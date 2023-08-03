#!/bin/bash

# This code helps to implement commands by using SSH
function run_ssh_command() {
    local host=$1
    local cmd=$2
    ssh remoteadmin@$host $cmd
}

# Target 1
 
# Target1-mgmt (172.16.1.10)
target1_mgmt="172.16.1.10"

# This function helps to change the system name to loghost
run_ssh_command $target1_mgmt "sudo hostnamectl set-hostname loghost"
echo "target1-mgmt hostname changed to loghost."

# Modify IP address to 192.168.1.3
run_ssh_command $target1_mgmt "sudo ip addr add 192.168.1.3/24 dev eth0"
echo "target1-mgmt IP adress changed to 192.168.1.3."

# Add a webhost to /etc/hosts
run_ssh_command $target1_mgmt "echo '192.168.1.4 webhost' | sudo tee -a /etc/hosts"
echo "Webhost added to /etc/hosts file on target1-mgmt."

# Install ufw and allow connections to port 514/udp from the mgmt network
run_ssh_command $target1_mgmt "sudo apt update && sudo apt install -y ufw"
run_ssh_command $target1_mgmt "sudo ufw allow from 172.16.1.0/24 to any port 514 proto udp"
echo "UFW on target1-mgmt is updated to allow connections to port 514/udp from mgmt network."

# For configuring rsyslog to listen for UDP connections
run_ssh_command $target1_mgmt "sudo sed -i '/^#module(load=\"imudp\")/s/^#//; /^#input(type=\"imudp\"/s/^#//;' /etc/rsyslog.conf"
run_ssh_command $target1_mgmt "sudo systemctl restart rsyslog"
echo "rsyslog on target1-mgmt is upgraded to listen for UDP connections."

# Target 2
# Target2-mgmt (172.16.1.11)
target2_mgmt="172.16.1.11"

# Modify hostname to webhost
run_ssh_command $target2_mgmt "sudo hostnamectl set-hostname webhost"
echo "target2-mgmt hostname is changed to webhost."

# Modify IP address to 192.168.1.4
run_ssh_command $target2_mgmt "sudo ip addr add 192.168.1.4/24 dev eth0"
echo "target2-mgmt IP address changed to 192.168.1.4."

# Add loghost to /etc/hosts 
run_ssh_command $target2_mgmt "echo '192.168.1.3 loghost' | sudo tee -a /etc/hosts"
echo "Loghost is inserted to /etc/hosts file on target2-mgmt."

# Install UFW and allow port 80/tcp from any source
run_ssh_command $target2_mgmt "sudo apt update && sudo apt install -y ufw"
run_ssh_command $target2_mgmt "sudo ufw allow 80/tcp"
echo "UFW on target2-mgmt configured to allow connections to port 80/tcp."

# Install Apache2
run_ssh_command $target2_mgmt "sudo apt update && sudo apt install -y apache2"
echo "Apache2 is installed on target2-mgmt."

# Configuring rsyslog for sending logs to loghost
run_ssh_command $target2_mgmt "echo '*.* @loghost' | sudo tee -a /etc/rsyslog.conf"
run_ssh_command $target2_mgmt "sudo systemctl restart rsyslog"
echo "rsyslog on target2-mgmt is upgraded to send logs to loghost."

# For configuring the NMS /etc/hosts file
echo "$target1_mgmt loghost" | sudo tee -a /etc/hosts
echo "$target2_mgmt webhost" | sudo tee -a /etc/hosts

# Verifying the web page and syslog entries
if firefox http://webhost &>/dev/null; then
    echo "Successfully retrieved the default Apache web page from webhost."
    if ssh remoteadmin@loghost grep -q "webhost" /var/log/syslog; then
        echo "Webhost logs found in loghost's syslog."
        echo "Configuration update is successful!"
    else
        echo "Webhost logs not found in loghost's syslog."
        echo "Configuration update is failed to send logs from webhost to loghost."
    fi
else
    echo "Unable to retrieve Apache web page from webhost."
    echo "Configuration update failed to install Apache on webhost."
fi

#End of the script
