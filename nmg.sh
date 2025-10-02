#!/usr/bin/env bash
#error function
function error {
  echo -e "\\e[91m$1\\e[39m"
  exit 1
}
#warning function
function warning {
  echo -e "\\e[91m$1\\e[39m"
}
#info function
function info {
  echo -e "\\e[033m$1\\e[39m"
}
#success function
function success {
  echo -e "\\e[032m$1\\e[39m"
}
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
        info "Update check explicitly disabled in the configuration"
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
    success "Network manager is not installed, please install and configure it to continue"
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
        echo -e "The following changes are made in Ghost mode:"
        echo -e "\n"
        echo -e "* Random MAC addresses are generated for a connection on an interface, every single time"
        echo -e "* Random hostname is generated on every boot"
        echo -e "* A new configuration file will be created at /etc/NetworkManager/conf.d"
        echo -e "* IPv6 temporary address extension will be enabled for all currently known connections"
        echo -e "\n"
        read -r -p "$(info "Do you want to continue? [y/n]: ")" choice
        
        if [ "$choice" = "y" ]; then
            success "Copying configuration file..."
            sudo cp 'nmg.conf' /etc/NetworkManager/conf.d/
            copy=$?
            if [ "$copy" = 0 ]; then
                success "Configuration applied successfully!"
            else
                error "Error occurred while copying the configuration file"
            fi

            success "Applying IPv6 privacy extensions..."
            nmcli -g NAME connection show --active | while IFS= read -r connection; do
                type=$(nmcli connection show "$connection" | grep '^connection.type:' | awk '{print $2}')
                if [[ "$type" == "802-11-wireless" || "$type" == "ethernet" ]]; then
                    success "Modifying $connection (type: $type)"
                    nmcli connection modify "$connection" ipv6.ip6-privacy 2
                    modify=$?
                    if [ "$modify" = 0 ]; then
                        success "IPv6 privacy extensions applied successfully!"
                    else
                        error "Error occurred while applying the IPv6 privacy extensions"
                    fi
                else
                    info "Skipping $connection (type: $type)"
                fi
            done

            success "Restarting network manager..."
            sudo systemctl restart NetworkManager
            restart=$?
            if [ "$restart" = 0 ]; then
                success "NetworkManager restarted successfully!"
            else
                error "An error occurred while attempting to restart network manager"
            fi

            read -r -p "Do you want to set [g]eneric or [r]andom hostnames? " hst_opt
            if [ "$hst_opt" = 'g' ]; then
                echo "host_setting=generic" > "$CONFIG_FILE"
                echo "original_hostname=$HOSTNAME" >> "$CONFIG_FILE"
                info "Setting generic hostname using prefix 'DESKTOP'..."
                sudo hostnamectl set-hostname "DESKTOP-$(tr -dc 'A-Z0-9' </dev/urandom | head -c7)"
                gn_hst=$?
                if [ "$gn_hst" = 0 ]; then
                    success "Generic hostname has been set successfully"
                else
                    error "Failed to set a generic hostname"
                fi
            elif [ "$hst_opt" = 'r' ]; then
                echo "host_setting=random" > "$CONFIG_FILE"
                echo "original_hostname=$HOSTNAME" >> "$CONFIG_FILE"
                info "Executing the random hostname module..."
                sudo bash "nmg_random_host.sh"
                hst_mn=$?
                if [ "$hst_mn" = 0 ]; then
                    success "Random hostname module executed successfully"
                else
                    error "Failed to run the random hostname module"
                fi
                info "Copying the source script..."
                sudo cp "nmg_random_host.sh" /etc/systemd/scripts/
                hst_cp=$?
                if [ "$hst_cp" = 0 ]; then
                    success "Source script copied successfully!"
                    sudo chmod 700 /etc/systemd/scripts/nmg_random_host.sh
                else
                    error "Error occurred while copying the source script"
                fi
                info "Installing the systemd service..."
                sudo cp "nmg_random_host.service" /etc/systemd/system/
                hst_in=$?
                if [ "$hst_in" = 0 ]; then
                    success "Systemd service installed successfully!"
                    sudo systemctl daemon-reload
                    sudo systemctl enable nmg_random_host.service
                    sudo systemctl start nmg_random_host.service
                    success "Systemd service started and enabled!"
                else
                    error "Error occurred while installing the systemd service"
                fi
            else 
                error "Invalid option was selected!"
            fi
        elif [ "$choice" = "n" ]; then
            exit 0
        else
            warning "Invalid option was selected!"
        fi
        ;;

    3)
        info "Disabling ghost mode..."
        
        #stop services
        if [ -f "$CONFIG_FILE" ]; then
            success "Checking hostname configuration..."
            
            if grep -q "host_setting=random" "$CONFIG_FILE"; then
                info "Stopping and disabling random hostname service..."
                sudo systemctl stop nmg_random_host.service 2>/dev/null
                sudo systemctl disable nmg_random_host.service 2>/dev/null
                success "Random hostname service stopped and disabled"
            fi
        fi

        #remove network manager config
        success "Removing configuration file..."
        sudo rm -f /etc/NetworkManager/conf.d/nmg.conf
        rm_conf=$?
        if [ "$rm_conf" = 0 ]; then
            success "Configuration file removed successfully!"
        else
            info "Configuration file not found or already removed"
        fi

        #restore IPv6 privacy extensions back to normal
        success "Removing IPv6 privacy extensions..."
        nmcli -g NAME connection show --active | while IFS= read -r connection; do
            type=$(nmcli connection show "$connection" | grep '^connection.type:' | awk '{print $2}')
            if [[ "$type" == "802-11-wireless" || "$type" == "ethernet" ]]; then
                success "Modifying $connection (type: $type)"
                nmcli connection modify "$connection" ipv6.ip6-privacy 0
                modify=$?
                if [ "$modify" = 0 ]; then
                    success "IPv6 privacy extensions removed from $connection"
                else
                    warning "Error removing IPv6 privacy from $connection"
                fi
            else
                info "Skipping $connection (type: $type)"
            fi
        done

        #restart network manager to apply changes
        success "Restarting network manager..."
        sudo systemctl restart NetworkManager
        restart=$?
        if [ "$restart" = 0 ]; then
            success "NetworkManager restarted successfully!"
        else
            warning "Error restarting NetworkManager"
        fi

        #restore original hostname
        if [ -f "$CONFIG_FILE" ]; then
            ORIGINAL_HOSTNAME=$(grep "original_hostname=" nmgc.conf | cut -d= -f2)
            
            if [ -n "$ORIGINAL_HOSTNAME" ]; then
                success "Restoring original hostname: $ORIGINAL_HOSTNAME"
                sudo hostnamectl set-hostname "$ORIGINAL_HOSTNAME"
                if [ $? -eq 0 ]; then
                    success "Hostname restored successfully!"
                else
                    warning "Failed to restore hostname"
                fi
            fi

            #remove systemd service
            if grep -q "host_setting=random" "$CONFIG_FILE"; then
                info "Cleaning up the random hostname service..."
                sudo rm -f /etc/systemd/scripts/nmg_random_host.sh
                sudo rm -f /etc/systemd/system/nmg_random_host.service
                sudo systemctl daemon-reload
                success "Random hostname service completely removed"
            fi

            #remove config
            rm -f nmgc.conf
            success "Configuration cleaned up"
        else
            info "No hostname configuration found$"
        fi

        success "Ghost mode has been completely disabled!"
        info "Note: You may need to restart your network connections for all changes to take effect"
        ;;

    4) 
        #check the config file first
        if [ -f "$CONFIG_FILE" ] && grep -q "host_setting=random" "$CONFIG_FILE"; then
            warning "╔══════════════════════════════════════════════════╗"
            warning "║                     WARNING!                     ║"
            warning "╚══════════════════════════════════════════════════╝"
            warning "ERROR: Random hostname mode detected!$"
            info "Please use option 3 (Disable ghost mode) first to properly"
            info "clean up the random hostname configuration."
            echo -e ""
            warning "Using this option with the random hostname mode will cause$"
            warning "configuration conflicts and system inconsistencies!$"
            exit 1
        fi

        warning "╔══════════════════════════════════════════════════╗"
        warning "║                     WARNING!                     ║"
        warning "╚══════════════════════════════════════════════════╝"
        info "This option is designed for use with generic hostname mode only."
        info "If you previously used random hostname mode, please use option 3"
        info "(Disable ghost mode) first to properly clean up the configuration."
        echo -e ""
        warning "Using this with random hostname mode may cause configuration conflicts!"
        echo -e "\n"
        read -r -p "Do you want to continue? [y/n]: " confirm
        if [[ "$confirm" = "y" ]]; then
            info "Resetting generic hostname using prefix 'DESKTOP'..."
            sudo hostnamectl set-hostname "DESKTOP-$(tr -dc 'A-Z0-9' </dev/urandom | head -c7)"
            reset_gn_hst=$?
            if [ "$reset_gn_hst" = 0 ]; then
                success "Generic hostname has been set successfully!"
                echo "host_setting=generic" > "$CONFIG_FILE"
                echo "original_hostname=$HOSTNAME" >> "$CONFIG_FILE"
            else
                echo "Failed to set a generic hostname"
            fi
        elif [[ "$confirm" = "n" ]]; then
            clear
            exec "$0" "$@"
        else
            echo "Invalid option was selected!"
        fi
        ;;

    5)
        echo "Network Manager Ghost"
        echo "A CLI frotend to tweak various privacy settings in network manager"
        echo "Issue tracker: https://github.com/Spectrum75/nmg"
        ;;

    *) 
        error "Invalid option was selected!"
        ;;
esac
