#!/bin/bash

# Show install script header
echo "[*] Starting TOR AP setup script..."

# Read in variables from the user
echo -n "Router IP for wlan0 (E.g. 192.168.42.1): "
read ROUTER_IP

echo -n "DHCP wlan0 start (E.g. 192.168.42.100): "
read DHCP_START

echo -n "DHCP wlan0 end (E.g. 192.168.42.200): "
read DHCP_END

echo -n "WLAN SSID (E.g. TORAP): "
read SSID

echo -n "WLAN Password (E.g. wlanpass12311): "
read PSK

echo 
echo "[*] Config:"
echo "Router IP: ${ROUTER_IP}"
echo "DHCP start: ${DHCP_START}"
echo "DHCP end: ${DHCP_END}"
echo "SSID: ${SSID}"
echo "PSK: ${PSK}"
echo

read -r -p "Config OK? (Y/n) " input
if [[ "${input}" =~ ^([yY][eE][sS]|[yY])+$ ]]
then
    echo "[+] Start installing and configuring the necessary tools"
else
    echo "[-] Please restart the script and insert new config."
    exit 1
fi

# Update repository and system
sudo apt update && sudo apt dist-upgrade -y

# Install necessary things for AP & tor etc.
sudo apt -y install hostapd dnsmasq tor unattended-upgrades monit iptables-persistent

# Disable dhcp on wlan0 to set static IP
echo "denyinterfaces wlan0" | sudo tee -a /etc/dhcpcd.conf

# Generate the configuration for the interfaces
echo "auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp

allow-hotplug wlan0
iface wlan0 inet static
    address ${ROUTER_IP}
    netmask 255.255.255.0
    network ${ROUTER_IP:0:-1}0
    broadcast ${ROUTER_IP:0:-1}255
" | sudo tee -a /etc/network/interfaces 

# Create the default config for wlan0 AP
echo "interface=wlan0
driver=nl80211
ssid=${SSID}
hw_mode=g
channel=6
ieee80211n=1
wmm_enabled=1
ht_capab=[HT40][SHORT-GI-20][DSSS_CCK-40]
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_key_mgmt=WPA-PSK
wpa_passphrase=${PSK}
rsn_pairwise=CCMP
" | sudo tee /etc/hostapd/hostapd.conf


# Set path value for the hostapd config
sudo sed -i 's|#DAEMON_CONF=""|DAEMON_CONF="/etc/hostapd/hostapd.conf"|g' /etc/default/hostapd


# Backup default dnsmasq file
sudo mv /etc/dnsmasq.conf /etc/dnsmas.conf-$(date +"%m_%d_%Y").bak

# Create the config file for dnsmasq
echo "interface=wlan0 
listen-address=${ROUTER_IP}
bind-interfaces 
server=8.8.8.8
domain-needed
bogus-priv
dhcp-range=${DHCP_START},${DHCP_END},24h
" | sudo tee /etc/dnsmasq.conf


# Enable packet forwarding to act as a router 
sudo sed -i 's|#net.ipv4.ip_forward=1|net.ipv4.ip_forward=1|g' /etc/sysctl.conf


# Set iptables rules to forward the traffic
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE  
sudo iptables -A FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i wlan0 -o eth0 -j ACCEPT
#####
##### END config for AP

## START config tor

# configure iptables for tor
sudo iptables -t nat -A PREROUTING -i wlan0 -p udp --dport 53 -j REDIRECT --to-ports 53
sudo iptables -t nat -A PREROUTING -i wlan0 -p tcp --syn -j REDIRECT --to-ports 9040



# Write the tor configuration
echo "Log notice file /var/log/tor/notices.log
VirtualAddrNetwork 10.192.0.0/10
AutomapHostsSuffixes .onion,.exit
AutomapHostsOnResolve 1
TransPort 9040
TransListenAddress ${ROUTER_IP}
DNSPort 53
DNSListenAddress ${ROUTER_IP}" | sudo tee -a /etc/tor/torrc

# Create tor log file
sudo touch /var/log/tor/notices.log
sudo chown debian-tor /var/log/tor/notices.log && sudo chmod 644 /var/log/tor/notices.log


# Restart tor service
sudo systemctl restart tor

# Keep routing changes after reboot
sudo sh -c "iptables-save > /etc/iptables.ipv4.nat"
echo "iptables-restore < /etc/iptables.ipv4.nat" | sudo tee -a /etc/rc.local


# Configure monit to restart the TOR service if necessary
echo 'check process gdm with pidfile /var/run/tor/tor.pid
   start program = "/etc/init.d/tor start"
   stop program = "/etc/init.d/tor stop"
' | sudo tee -a /etc/monit/monitrc

# Reload monit and add to startup
sudo monit reload
sudo systemctl enable monit


# reboot to apply all the config
sudo reboot
