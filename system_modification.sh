#!/bin/bash

# The function to display section headers
print_header() {
  echo "======================================="
  echo "  $1"
  echo "======================================="
}

# Function to display success messages
print_success() {
  echo "[SUCCESS] $1"
}

# Function to display error messages
print_error() {
  echo "[ERROR] $1"
}

# Function to check if a package is installed
is_package_installed() {
  dpkg -s "$1" &>/dev/null
}

# Function to check if a service is running
is_service_running() {
  systemctl is-active --quiet "$1"
}

# Function to restart a service
restart_service() {
  systemctl restart "$1"
}

# Function to modify configuration files
modify_config_file() {
  local file="$1"
  local config="$2"
  
  if grep -q "$config" "$file"; then
    print_success "Configuration already set in $file"
  else
    echo "$config" >> "$file"
    print_success "Configuration added to $file"
  fi
}

# Function to add SSH public key to authorized_keys
add_ssh_public_key() {
  local user="$1"
  local key="$2"
  local auth_file="/home/$user/.ssh/authorized_keys"
  
  if grep -q "$key" "$auth_file"; then
    print_success "SSH public key already added for $user"
  else
    echo "$key" >> "$auth_file"
    print_success "SSH public key added for $user"
  fi
}

# Function to create user accounts
create_user_account() {
  local username="$1"
  local sudo_access="$2"
  local ssh_key_rsa="$3"
  local ssh_key_ed25519="$4"
  
  if id "$username" &>/dev/null; then
    print_success "User account $username already exists"
  else
    useradd -m -s /bin/bash "$username"
    print_success "User account $username created"
  fi
  
  if [[ "$sudo_access" == "yes" ]]; then
    usermod -aG sudo "$username"
    print_success "Sudo access added for $username"
  fi
  
  add_ssh_public_key "$username" "$ssh_key_rsa"
  add_ssh_public_key "$username" "$ssh_key_ed25519"
}

# Check and modify hostname
print_header "Hostname"
current_hostname=$(hostname)
desired_hostname="autosrv"

if [[ "$current_hostname" != "$desired_hostname" ]]; then
  hostnamectl set-hostname "$desired_hostname"
  print_success "Hostname updated to $desired_hostname"
else
  print_success "Hostname already set to $desired_hostname"
fi

# Check and modify network configuration
print_header "Network Configuration"
config_file="/etc/netplan/01-netcfg.yaml"
config_data="
network:
  version: 2
  renderer: networkd
  ethernets:
    ens34:
      addresses:
        - 192.168.16.21/24
      gateway4: 192.168.16.1
      nameservers:
        addresses: [192.168.16.1]
        search: [home.arpa, localdomain]
"

modify_config_file "$config_file" "$config_data"

# Check and install required software packages
print_header "Software Installation"
packages=("openssh-server" "apache2" "squid" "ufw")

for package in "${packages[@]}"; do
  if is_package_installed "$package"; then
    print_success "$package is already installed"
  else
    apt-get -qq install "$package"
    print_success "$package installed"
  fi
done

# Configure SSH server
print_header "SSH Server Configuration"
ssh_config_file="/etc/ssh/sshd_config"

# Disable password authentication
if grep -q "^PasswordAuthentication" "$ssh_config_file"; then
  sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' "$ssh_config_file"
else
  echo "PasswordAuthentication no" >> "$ssh_config_file"
fi

# Enable SSH key authentication
if grep -q "^PubkeyAuthentication" "$ssh_config_file"; then
  sed -i 's/^PubkeyAuthentication.*/PubkeyAuthentication yes/' "$ssh_config_file"
else
  echo "PubkeyAuthentication yes" >> "$ssh_config_file"
fi

# Restart SSH service
restart_service "ssh"

# Configure Apache2 web server
print_header "Apache2 Configuration"
apache_config_file="/etc/apache2/ports.conf"
apache_ssl_config_file="/etc/apache2/sites-available/default-ssl.conf"

# Ensure Apache2 listens on ports 80 and 443
if grep -q "Listen 80" "$apache_config_file"; then
  print_success "Apache2 already configured to listen on port 80"
else
  sed -i 's/Listen 80/Listen 80\nListen 443/' "$apache_config_file"
  print_success "Apache2 configured to listen on port 80 and 443"
fi

# Enable SSL module
a2enmod ssl

# Restart Apache2 service
restart_service "apache2"

# Configure Squid web proxy
print_header "Squid Configuration"
squid_config_file="/etc/squid/squid.conf"

# Ensure Squid listens on port 3128
if grep -q "http_port 3128" "$squid_config_file"; then
  print_success "Squid already configured to listen on port 3128"
else
  echo "http_port 3128" >> "$squid_config_file"
  print_success "Squid configured to listen on port 3128"
fi

# Restart Squid service
restart_service "squid"

# Configure UFW firewall
print_header "UFW Firewall Configuration"
ufw default deny incoming
ufw default allow outgoing

# The code below will allow SSH on port 22
ufw allow 22

# The code below will allow HTTP on port 80
ufw allow 80

# The code below will allow HTTPS on port 443
ufw allow 443

# The code below will allow web proxy on port 3128
ufw allow 3128

# The code below will enable UFW firewall
ufw --force enable

# The code below will create user accounts
print_header "User Accounts"
declare -A user_accounts=(
  ["dennis"]="yes ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG4rT3vTt99Ox5kndS4HmgTrKBT8SKzhK4rhGkEVGlCI student@generic-vm"
  ["aubrey"]="no"
  ["captain"]="no"
  ["snibbles"]="no"
  ["brownie"]="no"
  ["scooter"]="no"
  ["sandy"]="no"
  ["perrier"]="no"
  ["cindy"]="no"
  ["tiger"]="no"
  ["yoda"]="no"
)

for username in "${!user_accounts[@]}"; do
  sudo_access="${user_accounts[$username]}"
  ssh_key_rsa=""
  ssh_key_ed25519=""
  
  if [[ "$username" == "dennis" ]]; then
    ssh_key_rsa="${user_accounts[$username+1]}"
    ssh_key_ed25519="${user_accounts[$username+2]}"
  fi
  
    create_user_account "$username" "$sudo_access" "$ssh_key_rsa" "$ssh_key_ed25519"
done

# The code below will display final configuration summary
print_header "Final Configuration Summary"
echo "Hostname: $(hostname)"
echo
echo "Network Configuration:"
echo "  Address: 192.168.16.21/24"
echo "  Gateway: 192.168.16.1"
echo "  DNS Server: 192.168.16.1"
echo "  DNS Search Domains: home.arpa, localdomain"
echo
echo "Software Installed:"
for package in "${packages[@]}"; do
  if is_package_installed "$package"; then
    echo "  $package: Installed"
  else
    echo "  $package: Not installed"
  fi
done
echo
echo "Firewall Configuration:"
echo "  SSH (port 22): Allowed"
echo "  HTTP (port 80): Allowed"
echo "  HTTPS (port 443): Allowed"
echo "  Web Proxy (port 3128): Allowed"
echo
echo "User Accounts:"
for username in "${!user_accounts[@]}"; do
  sudo_access="${user_accounts[$username]}"
  echo "  Username: $username"
  echo "    Sudo Access: $sudo_access"
done

# End of the script

