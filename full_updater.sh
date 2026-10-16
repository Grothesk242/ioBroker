#!/usr/bin/env bash

# Define colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
STOP_TIMEOUT=300
START_TIMEOUT=120
APT_COMMAND="upgrade"
IS_CONTAINER=false
nodejs_update=false

# Prevent parallel execution
LOCK_FILE="/var/lock/full_updater.lock"

exec 200>"$LOCK_FILE"

if ! flock -n 200; then
    printf "${RED}Error: Another instance of full_updater is already running.${NC}\n"
    exit 1
fi

# Detect container environments
if [ -f "/.dockerenv" ] || systemd-detect-virt -q --container 2>/dev/null; then
    IS_CONTAINER=true

    printf "${YELLOW}Container environment detected.${NC}\n"
    printf "${YELLOW}OS package updates will be skipped.${NC}\n\n"
fi

# Cleanup temporary files
cleanup() {
    [[ -n "${UPDATE_LOG:-}" ]] && rm -f "$UPDATE_LOG"
}

trap cleanup EXIT INT TERM

# Clear screen
clear

# --- Capabilities ---
# Installing/updating the nodejs package replaces the node binary, and file
# capabilities do not survive that. Re-grant what install_necessary_packages
# in installer_library.sh grants, otherwise adapters that need privileged
# ports or raw sockets (ping, BLE, ports below 1024) stop working.
set_node_capabilities() {
    local node_bin
    node_bin=$(readlink -f "$(command -v node)" 2>/dev/null || echo "")
    if [[ -z "$node_bin" ]]; then
        printf "${RED}Error: Node.js binary not found. Capabilities were not set, please run 'iob fix'.${NC}\n"
        return 1
    fi

    # A capability missing from the bounding set (a container started without
    # --cap-add=NET_ADMIN, for example) must not be granted: the kernel would
    # then refuse to start node at all. Bits: 10 = cap_net_bind_service,
    # 12 = cap_net_admin, 13 = cap_net_raw.
    local capbnd caps=() name bit
    capbnd=$(awk '/^CapBnd:/ {print $2}' /proc/self/status 2>/dev/null || echo "")
    for name in cap_net_admin:12 cap_net_bind_service:10 cap_net_raw:13; do
        bit=${name#*:}
        if [[ -z "$capbnd" ]] || (((16#$capbnd >> bit) & 1)); then
            caps+=("${name%%:*}")
        else
            printf "${YELLOW}Warning: ${name%%:*} is not available on this system and was not granted to Node.js.${NC}\n"
        fi
    done
    if [[ ${#caps[@]} -eq 0 ]]; then
        printf "${RED}Error: No capabilities can be granted to Node.js. Adapters that need privileged ports or raw sockets will not work.${NC}\n"
        return 1
    fi

    local caps_arg
    caps_arg="$(
        IFS=,
        echo "${caps[*]}"
    )+eip"
    printf "${YELLOW}Granting $caps_arg to $node_bin...${NC}\n"
    if ! sudo setcap "$caps_arg" "$node_bin"; then
        printf "${RED}Error: Failed to set the capabilities. Adapters that need privileged ports or raw sockets will not work until you run 'iob fix'.${NC}\n"
        return 1
    fi
    printf "${GREEN}Done.${NC}\n"
    echo ""
    return 0
}

# Function to stop ioBroker with timeout and progress bar
stop_iobroker() {
    printf "${YELLOW}Stopping ioBroker...${NC}\n"

    if ! iobroker stop; then
        printf "${RED}Error: iobroker stop returned an error.${NC}\n"
        return 1
    fi

    wait_for_js_controller_stop
}

# Function to wait until js-controller is fully stopped
wait_for_js_controller_stop() {
    printf "${YELLOW}Waiting until js-controller is fully stopped...${NC}"

    local elapsed=0

    while pgrep -f "iobroker.js-controller" >/dev/null; do
        if [ "$elapsed" -ge "$STOP_TIMEOUT" ]; then
            printf "\n${RED}Timeout: js-controller did not stop within ${STOP_TIMEOUT} seconds.${NC}\n"
            return 1
        fi

        printf "."
        sleep 1
        elapsed=$((elapsed + 1))
    done

    printf "\n${GREEN}Done.${NC}\n\n"
    return 0
}

# Function to wait until js-controller is fully started
wait_for_js_controller_start() {
    printf "${YELLOW}Waiting until js-controller is fully started...${NC}"

    local elapsed=0

    while ! pgrep -f "iobroker.js-controller" >/dev/null; do
        if [ "$elapsed" -ge "$START_TIMEOUT" ]; then
            printf "\n${RED}Timeout: js-controller did not start within ${START_TIMEOUT} seconds.${NC}\n"
            return 1
        fi

        printf "."
        sleep 1
        elapsed=$((elapsed + 1))
    done

    printf "\n${GREEN}Done.${NC}\n\n"
    return 0
}

# Header
printf "${BLUE}=============================================================================${NC}\n"
printf "${BLUE}===                         System Update Script                        ===${NC}\n"
printf "${BLUE}=============================================================================${NC}\n"
echo ""

# 1. Update package lists
if [[ "$IS_CONTAINER" == false ]]; then

    printf "${YELLOW}1. Updating package lists...${NC}\n"

    if ! sudo apt-get update -y; then
        printf "${RED}Error: Failed to update package lists.${NC}\n"
        exit 1
    fi

    printf "${GREEN}Done.${NC}\n"
    echo ""

    # Check if nodejs needs to be updated
    nodejs_update=false

    if sudo apt-get --dry-run "$APT_COMMAND" | grep -qE "^Inst nodejs "; then
        nodejs_update=true
    fi

    if [[ "$nodejs_update" == true && "$IS_CONTAINER" == false ]]; then
        if ! stop_iobroker; then
            printf "${RED}Error: Failed to stop ioBroker properly.${NC}\n"
            exit 1
        fi
    fi

    printf "${YELLOW}2. Performing system upgrade...${NC}\n"

    if ! sudo apt-get "$APT_COMMAND" -y; then
        printf "${RED}Error: System upgrade failed.${NC}\n"
        exit 1
    fi

    printf "${GREEN}Done.${NC}\n"
    echo ""

else

    printf "${YELLOW}Skipping OS package updates because a container environment was detected.${NC}\n\n"
    nodejs_update=false

fi

# Check if nodejs needs to be updated
nodejs_update=false
if sudo apt-get --dry-run "$APT_COMMAND" | grep -qE "^Inst nodejs "; then
    nodejs_update=true
fi

# 2. Check and install ioBroker updates
printf "${YELLOW}3. Checking for ioBroker updates...${NC}\n"
UPDATE_LOG=$(mktemp -t full_updater.XXXXXX.log)
iobroker update >"$UPDATE_LOG" 2>&1

# Check if js-controller needs to be updated
if grep -q "js-controller.*Updatable" "$UPDATE_LOG"; then
    printf "${YELLOW}js-controller needs to be updated. Stopping ioBroker...${NC}\n"
    if ! stop_iobroker; then
        printf "${RED}Error: Failed to stop ioBroker properly.${NC}\n"
        exit 1
    fi

    printf "${YELLOW}Updating js-controller...${NC}\n"
    if ! iobroker upgrade self; then
        printf "${RED}Error: Failed to update js-controller.${NC}\n"
        exit 1
    fi
    printf "${GREEN}Done.${NC}\n"
    echo ""

    printf "${YELLOW}Starting ioBroker...${NC}\n"
    if ! iobroker start; then
        printf "${RED}Error: Failed to start ioBroker.${NC}\n"
        exit 1
    fi
    if ! wait_for_js_controller_start; then
        printf "${RED}Error: ioBroker did not start properly.${NC}\n"
        exit 1
    fi
fi

# Install all other ioBroker updates
printf "${YELLOW}Installing ioBroker updates...${NC}\n"
if ! iobroker upgrade --all; then
    printf "${RED}Error: Failed to install ioBroker updates.${NC}\n"
    exit 1
fi
printf "${GREEN}Done.${NC}\n"
echo ""

# Reboot check
printf "${BLUE}=============================================================================${NC}\n"
if [ -f "/var/run/reboot-required" ]; then
    printf "${RED}IMPORTANT: The system needs to be REBOOTED to complete the changes!${NC}\n"
    echo ""
    printf "${YELLOW}Please execute the following command:${NC}\n"
    printf "${GREEN}sudo reboot${NC}\n"
else
    printf "${GREEN}All updates have been installed successfully. No reboot required.${NC}\n"
    if [[ "$nodejs_update" == true && "$IS_CONTAINER" == false ]]; then
        printf "${YELLOW}Please review ioBroker logs carefully after a Node.js update. Native modules may require rebuilding.${NC}\n"
    fi
fi
printf "${BLUE}=============================================================================${NC}\n"
