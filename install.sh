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
    
    echo "${YELLOW}Setting up configuration...${RESET}"
    mkdir -p "$CONFIG_DIR" || echo "${RED}Creating directory for the configuration file failed${RESET}"
    
    if [ -f "nmgc.conf" ]; then
        cp "nmgc.conf" "$CONFIG_FILE" || echo "${RED}Copying configuration file failed${RESET}"
        echo "${GREEN}Configuration file copied to $CONFIG_FILE${RESET}"
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
    #rm installer
    rm -f "$0"
    echo "${GREEN}Successfully installed NMG!${RESET}"
    echo "${YELLOW}You can now run the script with: ./nmg.sh${RESET}"
    echo "${YELLOW}Or use the alias: nmg${RESET}"
    
else
    echo "${RED}Cloning the repository failed, please check your connection and try again${RESET}"
    exit 1
fi
