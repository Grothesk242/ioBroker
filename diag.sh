#!/bin/bash
# iobroker diagnostics
# written to help getting information about the environment the ioBroker installation is running in

## --help

if [[ "$*" = *-h* ]]; then
echo "OPTIONS:";
echo "--de                      Ausgabe (teilweise) deutsch";
echo "--unmask                  Show otherwise masked output";
echo "-s, --short, -k, --kurz   Show summary / Zusammenfassung ausgeben";
echo "-h, --help, --hilfe       display this help and exit";
exit;
fi;



DOCKER=/opt/scripts/.docker_config/.thisisdocker
#if [[ -f "/opt/scripts/.docker_config/.thisisdocker" ]]
if [ "$(id -u)" -eq 0 ] && [ ! -f "$DOCKER" ]; then
    echo -e "You should not be root on your system!\nBetter use your standard user!\n\n"
    sleep 15
fi
clear
if [[ "$*" = *--de* ]]; then SKRPTLANG="--de"; fi
if [[ "$SKRPTLANG" = "--de" ]]; then
    echo "*** iob diag startet, bitte etwas warten ***"
else
    echo "*** iob diag is starting up, please wait ***"
fi

if ! [ -x "$(command -v distro-info)" ]; then
    if [[ "$SKRPTLANG" == "--de" ]]; then
        if [ -x "$(command -v apt-get)" ]; then
            echo "iob diag muss aktualisiert werden. Bitte dazu zunächst 'iobroker fix' ausführen."
        else
            echo "iob diag muss aktualisiert werden. Bitte das Paket 'distro-info' nachinstallieren."
        fi
    else
        if [ -x "$(command -v apt-get)" ]; then
            echo "iob diag needs to be updated. Please execute 'iobroker fix' first."
        else
            echo "iob diag needs to be updated. Please manually install package 'distro-info'"
        fi
    fi
fi

# VARIABLES
export LC_ALL=C
SKRIPTV="2025-03-08" #version of this script
#NODE_MAJOR=20           this is the recommended major nodejs version for ioBroker, please adjust accordingly if the recommendation changes
ALLOWROOT=""
if [ "$*" = "--allow-root" ]; then ALLOWROOT=$"--allow-root"; fi
MASKED=""
if [[ "$*" = *--unmask* ]]; then MASKED="unmasked"; fi
SUMMARY=""
if [[ "$*" = *--summary* ]] || [[ "$*" = *--short* ]] || [[ "$*" = *--zusammenfassung* ]] || [[ "$*" = *--kurz* ]] || [[ "$*" = *-s* ]] || [[ "$*" = *-k* ]] ; then SUMMARY="summary"; fi
HOST=$(uname -n)
ID_LIKE=$(awk -F= '$1=="ID_LIKE" { print $2 ;}' /etc/os-release | xargs)
NODERECOM=$(iobroker state getValue system.host."$HOST".versions.nodeNewestNext $ALLOWROOT) #recommended node version
NPMRECOM=$(iobroker state getValue system.host."$HOST".versions.npmNewestNext $ALLOWROOT)   #recommended npm version
#NODEUSED=$(iobroker state getValue system.host."$HOST".versions.nodeCurrent);      #current node version in use
#NPMUSED=$(iobroker state getValue system.host."$HOST".versions.npmCurrent);        #current npm version in use
XORGTEST=0 #test for GUI
APT=0
INSTENV=0
INSTENV2=0
SYSTDDVIRT=""
NODENOTCORR=0
IOBLISTINST=$(iobroker list instances $ALLOWROOT)
NPMLS=$(cd /opt/iobroker && npm ls -a)

#Debian and Ubuntu releases and their status
EOLDEB=$(debian-distro-info --unsupported)
EOLUBU=$(ubuntu-distro-info --unsupported)
DEBSTABLE=$(debian-distro-info --stable)
UBULTS=$(ubuntu-distro-info --lts)
UBUSUP=$(ubuntu-distro-info --supported)
TESTING=$(debian-distro-info --testing && ubuntu-distro-info --devel 2>/dev/null)
OLDSTABLE=$(debian-distro-info --oldstable)
CODENAME=$(lsb_release -sc)
UNKNOWNRELEASE=1

clear
if [[ "$SKRPTLANG" == "--de" ]]; then
    echo ""
    echo -e "\033[34;107m*** ioBroker Diagnose ***\033[0m"
    echo ""
    echo "Das Fenster des Terminalprogramms (puTTY) bitte so groß wie möglich ziehen oder den Vollbildmodus verwenden."
    echo ""
    echo "Die nachfolgenden Prüfungen liefern Hinweise zu etwaigen Fehlern, bitte im Forum hochladen:"
    echo ""
    echo "https://forum.iobroker.net"
    echo ""
    echo "Bitte die vollständige Ausgabe, einschließlich der \`\`\` Zeichen am Anfang und am Ende markieren und kopieren."
    echo "Es hilft beim helfen!"
    if [[ "$MASKED" != "unmasked" ]]; then
        echo ""
        echo "******************************************************************************************************"
        echo "* Einige Testergebnisse sind maskiert. Um alle Ausgaben zu sehen bitte 'iob diag --unmask' aufrufen. *"
        echo "******************************************************************************************************"
        echo ""
    fi
    # read -p "Press <Enter> to continue";
    echo -e "\nBitte eine Taste drücken"
    read -r -n 1 -s
    clear
    echo ""
else
    echo ""
    echo -e "\033[34;107m*** ioBroker Diagnosis ***\033[0m"
    echo ""
    echo "Please stretch the window of your terminal programm (puTTY) as wide as possible or switch to full screen"
    echo ""
    echo "The following checks may give hints to potential malconfigurations or errors, please post them in our forum:"
    echo ""
    echo "https://forum.iobroker.net"
    echo ""
    echo "Just copy and paste the Summary Page, including the \`\`\` characters at start and end."
    echo "It helps us to help you!"
    if [[ "$MASKED" != "unmasked" ]]; then
        echo ""
        echo "**************************************************************************"
        echo "* Some output is masked. For full results please use 'iob diag --unmask' *"
        echo "**************************************************************************"
    fi
    echo -e "\nPress any key to continue"
    read -r -n 1 -s
    clear
    echo ""
fi

if [[ "$SKRPTLANG" == "--de" ]]; then
    echo -e "\033[33m========== Langfassung ab hier markieren und kopieren ===========\033[0m"
    echo ""
    echo "\`\`\`bash"
    echo "Skript v.$SKRIPTV"
    echo ""
    echo -e "\033[34;107m*** GRUNDSYSTEM ***\033[0m"
