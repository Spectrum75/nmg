#!/usr/bin/env bash
function error {
  echo -e "\\e[91m$1\\e[39m"
  exit 1
}

function warning {
  echo -e "\\e[91m$1\\e[39m"
}

function info {
  echo -e "\\e[033m$1\\e[39m"
}

function success {
  echo -e "\\e[032m$1\\e[39m"
}

#config directory
CONFIG_DIR="$HOME/.config/nmg"
CONFIG_FILE="$CONFIG_DIR/nmgc.conf"
mkdir -p "$CONFIG_DIR"

echo '
.__   __. .___  ___.   _______ 
|  \ |  | |   \/   |  /  _____|
|   \|  | |  \  /  | |  |  __  
|  . `  | |  |\/|  | |  | |_ | 
|  |\   | |  |  |  | |  |__| | 
|__| \__| |__|  |__|  \______| 

'
if [ -f "$CONFIG_FILE" ]; then
    if grep -q "update_check=1" "$CONFIG_FILE"; then
        info "Checking for updates..."
        cd "$HOME"/nmg || error "Failed to change directory"
        localhash="$(git rev-parse HEAD)"
        latesthash="$(git ls-remote https://github.com/spectrum75/nmg HEAD | awk '{print $1}')"
        if [ -z "$latesthash" ]; then #check if latesthash var is empty 
            error "Failed to check for updates. Please try again or disable update check in the configuration file"
        elif [ "$localhash" != "$latesthash" ] && [ ! -z "$latesthash" ] && [ ! -z "$localhash" ]; then
            info "Updating to the new version..."
            git clean -fd
            git reset --hard
            git pull https://github.com/spectrum75/nmg HEAD || error "Update failed, please check your connection and try again"
            chmod +x nmg.sh
            exec "$0" "$@"
        else
            success "You are up to date!"
        fi
    elif grep -q "update_check=0" "$CONFIG_FILE"; then
        info "Update check is disabled in the configuration"
    else
        info "Invalid or missing update_check value in configuration"
    fi
else
    info "Configuration file not found, updates disabled"
fi

info "Checking for network manager..."
if systemctl list-unit-files "NetworkManager.service" >/dev/null 2>&1; then
    success "Network Manager found!"
else
    error "Network manager is not installed, please install and configure it to continue"
fi

echo -e "\n"
echo 'Choose your option below, to continue:
1 Display current hostname
2 Enable ghost mode 
3 Disable ghost mode
4 Switch to a generic Windows based hostname/regenerate it
5 Switch back to ghost mode
6 About this script'
read -r -p 'Select option: ' option
echo -e "\n"

case $option in
    1)
        echo "Current hostname is: $HOSTNAME"
        ;;

    2)
        echo -e "The following changes are made in Ghost mode:"
        echo -e "\n"
        echo -e "* Random MAC addresses are generated during every connection"
        echo -e "* IPv6 temporary address extensions are enabled"
        echo -e "* NetworkManager is configured to not send your hostname to DHCP servers"
        echo -e "* A configuration file is created at /etc/NetworkManager/conf.d/nmg.conf"
        echo -e "\n"
        read -r -p "$(info "Do you want to continue? [y/n]: ")" choice
        
        if [[ "$choice" == "y" ]]; then
            sed -i '/^host_setting=/d' "$CONFIG_FILE"
            echo "host_setting=ghost" >> "$CONFIG_FILE"

            success "Applying NetworkManager ghost configuration..."
            sudo cp 'nmg.conf' /etc/NetworkManager/conf.d/
            if [ $? -eq 0 ]; then
                success "Configuration applied successfully!"
            else
                error "Error occurred while copying the configuration file"
            fi

            success "Restarting NetworkManager to apply changes..."
            sudo systemctl restart NetworkManager
            if [ $? -eq 0 ]; then
                success "NetworkManager restarted successfully!"
                success "Ghost mode is now enabled!"
            else
                warning "Error restarting NetworkManager"
            fi
        elif [[ "$choice" == "n" ]]; then
            exec "$0" "$@"
        else
            warning "Invalid option was selected!"
        fi
        ;;

    3)
        info "Disabling ghost mode..."
        
        success "Removing NetworkManager configuration..."
        sudo rm -f /etc/NetworkManager/conf.d/nmg.conf
        
        success "Restarting NetworkManager to restore defaults..."
        sudo systemctl restart NetworkManager
        if [ $? -eq 0 ]; then
            success "NetworkManager restarted successfully!"
        else
            warning "Error restarting NetworkManager"
        fi

        if [ -f "$CONFIG_FILE" ]; then
            sed -i '/^host_setting=/d' "$CONFIG_FILE"
            success "Local configuration cleaned up."
        fi

        success "Ghost mode has been completely disabled!"
        ;;

    4) 
        info "This will generate a new generic Windows style hostname (like: DESKTOP-XXXXXXX)"
        info "and configure NetworkManager to send that to DHCP servers, making the"
        info "system appear as a normal Windows PC on the network."
        echo -e "\n"
        read -r -p "Do you want to continue? [y/n]: " confirm

        if [[ "$confirm" == "y" ]]; then
            info "Generating new generic Windows hostname..."

            if ! grep -q "^original_hostname=" "$CONFIG_FILE" 2>/dev/null; then
                echo "original_hostname=$(hostname)" >> "$CONFIG_FILE"
            fi

            NEW_HOST="DESKTOP-$(tr -dc 'A-Z0-9' </dev/urandom | head -c 7)"
            sudo hostnamectl set-hostname "$NEW_HOST"

            if [ $? -eq 0 ]; then
                sed -i '/^host_setting=/d' "$CONFIG_FILE"
                echo "host_setting=generic" >> "$CONFIG_FILE"
                success "Hostname set to '$NEW_HOST'"
            else
                warning "Failed to set hostname. Please check permissions"
            fi

            if [ -f /etc/NetworkManager/conf.d/nmg.conf ]; then
                sudo sed -i 's/^ipv4.dhcp-send-hostname=0/ipv4.dhcp-send-hostname=1/' /etc/NetworkManager/conf.d/nmg.conf
                sudo sed -i 's/^ipv6.dhcp-send-hostname=0/ipv6.dhcp-send-hostname=1/' /etc/NetworkManager/conf.d/nmg.conf
                sudo systemctl restart NetworkManager
                success "Generic hostname set successfully!"
            else
                info "nmg.conf not found in /etc/NetworkManager/conf.d/. Only the generic hostname tweak would be applied"
            fi

        elif [[ "$confirm" == "n" ]]; then
            exec "$0" "$@";
        else
            warning "Invalid option was selected!"
        fi
        ;;

    5)
        info "This will restore the original hostname and then enable ghost mode"
        echo -e "\n"
        read -r -p "Do you want to continue? [y/n]: " confirm

        if [[ "$confirm" == "y" ]]; then
            info "Restoring original hostname..."

            if [ -f "$CONFIG_FILE" ] && grep -q "^original_hostname=" "$CONFIG_FILE"; then
                ORIGINAL_HOSTNAME=$(grep "^original_hostname=" "$CONFIG_FILE" | cut -d= -f2)

                if [ -n "$ORIGINAL_HOSTNAME" ]; then
                    sudo hostnamectl set-hostname "$ORIGINAL_HOSTNAME"
                    if [ $? -eq 0 ]; then
                        sed -i '/^original_hostname=/d' "$CONFIG_FILE"
                        sed -i '/^host_setting=/d' "$CONFIG_FILE"
                        echo "host_setting=ghost" >> "$CONFIG_FILE"
                        
                        success "System hostname restored to '$ORIGINAL_HOSTNAME'"
                    else
                        warning "Failed to restore system hostname. Please check permissions"
                    fi
                else
                    warning "Original hostname value is empty in configuration!"
                fi
            else
                info "No original hostname was found. Skipping hostname restoration."
            fi

            info "Ensuring ghost mode configuration..."
            sudo cp 'nmg.conf' /etc/NetworkManager/conf.d/

            sudo sed -i 's/^ipv4.dhcp-send-hostname=.*/ipv4.dhcp-send-hostname=0/' /etc/NetworkManager/conf.d/nmg.conf
            sudo sed -i 's/^ipv6.dhcp-send-hostname=.*/ipv6.dhcp-send-hostname=0/' /etc/NetworkManager/conf.d/nmg.conf

            sudo systemctl restart NetworkManager
            success "Ghost mode enabled!"
        elif [[ "$confirm" == "n" ]]; then
            exec "$0" "$@";
        else
            warning "Invalid option was selected!"
        fi
        ;;

    6)
        echo "Network Manager Ghost"
        echo "A CLI frontend to tweak various privacy settings in NetworkManager"
        echo "Issue tracker: https://github.com/Spectrum75/nmg"
        ;;

    *) 
        error "Invalid option was selected!"
        ;;
esac
