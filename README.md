<img width="700" height="650" alt="header" src="https://github.com/user-attachments/assets/0ccd563c-aa4f-40c0-a974-ab1dce8e3152" />

Network Manager Ghost (NMG) is a CLI frotend to tweak various privacy settings in network manager

## Available Modes:

### Display Current Hostname:

Gets the current system hostname (spoofed or original) and displays it.

### Enable Ghost Mode:

Enables Mac address randomization for all available connection, this address also changes during every connection. The hostname is protected from being sent to the DHCP server as well. The network would only see the spoofed Mac address for both IPv4 and IPv6 (due to IPv6 Privacy Extensions).

Checks for captive portals also get disabled in this mode. If you need to access captive portals, use a site that is dedicated for that such as http://neverssl.com or http://httpforever.com.

### Disable Ghost Mode:

Removes the NetworkManager privacy configuration and restores your system's default network behavior. Your real Mac address and hostname will be visible to the network again.

### Switch To A Generic Windows Based Hostname/Regenerate It:

Requires running ghost mode once, uses a stock Windows like hostname (eg: DESKTOP-ABCD123) instead of not sending hostname at all. This is useful on certain networks where not having a hostname might cause issues. Running it after enabling it earlier regenerates the current hostname using the same style.

### Switch Back To Ghost Mode:

Restores the original hostname and then enables ghost mode. Since ghost mode doesn't send any hostname, the 
restored hostname is kept safe.

### About This Script:

Pretty self explanatory :)

## Installation:

Always check scripts from the internet before executing them. NMG is written fully in bash, and is simple to understand for almost all Linux users.

Run the following oneliner to start the install.sh script:

`wget https://raw.githubusercontent.com/Spectrum75/nmg/refs/heads/main/install.sh && chmod +x install.sh && ./install.sh`

## Uninstallation:

Run `uninstall.sh` and proceed with the prompts.
