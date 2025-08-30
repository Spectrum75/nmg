#!/usr/bin/env bash
#Colour escape sequences
RED=$'\033[0;31m'
RESET=$'\033[0m' 
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
#config
CONFIG_DIR="$HOME/.config/nmg"

echo "${GREEN}NMG Uninstaller${RESET}"
echo "${YELLOW}Note:${RESET}"
echo -e "${YELLOW}For a complete uninstall, please ensure that you disabled ghost mode from the main script\n${RESET}"
read -r -p "Do you want to continue with the uninstallation? [y/n]: " confirm

if [[ "$confirm" = "y" ]]; then
    #remove aliases from rc files
    if [ -f "$HOME/.bashrc" ]; then
        sed -i '/alias nmg=/d' "$HOME/.bashrc"
        sed -i '/# NMG alias/d' "$HOME/.bashrc"
    fi
    if [ -f "$HOME/.zshrc" ]; then
        sed -i '/alias nmg=/d' "$HOME/.zshrc"
        sed -i '/# NMG alias/d' "$HOME/.zshrc"
    fi
    echo "${GREEN}Removed NMG aliase(s) from rc file(s)${RESET}"
    
    if [ -d "$CONFIG_DIR" ]; then
        rm -rf "$CONFIG_DIR"
        echo "${GREEN}Removed configuration files${RESET}"
    fi
    
    if [ -d "NMG" ]; then
        rm -rf NMG
        echo "${GREEN}Removed NMG installation${RESET}"
    else
        echo "${YELLOW}NMG directory not found${RESET}"
    fi
    
    echo "${GREEN}Uninstall complete!${RESET}"
    
elif [[ "$confirm" = "n" ]]; then
    echo "${GREEN}Uninstall cancelled${RESET}"
else
    echo "${RED}Invalid option was selected!${RESET}"
    exit 1
fi