else
    echo -e "\033[33m========== Start marking the full check here ===========\033[0m"
    echo ""
    echo "\`\`\`bash"
    echo "Script v.$SKRIPTV"
    echo ""
    echo -e "\033[34;107m*** BASE SYSTEM ***\033[0m"
fi

if [ -f "$DOCKER" ]; then
    echo -e "Hardware Vendor : $(cat /sys/devices/virtual/dmi/id/sys_vendor)"
    echo -e "Kernel          : $(uname -m)"
    echo -e "Userland        : $(getconf LONG_BIT) bit"
    echo -e "Docker          : $(cat /opt/scripts/.docker_config/.thisisdocker)"
else
    hostnamectl | grep -v 'Machine\|Boot'
    echo "OS is similar to: $ID_LIKE"
    echo ""
    grep -i model /proc/cpuinfo | tail -1
    echo -e "Docker          : false"
fi

SYSTDDVIRT=$(systemd-detect-virt 2>/dev/null)
if [ "$SYSTDDVIRT" != "" ]; then
    echo -e "Virtualization  : $(systemd-detect-virt)"
else
    echo "Virtualization  : Docker"
fi
echo -e "Kernel          : $(uname -m)"
echo -e "Userland        : $(getconf LONG_BIT) bit"
echo ""
echo "Systemuptime and Load:"
uptime
echo "CPU threads: $(grep -c processor /proc/cpuinfo)"
echo ""
echo ""

if [[ "$SKRPTLANG" == "--de" ]]; then
    echo -e "\033[34;107m*** LEBENSZYKLUS STATUS ***\033[0m"

    for RELEASE in $EOLDEB; do
        if [ "$RELEASE" = "$CODENAME" ]; then
            RELEASESTATUS="\e[31mDas Debian Release '$CODENAME' hat sein Lebensende erreicht und muss JETZT auf die aktuelle stabile Veröffentlichung '$DEBSTABLE' gebracht werden!\e[0m"
            UNKNOWNRELEASE=0
        fi
    done

    for RELEASE in $EOLUBU; do
        if [ "$RELEASE" == "$CODENAME" ]; then
            RELEASESTATUS="\e[31mDas Ubuntu Release '$CODENAME' hat sein Lebensende erreicht und muss JETZT auf die aktuelle Version '$UBULTS' mit Langzeitunterstützung gebracht werden.\e[0m"
            UNKNOWNRELEASE=0
        fi
    done

    for RELEASE in $DEBSTABLE; do
        if [ "$RELEASE" == "$CODENAME" ]; then
            RELEASESTATUS="\e[32mDas Betriebssystem ist das aktuelle, stabile Debian '$DEBSTABLE'!\e[0m"
            UNKNOWNRELEASE=0
        fi
    done

    for RELEASE in $UBULTS; do
        if [ "$RELEASE" == "$CODENAME" ]; then
            RELEASESTATUS="\e[32mDas Betriebssystem ist die aktuelle Ubuntu LTS Version '$UBULTS'!\e[0m"
            UNKNOWNRELEASE=0
        fi
    done

    for RELEASE in $UBUSUP; do
        if [ "$RELEASE" == "$CODENAME" ] && [ "$RELEASE" != "$UBULTS" ]; then
            RELEASESTATUS="\e[1;33mDie Unterstützung für das Betriebssystem mit dem Codenamen '$CODENAME' läuft aus. Es sollte in nächster Zeit auf die aktuelle Version '$UBULTS' mit Langzeitunterstützung gebracht werden.\e[0m"
            UNKNOWNRELEASE=0
        fi
    done

    for RELEASE in $TESTING; do
        if [ "$RELEASE" == "$CODENAME" ]; then
            RELEASESTATUS="\e[1;33mDas Betriebssystem mit dem Codenamen '$CODENAME' ist eine Testversion! Es sollte nur zu Testzwecken eingesetzt werden!\e[0m"
            UNKNOWNRELEASE=0
        fi
    done

    for RELEASE in $OLDSTABLE; do
        if [ "$RELEASE" == "$CODENAME" ]; then
            RELEASESTATUS="\e[1;33mDebian '$OLDSTABLE' ist eine veraltete Version. Es sollte in nächster Zeit auf die aktuelle stabile Version '$DEBSTABLE' gebracht werden!\e[0m"
            UNKNOWNRELEASE=0
        fi
    done

    if [ $UNKNOWNRELEASE -eq 1 ]; then
        RELEASESTATUS="Das Betriebssystem mit dem Codenamen '$CODENAME' ist unbekannt. Bitte den Status der Unterstützung eigenständig prüfen."
    fi

    echo -e "$RELEASESTATUS"

else
    echo -e "\033[34;107m*** LIFE CYCLE STATUS ***\033[0m"

    for RELEASE in $EOLDEB; do
        if [ "$RELEASE" = "$CODENAME" ]; then
            RELEASESTATUS="\e[31mDebian Release codenamed '$CODENAME' reached its END OF LIFE and needs to be updated to the latest stable release '$DEBSTABLE' NOW!\e[0m"
            UNKNOWNRELEASE=0
        fi
    done

    for RELEASE in $EOLUBU; do
        if [ "$RELEASE" == "$CODENAME" ]; then
            RELEASESTATUS="\e[31mUbuntu Release codenamed '$CODENAME' reached its END OF LIFE and needs to be updated to the latest LTS release '$UBULTS' NOW!\e[0m"
            UNKNOWNRELEASE=0
        fi
    done

    for RELEASE in $DEBSTABLE; do
        if [ "$RELEASE" == "$CODENAME" ]; then
            RELEASESTATUS="\e[32mOperating System is the current Debian stable version codenamed '$DEBSTABLE'!\e[0m"
            UNKNOWNRELEASE=0
        fi
    done

    for RELEASE in $UBULTS; do
        if [ "$RELEASE" == "$CODENAME" ]; then
            RELEASESTATUS="\e[32mOperating System is the current Ubuntu LTS release codenamed '$UBULTS'!\e[0m"
            UNKNOWNRELEASE=0
        fi
    done

    for RELEASE in $UBUSUP; do
        if [ "$RELEASE" == "$CODENAME" ] && [ "$RELEASE" != "$UBULTS" ]; then
            RELEASESTATUS="\e[1;33mOperating System codenamed '$CODENAME' is an aging Ubuntu release! Please upgrade to the latest LTS release '$UBULTS' in due time!\e[0m"
            UNKNOWNRELEASE=0
        fi
    done

    for RELEASE in $TESTING; do
        if [ "$RELEASE" == "$CODENAME" ]; then
            RELEASESTATUS="\e[1;33mOperating System codenamed '$CODENAME' is a testing release! Please use it only for testing purposes!\e[0m"
            UNKNOWNRELEASE=0
        fi
    done

    for RELEASE in $OLDSTABLE; do
        if [ "$RELEASE" == "$CODENAME" ]; then
            RELEASESTATUS="\e[1;33mDebian '$OLDSTABLE' is the current oldstable version. Please upgrade to the latest stable release '$DEBSTABLE' in due time!\e[0m"
            UNKNOWNRELEASE=0
        fi
    done

    if [ $UNKNOWNRELEASE -eq 1 ]; then
        RELEASESTATUS="Unknown release codenamed '$CODENAME'. Please check yourself if the Operating System is actively maintained."
    fi

    echo -e "$RELEASESTATUS"
