#!/usr/bin/env bash
#colour escape sequences
RED=$'\033[0;31m'
RESET=$'\033[0m' 
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
#config directory
CONFIG_DIR="$HOME/.config/nmg"
CONFIG_FILE="$CONFIG_DIR/nmgc.conf"
echo '
.__   __. .___  ___.   _______ 
|  \ |  | |   \/   |  /  _____|
|   \|  | |  \  /  | |  |  __  
|  . `  | |  |\/|  | |  | |_ | 
|  |\   | |  |  |  | |  |__| | 
|__| \__| |__|  |__|  \______| 

'
if [ -f "$CONFIG_FILE" ] && grep -q "update_check=1" "$CONFIG_FILE"; then
echo -e "${YELLOW}Checking for updates...${YELLOW}"
cd "$HOME"/nmg || echo "${RED}Failed to change directory${RESET}"
localhash="$(git rev-parse HEAD)"
latesthash="$(git ls-remote https://github.com/spectrum75/nmg HEAD | awk '{print $1}')"
    if [ "$localhash" != "$latesthash" ] && [ ! -z "$latesthash" ] && [ ! -z "$localhash" ];then
        echo "${YELLOW}Updating to the new version...${RESET}"
        git clean -fd
        git reset --hard
        git pull https://github.com/spectrum75/nmg HEAD || echo "$S{RED}Update failed, please check your connection and try again${RESET}"
    else
        echo "${GREEN}You are up to date!${RESET}"
    fi
fi

echo -e "${YELLOW}Checking for network manager...${RESET}"
if systemctl list-unit-files "NetworkManager.service" >/dev/null 2>&1; then
    echo -e "${GREEN}Network Manager found!${RESET}"
else
    echo -e "${GREEN}Network manager is not installed, please install and configure it to continue${RESET}"
fi

echo -e "\n"
echo 'Choose your option below, to continue:
1 Display current hostname
2 Enable ghost mode 
3 Disable ghost mode
4 Reset generic hostname
5 About'
read -r -p 'Select option: ' option
echo -e "\n"

case $option in
    1)
        echo "Current hostname is: $HOSTNAME"
        ;;

    2)
        echo -e "The following changes are made in Ghost mode:\n\n* Random MAC addresses are generated for a connection on an interface, every single time\n* Random hostname is generated on every boot\n* A new configuration file will be created at /etc/NetworkManager/conf.d\n* ipv6 temporary address extension will be enabled for all currently known connections\n"
        read -r -p "${YELLOW}Do you want to continue? [y/n]: ${RESET}" choice
        
        if [ "$choice" = "y" ]; then
            echo -e "${GREEN}Copying configuration file...${RESET}"
            sudo cp 'nmg.conf' /etc/NetworkManager/conf.d/
            copy=$?
            if [ "$copy" = 0 ]; then
                echo "${GREEN}Configuration applied successfully!${RESET}"
            else
                echo "${RED}Error occurred while copying the configuration file${RED}"
            fi

            echo -e "${GREEN}Applying ipv6 privacy extensions...${RESET}"
            nmcli -g NAME connection show --active | while IFS= read -r connection; do
                type=$(nmcli connection show "$connection" | grep '^connection.type:' | awk '{print $2}')
                if [[ "$type" == "802-11-wireless" || "$type" == "ethernet" ]]; then
                    echo "${GREEN}Modifying $connection (type: $type)${RESET}"
                    nmcli connection modify "$connection" ipv6.ip6-privacy 2
                    modify=$?
                    if [ "$modify" = 0 ]; then
                        echo "${GREEN}ipv6 privacy extensions applied successfully!${RESET}"
                    else
                        echo "${RED}Error occurred while applying the ipv6 privacy extensions${RED}"
                    fi
                else
                    echo "${YELLOW}Skipping $connection (type: $type)${RESET}"
                fi
            done

            echo "${GREEN}Restarting network manager...${RESET}"
            sudo systemctl restart NetworkManager
            restart=$?
            if [ "$restart" = 0 ]; then
                echo "${GREEN}NetworkManager restarted successfully!${RESET}"
            else
                echo "${RED}Error occurred while attempting to restart network manager${RED}"
            fi

            read -r -p "Do you want to set [g]eneric or [r]andom hostnames? " hst_opt
            if [ "$hst_opt" = 'g' ]; then
                echo "host_setting=generic" > "$CONFIG_FILE"
                echo "original_hostname=$HOSTNAME" >> "$CONFIG_FILE"
                echo "${YELLOW}Setting generic hostname using prefix 'DESKTOP'...${RESET}"
                sudo hostnamectl set-hostname "DESKTOP-$(tr -dc 'A-Z0-9' </dev/urandom | head -c7)"
                gn_hst=$?
                if [ "$gn_hst" = 0 ]; then
                    echo "${GREEN}Generic hostname has been set successfully${RESET}"
                else
                    echo "${RED}Failed to set a generic hostname${RESET}"
                fi
            elif [ "$hst_opt" = 'r' ]; then
                echo "host_setting=random" > "$CONFIG_FILE"
                echo "original_hostname=$HOSTNAME" >> "$CONFIG_FILE"
                echo "${YELLOW}Executing the random hostname module...${RESET}"
                sudo bash "nmg_random_host.sh"
                hst_mn=$?
                if [ "$hst_mn" = 0 ]; then
                    echo "${GREEN}Random hostname module executed successfully${RESET}"
                else
                    echo "${RED}Failed to run the random hostname module${RESET}"
                fi
                echo "${YELLOW}Copying the source script...${RESET}"
                sudo cp "nmg_random_host.sh" /etc/systemd/scripts/
                hst_cp=$?
                if [ "$hst_cp" = 0 ]; then
                    echo "${GREEN}Source script copied successfully!${RESET}"
                    sudo chmod 700 /etc/systemd/scripts/nmg_random_host.sh
                else
                    echo "${RED}Error occurred while copying the source script${RED}"
                fi
                echo "${YELLOW}Installing the systemd service...${RESET}"
                sudo cp "nmg_random_host.service" /etc/systemd/system/
                hst_in=$?
                if [ "$hst_in" = 0 ]; then
                    echo "${GREEN}Systemd service installed successfully!${RESET}"
                    sudo systemctl daemon-reload
                    sudo systemctl enable nmg_random_host.service
                    sudo systemctl start nmg_random_host.service
                    echo "${GREEN}Systemd service started and enabled!${RESET}"
                else
                    echo "${RED}Error occurred while installing the systemd service${RED}"
                fi
            else 
                echo -e "${RED}Invalid option was selected!${RESET}"
            fi
        elif [ "$choice" = "n" ]; then
            exit 0
        else
            echo -e "${RED}Invalid option was selected!${RESET}"
        fi
        ;;

    3)
        echo "${YELLOW}Disabling ghost mode...${RESET}"
        
        #stop services
        if [ -f "$CONFIG_FILE" ]; then
            echo "${GREEN}Checking hostname configuration...${RESET}"
            
            if grep -q "host_setting=random" "$CONFIG_FILE"; then
                echo "${YELLOW}Stopping and disabling random hostname service...${RESET}"
                sudo systemctl stop nmg_random_host.service 2>/dev/null
                sudo systemctl disable nmg_random_host.service 2>/dev/null
                echo "${GREEN}Random hostname service stopped and disabled${RESET}"
            fi
        fi

        #remove network manager config
        echo -e "${GREEN}Removing configuration file...${RESET}"
        sudo rm -f /etc/NetworkManager/conf.d/nmg.conf
        rm_conf=$?
        if [ "$rm_conf" = 0 ]; then
            echo "${GREEN}Configuration file removed successfully!${RESET}"
        else
            echo "${YELLOW}Configuration file not found or already removed${RESET}"
        fi

        #restore ipv6 privacy extensions back to normal
        echo -e "${GREEN}Removing ipv6 privacy extensions...${RESET}"
        nmcli -g NAME connection show --active | while IFS= read -r connection; do
            type=$(nmcli connection show "$connection" | grep '^connection.type:' | awk '{print $2}')
            if [[ "$type" == "802-11-wireless" || "$type" == "ethernet" ]]; then
                echo "${GREEN}Modifying $connection (type: $type)${RESET}"
                nmcli connection modify "$connection" ipv6.ip6-privacy 0
                modify=$?
                if [ "$modify" = 0 ]; then
                    echo "${GREEN}IPv6 privacy extensions removed from $connection${RESET}"
                else
                    echo "${RED}Error removing IPv6 privacy from $connection${RESET}"
                fi
            else
                echo "${YELLOW}Skipping $connection (type: $type)${RESET}"
            fi
        done

        #restart network manager to apply changes
        echo "${GREEN}Restarting network manager...${RESET}"
        sudo systemctl restart NetworkManager
        restart=$?
        if [ "$restart" = 0 ]; then
            echo "${GREEN}NetworkManager restarted successfully!${RESET}"
        else
            echo "${RED}Error restarting NetworkManager${RESET}"
        fi

        #restore original hostname
        if [ -f "$CONFIG_FILE" ]; then
            ORIGINAL_HOSTNAME=$(grep "original_hostname=" nmgc.conf | cut -d= -f2)
            
            if [ -n "$ORIGINAL_HOSTNAME" ]; then
                echo "${GREEN}Restoring original hostname: $ORIGINAL_HOSTNAME${RESET}"
                sudo hostnamectl set-hostname "$ORIGINAL_HOSTNAME"
                if [ $? -eq 0 ]; then
                    echo "${GREEN}Hostname restored successfully!${RESET}"
                else
                    echo "${RED}Failed to restore hostname${RESET}"
                fi
            fi

            #remove systemd service
            if grep -q "host_setting=random" "$CONFIG_FILE"; then
                echo "${YELLOW}Cleaning up the random hostname service...${RESET}"
                sudo rm -f /etc/systemd/scripts/nmg_random_host.sh
                sudo rm -f /etc/systemd/system/nmg_random_host.service
                sudo systemctl daemon-reload
                echo "${GREEN}Random hostname service completely removed${RESET}"
            fi

            #remove config
            rm -f nmgc.conf
            echo "${GREEN}Configuration cleaned up${RESET}"
        else
            echo "${YELLOW}No hostname configuration found${RESET}"
        fi

        echo "${GREEN}Ghost mode has been completely disabled!${RESET}"
        echo "${YELLOW}Note: You may need to restart your network connections for all changes to take effect${RESET}"
        ;;

    4) 
        #check the config file first
        if [ -f "$CONFIG_FILE" ] && grep -q "host_setting=random" "$CONFIG_FILE"; then
            echo -e "${RED}╔══════════════════════════════════════════════════╗${RESET}"
            echo -e "${RED}║                     WARNING!                     ║${RESET}"
            echo -e "${RED}╚══════════════════════════════════════════════════╝${RESET}"
            echo -e "${RED}ERROR: Random hostname mode detected!${RESET}"
            echo -e "${YELLOW}Please use option 3 (Disable ghost mode) first to properly${RESET}"
            echo -e "${YELLOW}clean up the random hostname configuration.${RESET}"
            echo -e ""
            echo -e "${RED}Using this option with the random hostname mode will cause${RESET}"
            echo -e "${RED}configuration conflicts and system inconsistencies!${RESET}"
            exit 1
        fi

        echo -e "${RED}╔══════════════════════════════════════════════════╗${RESET}"
        echo -e "${RED}║                     WARNING!                     ║${RESET}"
        echo -e "${RED}╚══════════════════════════════════════════════════╝${RESET}"
        echo -e "${YELLOW}This option is designed for use with generic hostname mode only.${RESET}"
        echo -e "${YELLOW}If you previously used random hostname mode, please use option 3${RESET}"
        echo -e "${YELLOW}(Disable ghost mode) first to properly clean up the configuration.${RESET}"
        echo -e ""
        echo -e "${RED}Using this with random hostname mode may cause configuration conflicts!${RESET}"
        echo -e ""
        
        read -r -p "Do you want to continue? [y/n]: " confirm
        if [[ "$confirm" = "y" ]]; then
            echo "${YELLOW}Resetting generic hostname using prefix 'DESKTOP'...${RESET}"
            sudo hostnamectl set-hostname "DESKTOP-$(tr -dc 'A-Z0-9' </dev/urandom | head -c7)"
            reset_gn_hst=$?
            if [ "$reset_gn_hst" = 0 ]; then
                echo "${GREEN}Generic hostname has been set successfully!${RESET}"
                echo "host_setting=generic" > "$CONFIG_FILE"
                echo "original_hostname=$HOSTNAME" >> "$CONFIG_FILE"
            else
                echo "${RED}Failed to set a generic hostname${RESET}"
            fi
        elif [[ "$confirm" = "n" ]]; then
            bash "nmg.sh"
        else
            echo -e "${RED}Invalid option was selected!${RESET}"
        fi
        ;;

    5)
        echo "Network Manager Ghost"
        echo "A CLI frotend to tweak various privacy settings in network manager"
        echo "Issue tracker: https://github.com/Spectrum75/nmg"
        ;;

    *) 
        echo "${RED}Invalid option was selected!${RESET}"
        ;;
esac
