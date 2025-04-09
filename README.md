# Anonymity Tool Anonyx v1.1

## Overview
Anonyx is a robust anonymity tool designed for Kali Linux or any other Debian-based Distro to automate the configuration of Tor, Proxychains, and secure DNS settings. It enhances your online privacy by enabling anonymous browsing and operations.

## Features
- Automates installation and configuration of Tor, Proxychains, and secure DNS.
- Logs all operations for transparency and troubleshooting.
- Provides a simple CLI menu to enable and disable anonymity mode.
- Verifies Tor anonymity connection status.

## Prerequisites
- **Operating System**: Ensure you are using Kali Linux or any other Debian-based distribution, as this tool is tailored for such environments.
- **Root Access**: Full root privileges are required to modify network configurations and install necessary packages effectively.

## Installation
1. **Clone the Repository**:
    ```bash
    git clone https://github.com/Aryann019x/Anonymity-Tool.git
    cd Anonymity-Tool
    ```

2. **Make the Script Executable**:
    ```bash
    chmod +x Anonyx.sh
    ```
3. **Run the script with root privileges**:
    ```bash
    sudo ./Anonyx.sh
    ```
## Menu Options

**[1] Enable Anonymity**: Configures your system for anonymous browsing.  
**[2] Disable Anonymity**: Restores your original network settings.  
**[3] Show Status**: Displays the current status of anonymity-related services.  
**[4] Exit**: Exits the tool.

## Tool Specifications
- Tor Port: 9050  
- Control Port: 9051  
- DNS Servers:  
 1.1.1.1  
 9.9.9.9  
208.67.222.222
    
- **Files Used**  
Log File: /var/log/anonymity.log  
Proxychains Configuration: /etc/proxychains4.conf  
DNS Configuration: /etc/resolv.conf  
Tor Configuration: /etc/tor/torrc
  
## Verifying the Tool is Working   
Checking Anonymity Mode
- Enable Anonymity Mode:  

```bash
sudo ./Anonyx.sh
# Select option [1] to enable anonymity mode.
```
## Verify Anonymity:

**Check Tor Connection**:
```bash
proxychains4 curl https://check.torproject.org
```
You should see a message indicating that your browser is configured to use Tor.  


**Check Tor Service Status**:
```bash
sudo systemctl status tor
```
Ensure that the Tor service is active.  


**Verify DNS Configuration**:
```bash
cat /etc/resolv.conf
```
The output should show the anonymous DNS servers:

```bash
plaintext
nameserver 1.1.1.1  
nameserver 9.9.9.9  
nameserver 208.67.222.222   
```

**Check Firewall Rules**:
```bash
sudo ufw status verbose  
```

## Disabling Anonymity Mode
- Disable Anonymity:

```bash
sudo ./Anonyx.sh
# Select option [2] to disable anonymity mode.
```

## Verify Restoration:

**Check DNS Configuration**:
```bash
cat /etc/resolv.conf
```
**The output should show your original DNS settings (e.g., Google DNS)**:   
```bash
plaintext   
nameserver 8.8.8.8   
nameserver 8.8.4.4   
```

**Check Internet Connection**:
```bash
curl https://www.example.com
```
Ensure you can browse the internet normally.
Logging All operations are logged in /var/log/anonymity.log.  
This file can be used for troubleshooting and verifying the actions performed by the script.

## CONTRIBUTING
Contributions are welcome! Please submit a pull request or open an issue to discuss any changes or improvements.

## AUTHOR
Aryann019x

## LICENSE
This project is licensed under the MIT License.
