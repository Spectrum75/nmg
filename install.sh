#!/usr/bin/env bash
#colour escape sequences
RED=$'\033[0;31m'
RESET=$'\033[0m' 
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
#config
CONFIG_DIR="$HOME/.config/nmg"
CONFIG_FILE="$CONFIG_DIR/nmgc.conf"

echo "${YELLOW}Installing NMG...${RESET}"
git clone https://github.com/Spectrum75/nmg
clone=$?

if [ "$clone" = 0 ]; then
    echo "${GREEN}Repository cloned successfully!${RESET}"
    cd "nmg" || { echo "${RED}Failed to enter nmg directory${RESET}"; exit 1; }
    
    echo -e "${YELLOW}Note: For ensuring that the included random hostname script and systemd service are not modified by non-root users, the ownership and group would have to be changed to root."
    echo -e "The file will not be moved anywhere, unless the specific option is selected in the main script for this."
    echo -e "You can continue without this step, however the file could be modified by any regular user, which is a potential security risk.${RESET}"
    
    read -r -p "Do you want to set root ownership? [y/n]: " confirm
    if [[ "$confirm" = "y" ]]; then
        echo "${YELLOW}Changing ownership and permissions...${RESET}"
        sudo chown root:root nmg_random_host.service 2>/dev/null || echo "${RED}Changing ownership of service file failed${RESET}"
        sudo chown root:root nmg_random_host.sh 2>/dev/null || echo "${RED}Changing ownership of script failed${RESET}"
        sudo chmod 644 nmg_random_host.service 2>/dev/null || echo "${RED}Changing permission of service failed${RESET}"
        sudo chmod 755 nmg_random_host.sh 2>/dev/null || echo "${RED}Changing permission of script failed${RESET}"
        chmod +x uninstall.sh
        chmod +x nmg.sh
        echo "${GREEN}Secure ownership and permissions set successfully!${RESET}"
    elif [[ "$confirm" = "n" ]]; then
        echo "${GREEN}Skipped ownership setting${RESET}"
        chmod 644 nmg_random_host.service 2>/dev/null
        chmod 755 nmg_random_host.sh 2>/dev/null
        chmod +x uninstall.sh
        chmod +x nmg.sh
    else
        echo "${RED}Invalid option was selected!${RESET}"
        exit 1
    fi
    
    echo "${YELLOW}Setting up configuration...${RESET}"
    mkdir -p "$CONFIG_DIR" || echo "${RED}Creating directory for the configuration file failed${RESET}"
    
    if [ -f "nmgc.conf" ]; then
        mv "nmgc.conf" "$CONFIG_FILE" || echo "${RED}Moving configuration file failed${RESET}"
        echo "${GREEN}Configuration file moved to $CONFIG_FILE${RESET}"
    else
        echo "${YELLOW}No configuration file found${RESET}"
    fi
    
    chmod +x nmg.sh
    
    CURRENT_SHELL=$(basename "$SHELL")
    NMG_PATH="$(pwd)/nmg.sh"
    
    #current shell
    if [ "$CURRENT_SHELL" = "zsh" ] && [ -f "$HOME/.zshrc" ]; then
        SHELL_CONFIG="$HOME/.zshrc"
    elif [ "$CURRENT_SHELL" = "bash" ] && [ -f "$HOME/.bashrc" ]; then
        SHELL_CONFIG="$HOME/.bashrc"
    else
        if [ -f "$HOME/.bashrc" ]; then
            SHELL_CONFIG="$HOME/.bashrc"
        elif [ -f "$HOME/.zshrc" ]; then
            SHELL_CONFIG="$HOME/.zshrc"
        else
            echo "${RED}Neither .bashrc nor .zshrc were found${RESET}"
            echo "${YELLOW}Alias will not be added. You can run the script directly with ./nmg.sh${RESET}"
            SHELL_CONFIG=""
        fi
    fi
    
    #add alias to the main shell, if found
    if [ -n "$SHELL_CONFIG" ]; then
        if ! grep -q "alias nmg=" "$SHELL_CONFIG"; then
            echo "" >> "$SHELL_CONFIG"
            echo "# NMG alias" >> "$SHELL_CONFIG"
            echo "alias nmg='$NMG_PATH'" >> "$SHELL_CONFIG"
            echo "${GREEN}Added 'nmg' alias to $SHELL_CONFIG${RESET}"
            echo "${YELLOW}Run 'source $SHELL_CONFIG' or restart your terminal to use: nmg${RESET}"
        else
            echo "${YELLOW}NMG alias already exists in $SHELL_CONFIG${RESET}"
        fi
    fi
    
    echo "${GREEN}Successfully installed NMG!${RESET}"
    echo "${YELLOW}You can now run the script with: ./nmg.sh${RESET}"
    echo "${YELLOW}Or use the alias: nmg${RESET}"
    
else
    echo "${RED}Cloning the repository failed, please check your connection and try again${RESET}"
    exit 1
fi