fi
# RASPBERRY only
if [[ $(type -P "vcgencmd" 2>/dev/null) = *"/vcgencmd" ]]; then
    #        echo "Raspberry only:";
    #        vcgencmd get_throttled 2> /dev/null;
    #        echo "Other values than 0x0 hint to temperature/voltage problems";
    #        vcgencmd measure_temp;
    #        vcgencmd measure_volts;

    #### TEST CODE  ###

    echo ""
    echo -e "\033[34;107m*** RASPBERRY THROTTLING ***\033[0m"
    # CODE from https://github.com/alwye/get_throttled under MIT Licence
    ISSUES_MAP=(
        [0]="Under-voltage detected"
        [1]="Arm frequency capped"
        [2]="Currently throttled"
        [3]="Soft temperature limit active"
        [16]="Under-voltage has occurred"
        [17]="Arm frequency capping has occurred"
        [18]="Throttling has occurred"
        [19]="Soft temperature limit has occurred")

    HEX_BIN_MAP=(
        ["0"]="0000"
        ["1"]="0001"
        ["2"]="0010"
        ["3"]="0011"
        ["4"]="0100"
        ["5"]="0101"
        ["6"]="0110"
        ["7"]="0111"
        ["8"]="1000"
        ["9"]="1001"
        ["A"]="1010"
        ["B"]="1011"
        ["C"]="1100"
        ["D"]="1101"
        ["E"]="1110"
        ["F"]="1111"
    )

    THROTTLED_OUTPUT=$(vcgencmd get_throttled)
    IFS='x'
    read -r -a strarr <<<"$THROTTLED_OUTPUT"
    THROTTLED_CODE_HEX=${strarr[1]}

    # Display current issues
    echo "Current issues:"
    CURRENT_HEX=${THROTTLED_CODE_HEX:4:1}
    CURRENT_BIN=${HEX_BIN_MAP[$CURRENT_HEX]}
    if [ "$CURRENT_HEX" == "0" ] || [ -z "$CURRENT_HEX" ]; then
        echo "No throttling issues detected."
    else
        bit_n=0
        for ((i = ${#CURRENT_BIN} - 1; i >= 0; i--)); do
            if [ "${CURRENT_BIN:$i:1}" = "1" ]; then
                echo "~ ${ISSUES_MAP[$bit_n]}"
                bit_n=$((bit_n + 1))
            fi
        done
    fi

    echo ""

    # Display past issues
    echo "Previously detected issues:"
    PAST_HEX=${THROTTLED_CODE_HEX:0:1}
    PAST_BIN=${HEX_BIN_MAP[$PAST_HEX]}
    if [ "$PAST_HEX" = "0" ]; then
        echo "No throttling issues detected."
    else
        bit_n=16
        for ((i = ${#PAST_BIN} - 1; i >= 0; i--)); do
            if [ "${PAST_BIN:$i:1}" = "1" ]; then
                echo "~ ${ISSUES_MAP[$bit_n]}"
                bit_n=$((bit_n + 1))
            fi
        done
    fi
fi

if [[ "$SKRPTLANG" = "--de" ]]; then
    if [[ -f "/var/run/reboot-required" ]]; then
        echo ""
        echo "Dieses System benötigt einen NEUSTART"
        echo ""
    fi
else
    if [[ -f "/var/run/reboot-required" ]]; then
        echo ""
        echo "This system needs to be REBOOTED!"
        echo ""
    fi
fi

echo ""

if [[ "$SKRPTLANG" = "--de" ]]; then
    echo -e "\033[34;107m*** ZEIT UND ZEITZONEN ***\033[0m"

    if [ -f "$DOCKER" ]; then
        date -u
        date
        date +"%Z %z"
        cat /etc/timezone
    else
        timedatectl
    fi

    if [[ $(ps -p 1 -o comm=) == "systemd" ]] && [[ $(timedatectl show) == *Etc/UTC* ]] || [[ $(timedatectl show) == *Europe/London* ]]; then
        echo "Die gesetzte Zeitzone ist vermutlich falsch. Bitte die Zeitzone mit den Mitteln des Betriebssystems ändern oder per 'iobroker fix' setzen."
    fi
else

    echo -e "\033[34;107m*** TIME AND TIMEZONES ***\033[0m"

    if [ -f "$DOCKER" ]; then
        date -u
        date
        date +"%Z %z"
        cat /etc/timezone
    else
        timedatectl
    fi

    if [[ $(ps -p 1 -o comm=) == "systemd" ]]; then
        if [[ $(timedatectl show) == *Etc/UTC* ]] || [[ $(timedatectl show) == *Europe/London* ]]; then
            echo "Timezone is probably wrong. Please configure it with system admin tools or by running 'iobroker fix'"
        fi
    fi
fi

echo ""
if [[ "$SKRPTLANG" = "--de" ]]; then
    echo -e "\033[34;107m*** User und Gruppen ***\033[0m"
    echo "User der 'iob diag' aufgerufen hat:"
    whoami
    env | grep HOME
    echo "GROUPS=$(groups)"
    echo ""
    echo "User der den 'js-controller' ausführt:"
    if [[ $(pidof iobroker.js-controller) -gt 0 ]]; then
        IOUSER=$(ps -o user= -p "$(pidof iobroker.js-controller)")
        echo "$IOUSER"
        sudo -H -u "$IOUSER" env | grep HOME
        echo "GROUPS=$(sudo -u "$IOUSER" groups)"
    else
        echo "js-controller läuft nicht"
    fi
    echo ""

    if [ ! -f "$DOCKER" ] && [[ "$(whoami)" = "root" || "$(whoami)" = "iobroker" ]]; then

        # Prompt for username
        echo "Es sollte ein Standarduser angelegt werden! Dieser user kann auch mittels 'sudo' temporär root-Rechte erlangen."
        echo "Ein permanentes Login als root ist nicht vorgesehen."
        echo "Bitte den 'iobroker fix' ausführen oder manuell eine entsprechenden User anlegen."

    fi
else
    echo -e "\033[34;107m*** Users and Groups ***\033[0m"
    echo "User that called 'iob diag':"
    whoami
    env | grep HOME
    echo "GROUPS=$(groups)"
    echo ""
    echo "User that is running 'js-controller':"
    if [[ $(pidof iobroker.js-controller) -gt 0 ]]; then
        IOUSER=$(ps -o user= -p "$(pidof iobroker.js-controller)")
        echo "$IOUSER"
        sudo -H -u "$IOUSER" env | grep HOME
        echo "GROUPS=$(sudo -u "$IOUSER" groups)"
    else
        echo "js-controller is not running"
    fi

    echo ""

    if [[ $(ps -p 1 -o comm=) == "systemd" ]] && [[ "$(whoami)" = "root" || "$(whoami)" = "iobroker" ]]; then

        # Prompt for username
        echo "A default user should be created! This user will be enabled to temporarily switch to root via 'sudo'!"
        echo "A root login is not required in most Linux Distributions."
        echo "Run 'iobroker fix' or use the system tools to create a user."

    fi
fi
echo -e "\033[34;107m*** DISPLAY-SERVER SETUP ***\033[0m"
XORGTEST=$(pgrep -cf 'ayland|X11|Xorg|wayfire|labwc')
if [[ "$XORGTEST" -gt 0 ]]; then
    echo -e "Display-Server: true"
else
    echo -e "Display-Server: false"
fi
echo -e "Desktop: \t$DESKTOP_SESSION"
echo -e "Terminal: \t$XDG_SESSION_TYPE"
if [ -z "$DOCKER" ]; then
    echo -e "Boot Target: \t$(systemctl get-default)"
fi

if [[ $(ps -p 1 -o comm=) == "systemd" ]]; then
    if [[ $(systemctl get-default) == "graphical.target" ]]; then
        if [[ "$SKRPTLANG" = "--de" ]]; then
            echo -e "\nDas System bootet in eine graphische Oberfläche. Im Serverbetrieb wird keine GUI verwendet. Bitte das BootTarget auf 'multi-user.target' setzen oder 'iobroker fix' ausführen."
        else
            echo -e "\nSystem is booting into 'graphical.target'. Usually a server is running in 'multi-user.target'. Please set BootTarget to 'multi-user.target' or run 'iobroker fix'"
        fi
    fi
fi
echo ""
echo -e "\033[34;107m*** MEMORY ***\033[0m"
free -th --mega
echo ""
echo -e "Active iob-Instances: \t$(echo "$IOBLISTINST" | grep -c ^+)"
echo ""
vmstat -S M -s | head -n 10

# RASPBERRY only - Code broken for RPi5
# if [[ $(type -P "vcgencmd" 2>/dev/null) = *"/vcgencmd" ]]; then
#        echo "";
#        echo "Raspberry only:";
#        vcgencmd mem_oom;
#fi

echo ""
echo -e "\033[34;107m*** top - Table Of Processes  ***\033[0m"
top -b -n 1 | head -n 5

if [ -f "$DOCKER" ]; then
    echo ""
else
    echo ""
    echo -e "\033[34;107m*** FAILED SERVICES ***\033[0m"
    echo ""
    systemctl list-units --failed --no-pager
    echo ""
fi

echo ""
echo -e "\033[34;107m*** DMESG CRITICAL ERRORS ***\033[0m"
CRITERROR=$(sudo dmesg --level=emerg,alert,crit -T | wc -l)
if [[ "$CRITERROR" -gt 0 ]]; then
    if [[ "$SKRPTLANG" = "--de" ]]; then
        echo -e "Es wurden $CRITERROR KRITISCHE FEHLER gefunden. \nSiehe 'sudo dmesg --level=emerg,alert,crit -T' für Details"
    else
        echo -e "$CRITERROR CRITICAL ERRORS DETECTED! \nCheck 'sudo dmesg --level=emerg,alert,crit -T' for details"
    fi
else
    if [[ "$SKRPTLANG" = "--de" ]]; then
        echo "Es wurden keine kritischen Fehler gefunden"
    else
        echo "No critical errors detected"
    fi
fi
echo ""

echo -e "\033[34;107m*** FILESYSTEM ***\033[0m"
df -PTh
echo ""
echo -e "\033[32mMessages concerning ext4 filesystem in dmesg:\033[0m"
sudo dmesg -T | grep -i ext4
echo ""
echo -e "\033[32mShow mounted filesystems:\033[0m"
findmnt --real
echo ""
if [[ -L "/opt/iobroker/backups" ]]; then
    echo "backups directory is linked to a different directory"
    echo ""
fi
echo -e "\033[32mFiles in neuralgic directories:\033[0m"
echo ""
echo -e "\033[32m/var:\033[0m"
sudo du -h /var/ | sort -rh | head -5
echo -e ""
if [ ! -f "$DOCKER" ]; then
    journalctl --disk-usage
fi
echo ""
echo -e "\033[32m/opt/iobroker/backups:\033[0m"
du -h /opt/iobroker/backups/ | sort -rh | head -5
echo ""
echo -e "\033[32m/opt/iobroker/iobroker-data:\033[0m"
du -h /opt/iobroker/iobroker-data/ | sort -rh | head -5
echo ""
echo -e "\033[32mThe five largest files in iobroker-data are:\033[0m"
find /opt/iobroker/iobroker-data -maxdepth 15 -type f -exec du -sh {} + | sort -rh | head -n 5
echo ""
# Detecting dev-links in /dev/serial/by-id
echo -e "\033[32mUSB-Devices by-id:\033[0m"
echo "USB-Sticks -  Avoid direct links to /dev/tty* in your adapter setups, please always prefer the links 'by-id':"
echo ""

SYSZIGBEEPORT=$(find /dev/serial/by-id/ -maxdepth 1 -mindepth 1 2>/dev/null)

# echo "CODE I ";
#
#
# if [[ -n "$SYSZIGBEEPORT" ]];
#         then
#                 echo "$SYSZIGBEEPORT";
#         else
#                 echo "No Devices found 'by-id'";
# fi
#
# readarray IOBZIGBEEPORT < <( iob list instances | grep system.adapter.zigbee | awk -F ':' '{print $4}' );
# for i in  ${IOBZIGBEEPORT[@]}; do
#         if [[ "$SYSZIGBEEPORT" == *"$i"* ]]
#                 then
#                 echo "";
#                 echo "Your zigbee COM-Port is matching 'by-id'. Very good!"
#                 else
#                 echo;
#                 echo "HINT:";
#                 echo "Your zigbee COM-Port is NOT matching 'by-id'. Please check your setting:";
#                 echo "$IOBZIGBEEPORT0";
#         fi
#                 done;
#
# echo "";
# echo "CODE II";
IOBZIGBEEPORT0=$(echo "$IOBLISTINST" | grep system.adapter.zigbee.0 | awk -F ':' '{print $4}' | cut -c 2-)
IOBZIGBEEPORT1=$(echo "$IOBLISTINST" | grep system.adapter.zigbee.1 | awk -F ':' '{print $4}' | cut -c 2-)
IOBZIGBEEPORT2=$(echo "$IOBLISTINST" | grep system.adapter.zigbee.2 | awk -F ':' '{print $4}' | cut -c 2-)
IOBZIGBEEPORT3=$(echo "$IOBLISTINST" | grep system.adapter.zigbee.3 | awk -F ':' '{print $4}' | cut -c 2-)

if [[ -n "$SYSZIGBEEPORT" ]]; then
    echo "$SYSZIGBEEPORT"
else
    echo "No Devices found 'by-id'"
fi

echo ""

for d in /opt/iobroker/iobroker-data/zigbee_*; do
    if [ -d "$d" ]; then
        echo -e "\033[34;107m*** ZigBee Settings ***\033[0m"
    fi
    break
done

if [[ -n "$IOBZIGBEEPORT0" ]]; then
    if [ "$SYSZIGBEEPORT" = "$IOBZIGBEEPORT0" ]; then
        echo ""
        echo "Your zigbee.0 COM-Port is matching 'by-id'. Very good!"
    else
        echo
        echo "HINT:"
        echo "Your zigbee.0 COM-Port is NOT matching 'by-id'. Please check your setting:"
        echo "$IOBZIGBEEPORT0"
        # diff -y --left-column <(echo "$IOBZIGBEEPORT0") <(echo "$SYSZIGBEEPORT");
    fi
fi
if [[ -n "$IOBZIGBEEPORT1" ]]; then
    if [ "$SYSZIGBEEPORT" = "$IOBZIGBEEPORT1" ]; then
        echo ""
        echo "Your zigBee.1 COM-Port is matching 'by-id'. Very good!"
    else
        echo
        echo "HINT:"
        echo "Your zigbee.1 COM-Port is NOT matching 'by-id'. Please check your setting:"
        echo "$IOBZIGBEEPORT1"
        # diff -y --left-column <(echo "$IOBZIGBEEPORT1") <(echo "$SYSZIGBEEPORT");
    fi
fi
if [[ -n "$IOBZIGBEEPORT2" ]]; then
    if [ "$SYSZIGBEEPORT" = "$IOBZIGBEEPORT2" ]; then
        echo ""
        echo "Your zigBee.2 COM-Port is matching 'by-id'. Very good!"
    else
        echo
        echo "HINT:"
        echo "Your zigbee.2 COM-Port is NOT matching 'by-id'. Please check your setting:"
        echo "$IOBZIGBEEPORT2"
        # diff -y --left-column <(echo "$IOBZIGBEEPORT2") <(echo "$SYSZIGBEEPORT");
    fi
fi
if [[ -n "$IOBZIGBEEPORT3" ]]; then
    if [ "$SYSZIGBEEPORT" = "$IOBZIGBEEPORT3" ]; then
        echo ""
        echo "Your zigbee.3 COM-Port is matching 'by-id'. Very good!"
    else
        echo
        echo "HINT:"
        echo "Your zigbee.3 COM-Port is NOT matching 'by-id'. Please check your setting:"
        echo "$IOBZIGBEEPORT3"
        # diff -y --left-column <(echo "$IOBZIGBEEPORT0") <(echo "$SYSZIGBEEPORT");
    fi
fi
# masked output

for d in /opt/iobroker/iobroker-data/zigbee_*/nvbackup.json
    do
        if [[ "$MASKED" != "unmasked" ]]; then
        echo "Zigbee Network Settings on your coordinator/in nvbackup are:"
        echo ""
        echo "zigbee.X"
        echo "Extended Pan ID:"
        echo "*** MASKED ***"
        #echo "OR";
        #echo "*** MASKED ***";
        echo "Pan ID:"
        echo "*** MASKED ***"
        echo "Channel:"
        echo "*** MASKED ***"
        echo "Network Key:"
        echo "*** MASKED ***"
        echo -e "\nTo unmask the settings run 'iob diag --unmask'\n"
        break
        fi
    done

for d in /opt/iobroker/iobroker-data/zigbee_*/nvbackup.json
    do
        if [[ "$MASKED" = "unmasked" ]]; then
        echo -e "\nZigbee Network Settings on your coordinator/in nvbackup are:"
        echo -e "zigbee.$(printf '%s\n' "$d" | cut -c36)"
        echo "Extended Pan ID:"
        grep extended_pan_id "$d" | cut -c 23-38
        echo "Pan ID:"
        printf "%d" 0x"$(grep \"pan_id\" "$d" | cut -c 14-17)"
        echo -e "\nChannel:"
        grep \"channel\" "$d" | cut -c 14-15
        echo "Network Key:"
        grep \"key\" "$d" | cut -c 13-44
        fi
    done
echo ""
echo -e "\033[34;107m*** NodeJS-Installation ***\033[0m"
echo ""

# PATHAPT=$(type -P apt);
PATHNODEJS=$(type -P nodejs)
PATHNODE=$(type -P node)
PATHNPM=$(type -P npm)
PATHNPX=$(type -P npx)
PATHCOREPACK=$(type -P corepack)

if [[ -z "$PATHNODEJS" ]]; then
    echo -e "nodejs: \t\tN/A"
else
    echo -e "$(type -P nodejs) \t$(nodejs -v)"
    VERNODEJS=$(nodejs -v)
fi

if [[ -z "$PATHNODE" ]]; then
    echo -e "node: \t\tN/A"

else
    echo -e "$(type -P node) \t\t$(node -v)"
    VERNODE=$(node -v)
fi

if [[ -z "$PATHNPM" ]]; then
    echo -e "npm: \t\t\tN/A"
else
    echo -e "$(type -P npm) \t\t$(npm -v)"
    VERNPM=$(npm -v)
fi

if [[ -z "$PATHNPX" ]]; then
    echo -e "npx: \t\t\tN/A"

else
    echo -e "$(type -P npx) \t\t$(npx -v)"
    VERNPX=$(npx -v)
fi

if [[ -z "$PATHCOREPACK" ]]; then
    echo -e "corepack: \tN/A"

else
    echo -e "$(type -P corepack) \t$(corepack -v)"
    # VERCOREPACK=$(corepack -v);
fi

if
    [[ $PATHNODEJS != "/usr/bin/nodejs" ]]
then
    NODENOTCORR=1
    if [[ "$SKRPTLANG" = "--de" ]]; then
        echo -e "\033[0;31m*** nodejs ist NICHT korrekt installiert ***\033[0m"
    else
        echo -e "\033[0;31m*** nodejs is NOT correctly installed ***\033[0m"
    fi
elif
    [[ $PATHNODE != "/usr/bin/node" ]]
then
    NODENOTCORR=1
    if [[ "$SKRPTLANG" = "--de" ]]; then
        echo -e "\033[0;31m*** nodejs ist NICHT korrekt installiert ***\033[0m"
    else
        echo -e "\033[0;31m*** nodejs is NOT correctly installed ***\033[0m"
    fi
elif
    [[ $PATHNPM != "/usr/bin/npm" ]]
then
    NODENOTCORR=1
    if [[ "$SKRPTLANG" = "--de" ]]; then
        echo -e "\033[0;31m*** nodejs ist NICHT korrekt installiert ***\033[0m"
    else
        echo -e "\033[0;31m*** nodejs is NOT correctly installed ***\033[0m"
    fi
elif
    [[ $PATHNPX != "/usr/bin/npx" ]]
then
    NODENOTCORR=1
    if [[ "$SKRPTLANG" = "--de" ]]; then
        echo -e "\033[0;31m*** nodejs ist NICHT korrekt installiert ***\033[0m"
    else
        echo -e "\033[0;31m*** nodejs is NOT correctly installed ***\033[0m"
    fi
elif
    [[ $VERNODEJS != "$VERNODE" ]]
then
    NODENOTCORR=1
    if [[ "$SKRPTLANG" = "--de" ]]; then
        echo -e "\033[0;31m*** nodejs ist NICHT korrekt installiert ***\033[0m"
    else
        echo -e "\033[0;31m*** nodejs is NOT correctly installed ***\033[0m"
    fi
elif
    [[ $VERNPM != "$VERNPX" ]]
then
    NODENOTCORR=1
    if [[ "$SKRPTLANG" = "--de" ]]; then
        echo -e "\033[0;31m*** nodejs ist NICHT korrekt installiert ***\033[0m"
    else
        echo -e "\033[0;31m*** nodejs is NOT correctly installed ***\033[0m"
    fi
elif
    [[ $PATHCOREPACK != "/usr/bin/corepack" ]]
then
    NODENOTCORR=1
    if [[ "$SKRPTLANG" = "--de" ]]; then
        echo -e "\033[0;31m*** nodejs ist NICHT korrekt installiert ***\033[0m"
    else
        echo -e "\033[0;31m*** nodejs is NOT correctly installed ***\033[0m"
    fi
fi

echo ""
if [ -f /usr/bin/apt-cache ]; then
    apt-cache policy nodejs
    echo ""
fi

ANZNPMTMP=$(find /opt/iobroker/node_modules -type d -iname '.*-????????' ! -iname '.local-chromium' | wc -l)
echo -e "\033[32mTemp directories causing deletion problem:\033[0m ""$ANZNPMTMP"""
if [[ $ANZNPMTMP -gt 0 ]]; then
    echo -e "Some problems detected, please run \e[031miob fix\e[0m"
else
    echo "No problems detected"
fi

# echo "";
# echo -e "Temp directories being cleaned up now `find /opt/iobroker/node_modules -type d -iname ".*-????????" ! -iname ".local-chromium" -exec rm -rf {} \;`";
# find /opt/iobroker/node_modules -type d -iname ".*-????????" ! -iname ".local-chromium" -exec rm -rf {} \ &> /dev/null;
# echo -e "\033[32m1 - Temp directories causing npm8 problem:\033[0m `find /opt/iobroker/node_modules -type d -iname '.*-????????' ! -iname '.local-chromium'>e;
echo ""
if [[ $(echo "$NPMLS" | grep ERR -wc -l) -gt 0 ]]; then
    echo -e "\033[322mErrors in npm tree:\033[0m"
    echo "$NPMLS" | grep ERR
    echo ""
else
    echo -e "\033[32mErrors in npm tree:\033[0m 0"
    echo "No problems detected"
    echo ""
fi
echo -e "\033[34;107m*** ioBroker-Installation ***\033[0m"
echo ""
echo -e "\033[32mioBroker Status\033[0m"
iob status $ALLOWROOT
echo -e "\nHosts:"
iob list hosts $ALLOWROOT
echo ""
# multihost detection - wip
# iobroker multihost status
# iobroker status all | grep MULTIHOSTSERVICE/enabled
echo -e "\033[32mCore adapters versions\033[0m"
echo -e "js-controller: \t$(iob -v $ALLOWROOT)"
echo -e "admin: \t\t$(iob version admin $ALLOWROOT)"
echo -e "javascript: \t$(iob version javascript $ALLOWROOT)"
echo ""
echo -e "nodejs modules from github: \t$(echo "$NPMLS" | grep -c 'github.com')"
echo "$NPMLS" | grep 'github.com'
echo ""
echo -e "\033[32mAdapter State\033[0m"
echo "$IOBLISTINST"
echo ""
echo -e "\033[32mEnabled adapters with bindings\033[0m"
echo "$IOBLISTINST" | grep enabled | grep port
echo ""
echo -e "\033[32mioBroker-Repositories\033[0m"
iob repo list $ALLOWROOT
echo ""
echo -e "\033[32mInstalled ioBroker-Adapters\033[0m"
iob update -i $ALLOWROOT
echo ""
echo -e "\033[32mObjects and States\033[0m"
echo "Please stand by - This may take a while"
IOBOBJECTS=$(iob list objects $ALLOWROOT 2>/dev/null | wc -l)
echo -e "Objects: \t$IOBOBJECTS"
IOBSTATES=$(iob list states $ALLOWROOT 2>/dev/null | wc -l)
echo -e "States: \t$IOBSTATES"
echo ""
echo -e "\033[34;107m*** OS-Repositories and Updates ***\033[0m"
if [ -f /usr/bin/apt-get ]; then
    sudo apt-get update 1>/dev/null && sudo apt-get update
    APT=$(apt-get upgrade -s | grep -P '^\d+ upgraded' | cut -d" " -f1)
    if [[ "$SKRPTLANG" = "--de" ]]; then
        echo -e "Offene Systemupdates: $APT"
    else
        echo -e "Pending Updates: $APT"
    fi
else
    if [[ "$SKRPTLANG" = "--de" ]]; then
        echo "Es wurde kein auf Debian basierendes System erkannt"
    else
        echo "No Debian-based Linux detected."
    fi
fi

echo ""

echo -e "\033[34;107m*** Listening Ports ***\033[0m"
sudo netstat -tulpen #| sed -n '1,2p;/LISTEN/p';
# Alternativ - ss ist nicht ueberall installiert
# sudo ss -tulwp | grep LISTEN;
echo ""
echo -e "\033[34;107m*** Log File - Last 25 Lines ***\033[0m"
echo ""
# iobroker logs --lines 25;
tail -n 25 /opt/iobroker/log/iobroker.current.log
echo ""
echo "\`\`\`"
echo ""
if [[ "$SKRPTLANG" = "--de" ]]; then
    echo -e "\033[33m============ Langfassung bis hier markieren =============\033[0m"
    echo ""
    echo "iob diag hat das System inspiziert."
    echo ""
    echo ""
    if [[ $SUMMARY != "summary" ]]; then
    exit
    else
    echo "Beliebige Taste für eine Zusammenfassung drücken"
    fi
else
    echo -e "\033[33m============ Mark until here for C&P =============\033[0m"
    echo ""
    echo "iob diag has finished."
    echo ""
    echo ""
    if [[ $SUMMARY != "summary" ]]; then
    exit
    else
    echo "Press any key for a summary"
    fi
read -r -n 1 -s
echo ""
fi
clear
if [[ "$SKRPTLANG" = "--de" ]]; then
    echo "Zusammfassung ab hier markieren und kopieren:"
    echo ""
    echo "\`\`\`bash"
    echo "===================== ZUSAMMENFASSUNG ====================="
    echo -e "\t\t\tv.$SKRIPTV"
    echo ""
    echo ""
else
    echo "Copy text starting here:"
    echo ""
    echo "\`\`\`bash"
    echo "======================= SUMMARY ======================="
    echo -e "\t\t\tv.$SKRIPTV"
    echo ""
    echo ""
fi
if [ -f "$DOCKER" ]; then
    INSTENV=2
elif [ "$SYSTDDVIRT" != "none" ]; then
    INSTENV=1
else
    INSTENV=0
fi
INSTENV2=$(
    if [[ $INSTENV -eq 2 ]]; then
        echo "Docker"
    elif [ $INSTENV -eq 1 ]; then
        echo "$SYSTDDVIRT"
    else
        echo "native"
    fi
)
if [ -f "$DOCKER" ]; then
    grep -i model /proc/cpuinfo | tail -1
    echo -e "Kernel          : $(uname -m)"
    echo -e "Userland        : $(dpkg --print-architecture)"
    if [[ -f "$DOCKER" ]]; then
        echo -e "Docker          : $(cat /opt/scripts/.docker_config/.thisisdocker)"
    else
        echo -e "Docker          : false"
    fi

else
    hostnamectl | grep -v 'Machine\|Boot'
fi
echo ""
echo -e "Installation: \t\t$INSTENV2"
echo -e "Kernel: \t\t$(uname -m)"
echo -e "Userland: \t\t$(getconf LONG_BIT) bit"
if [ -f "$DOCKER" ]; then
    echo -e "Timezone: \t\t$(date +"%Z %z")"
else
    echo -e "Timezone: \t\t$(timedatectl | grep zone | cut -c28-80)"
fi
echo -e "User-ID: \t\t$EUID"
echo -e "Display-Server: \t$(if [[ $XORGTEST -gt 0 ]]; then echo "true"; else echo "false"; fi)"
if [ -f "$DOCKER" ]; then
    echo -e ""
else
    echo -e "Boot Target: \t\t$(systemctl get-default)"
fi

echo ""
if [[ "$SKRPTLANG" = "--de" ]]; then
    echo -e "Offene OS-Updates: \t$APT"
    echo -e "Offene iob updates: \t$(iob update -u $ALLOWROOT | grep -c 'Updatable\|Updateable')"
else
    echo -e "Pending OS-Updates: \t$APT"
    echo -e "Pending iob updates: \t$(iob update -u $ALLOWROOT | grep -c 'Updatable\|Updateable')"
fi
if [[ -f "/var/run/reboot-required" ]]; then
    if [[ "$SKRPTLANG" = "--de" ]]; then
        echo -e "\nDas System muss JETZT neugestartet werden!"
        echo ""
    else
        echo -e "\nThis system needs to be REBOOTED NOW!"
        echo ""
    fi
fi
echo -e "\nNodejs-Installation:"
if [[ -z "$PATHNODEJS" ]]; then
    echo -e "nodejs: \t\tN/A"
else
    echo -e "$(type -P nodejs) \t$(nodejs -v)"
    VERNODEJS=$(nodejs -v)
fi

if [[ -z "$PATHNODE" ]]; then
    echo -e "node: \t\t\tN/A"

else
    echo -e "$(type -P node) \t\t$(node -v)"
    VERNODE=$(node -v)
fi

if [[ -z "$PATHNPM" ]]; then
    echo -e "npm: \t\t\tN/A"
else
    echo -e "$(type -P npm) \t\t$(npm -v)"
    VERNPM=$(npm -v)
fi

if [[ -z "$PATHNPX" ]]; then
    echo -e "npx: \t\t\tN/A"

else
    echo -e "$(type -P npx) \t\t$(npx -v)"
    VERNPX=$(npx -v)
fi

if [[ -z "$PATHCOREPACK" ]]; then
    echo -e "corepack: \tN/A"

else
    echo -e "$(type -P corepack) \t$(corepack -v)"
fi
if [[ "$SKRPTLANG" = "--de" ]]; then
    echo -e "\nEmpfohlene Versionen sind zurzeit nodejs ""$NODERECOM"" und npm ""$NPMRECOM"""
else
    echo -e "\nRecommended versions are nodejs ""$NODERECOM"" and npm ""$NPMRECOM"""
fi
if
    [[ $PATHNODEJS != "/usr/bin/nodejs" ]]
then
    if [[ "$SKRPTLANG" = "--de" ]]; then
        echo -e "\033[0;31m*** nodejs ist NICHT korrekt installiert ***\033[0m"
        echo "Falsche Installationspfade erkannt. Dies muss korrigiert werden."
    else
        echo -e "\033[0;31m*** nodejs is NOT correctly installed ***\033[0m"
        echo "Wrong installation path detected. This needs to be fixed."
    fi
elif
    [[ $PATHNODE != "/usr/bin/node" ]]
then
    if [[ "$SKRPTLANG" = "--de" ]]; then
        echo -e "\033[0;31m*** nodejs ist NICHT korrekt installiert ***\033[0m"
        echo "Falsche Installationspfade erkannt. Dies muss korrigiert werden."
    else
        echo -e "\033[0;31m*** nodejs is NOT correctly installed ***\033[0m"
        echo "Wrong installation path detected. This needs to be fixed."
    fi
elif
    [[ $PATHNPM != "/usr/bin/npm" ]]
then
    if [[ "$SKRPTLANG" = "--de" ]]; then
        echo -e "\033[0;31m*** nodejs ist NICHT korrekt installiert ***\033[0m"
        echo "Falsche Installationspfade erkannt. Dies muss korrigiert werden."
    else
        echo -e "\033[0;31m*** nodejs is NOT correctly installed ***\033[0m"
        echo "Wrong installation path detected. This needs to be fixed."
    fi
elif
    [[ $PATHNPX != "/usr/bin/npx" ]]
then
    if [[ "$SKRPTLANG" = "--de" ]]; then
        echo -e "\033[0;31m*** nodejs ist NICHT korrekt installiert ***\033[0m"
        echo "Falsche Installationspfade erkannt. Dies muss korrigiert werden."
    else
        echo -e "\033[0;31m*** nodejs is NOT correctly installed ***\033[0m"
        echo "Wrong installation path detected. This needs to be fixed."
    fi
elif
    [[ $PATHCOREPACK != "/usr/bin/corepack" ]]
then
    if [[ "$SKRPTLANG" = "--de" ]]; then
        echo -e "\033[0;31m*** nodejs ist NICHT korrekt installiert ***\033[0m"
        echo "Falsche Installationspfade erkannt. Dies muss korrigiert werden."
    else
        echo -e "\033[0;31m*** nodejs is NOT correctly installed ***\033[0m"
        echo "Wrong installation path detected. This needs to be fixed."
    fi
elif
    [[ $VERNODEJS != "$VERNODE" ]]
then
    if [[ "$SKRPTLANG" = "--de" ]]; then
        echo -e "\033[0;31m*** nodejs ist NICHT korrekt installiert ***\033[0m"
        echo "Die Versionen von nodejs und node stimmen nicht überein. Dies muss korrigiert werden."
    else
        echo -e "\033[0;31m*** nodejs is NOT correctly installed ***\033[0m"
        echo "nodejs and node versions do not match. This needs to be fixed."
    fi

elif
    [[ $VERNPM != "$VERNPX" ]]
then
    if [[ "$SKRPTLANG" = "--de" ]]; then
        echo -e "\033[0;31m*** nodejs ist NICHT korrekt installiert ***\033[0m"
        echo "Die Versionen von npm und npx stimmen nicht überein. Dies muss korrigiert werden."
    else
        echo -e "\033[0;31m*** nodejs is NOT correctly installed ***\033[0m"
        echo "npm and npx versions do not match. This needs to be fixed."
    fi
else
    if [[ "$SKRPTLANG" = "--de" ]]; then
        echo "nodeJS ist korrekt installiert"
    else
        echo "nodeJS installation is correct"
    fi
fi
if [[ $NODENOTCORR -eq 1 ]]; then
    if [[ "$SKRPTLANG" = "--de" ]]; then
        echo ""
        echo "Bitte den Befehl"
        echo -e "\e[031miob nodejs-update\e[0m"
        echo "zur Korrektur der Installation ausführen."
    else
        echo ""
        echo "Please execute"
        echo -e "\e[031miob nodejs-update\e[0m"
        echo "to fix these errors."
    fi
fi
echo ""
# echo -e "Total Memory: \t\t`free -h | awk '/^Mem:/{print $2}'`";
echo "MEMORY: "
free -ht --mega
echo ""
echo -e "Active iob-Instances: \t$(echo "$IOBLISTINST" | grep -c ^+)"
iob repo list $ALLOWROOT | tail -n1
echo ""
echo -e "ioBroker Core: \t\tjs-controller \t\t$(iob -v $ALLOWROOT)"
echo -e "\t\t\tadmin \t\t\t$(iob version admin $ALLOWROOT)"
echo ""
echo -e "ioBroker Status: \t$(iobroker status $ALLOWROOT)"
echo ""
# iobroker status all | grep MULTIHOSTSERVICE/enabled;
echo "Status admin and web instance:"
echo "$IOBLISTINST" | grep 'admin.\|system.adapter.web.'
echo ""
echo -e "Objects: \t\t$IOBOBJECTS"
echo -e "States: \t\t$IOBSTATES"
echo ""
echo -e "Size of iob-Database:"
echo ""
find /opt/iobroker/iobroker-data -maxdepth 1 -type f -name \*objects\* -exec du -sh {} + | sort -rh | head -n 5
find /opt/iobroker/iobroker-data -maxdepth 1 -type f -name \*states\* -exec du -sh {} + | sort -rh | head -n 5
echo ""
echo ""
if [[ $ANZNPMTMP -gt 0 ]]; then
    if [[ "$SKRPTLANG" = "--de" ]]; then
        echo "**********************************************************************"
        echo -e "Probleme wurden erkannt, bitte \e[031miob fix\e[0m ausführen"
        echo "**********************************************************************"
        echo ""
    else
        echo "**********************************************************************"
        echo -e "Some problems detected, please run \e[031miob fix\e[0m and try to have them fixed"
        echo "**********************************************************************"
        echo ""
    fi
fi
if [[ "$CRITERROR" -gt 0 ]]; then
    if [[ "$SKRPTLANG" = "--de" ]]; then
        echo -e "Es wurden $CRITERROR KRITISCHE FEHLER gefunden. \nSiehe 'sudo dmesg --level=emerg,alert,crit -T' für Details"
    else
        echo -e "$CRITERROR CRITICAL ERRORS DETECTED! \nCheck 'sudo dmesg --level=emerg,alert,crit -T' for details"
    fi
fi
echo -e "$RELEASESTATUS"
echo ""
if [[ "$SKRPTLANG" = "--de" ]]; then
    echo "=================== ENDE DER ZUSAMMENFASSUNG ===================="
    echo -e "\`\`\`"
    echo ""
    echo "=== Ausgabe bis hier markieren und kopieren ==="
else
    echo "=================== END OF SUMMARY ===================="
    echo -e "\`\`\`"
    echo ""
    echo "=== Mark text until here for copying ==="
fi
exit
