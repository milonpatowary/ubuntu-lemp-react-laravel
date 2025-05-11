#!/bin/bash
#
# This script automates the installation and configuration of Nginx, PHP-FPM,
# and MySQL on Ubuntu for running a React/Vite.js and PHP (Laravel) application.
#
# Intended to be run on Ubuntu 18.04/20.04/22.04.  May need adjustments for other versions.
#
# IMPORTANT:
#   - Run this script with sudo privileges:  sudo bash setup_web_server.sh
#   - The script assumes a basic level of familiarity with the command line.
#   - It's HIGHLY recommended to back up any critical data before running this script.
#   - The script will attempt to set a MySQL root password.
#     If you have already set one, you may need to modify the script or handle it manually.
#   -  The script uses 'your_domain.com' as a placeholder.  You MUST change this
#     to your actual domain name or use 'localhost' for testing.
#   - The script assumes your React/Vite.js build is in /var/www/html and PHP (Laravel) backend is in /var/www/backend
#

set -e   # Exit immediately if a command exits with a non-zero status.
#set -x #Uncomment this to debug and see all commands

# --- Helper Functions ---

# Function to display colored output
_info() {
  printf "\e[34mINFO: %s\e[0m\n" "$1"
}

_warn() {
  printf "\e[33mWARN: %s\e[0m\n" "$1"
}

_error() {
  printf "\e[31mERROR: %s\e[0m\n" "$1"
  exit 1
}

_success() {
  printf "\e[32mSUCCESS: %s\e[0m\n" "$1"
}

# Function to check if a command is installed
_command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Function to execute a command and handle errors
_execute() {
  _info "Running: $1"
  eval "$1" || _error "Command '$1' failed."
}

# Function to check and install a package
_check_and_install_package() {
  if ! _command_exists "$1"; then
    _info "Installing package: $1"
    _execute "sudo apt update"
    _execute "sudo apt install -y $1"
  else
    _info "Package '$1' is already installed."
  fi
}

# Function to create a file with content
_create_file() {
  local filepath="$1"
  local content="$2"
  _info "Creating file: $filepath"
  echo "$content" | sudo tee "$filepath" >/dev/null
}

# Function to check if a file exists
_file_exists() {
  if [ -f "$1" ]; then
    return 0 # File exists
  else
    return 1 # File does not exist
  fi
}
# --- Main Script ---

_info "Starting web server setup (Nginx, PHP, MySQL) for React/Vite.js and PHP (Laravel) application..."

# --- 1. System Update ---
_info "Updating system packages..."
_execute "sudo apt update"
_execute "sudo apt upgrade -y"

# --- 2. Install Nginx ---
_check_and_install_package "nginx"
_execute "sudo systemctl start nginx"
_execute "sudo systemctl enable nginx"
_success "Nginx installed and started."

# --- 3. Install PHP and PHP-FPM ---
_check_and_install_package "php-fpm"
_check_and_install_package "php-cli" # Install the PHP CLI.
_check_and_install_package "php-mysql"
_check_and_install_package "php-json"
_check_and_install_package "php-gd"
_check_and_install_package "php-curl"
_check_and_install_package "php-mbstring"
_check_and_install_package "php-xml"
_check_and_install_package "php-zip"

# Determine PHP version
PHP_VERSION=$(_execute "php -v | grep 'PHP' | awk '{print \$2}' | cut -d'.' -f1")

_execute "sudo systemctl start php${PHP_VERSION}-fpm.service"
_execute "sudo systemctl enable php${PHP_VERSION}-fpm.service"
_success "PHP and PHP-FPM installed and started."

# --- 4. Install MySQL Server ---
_check_and_install_package "mysql-server"
_check_and_install_package "mysql-client"

# Set MySQL root password.  The following command *should* work on a clean install.
# If it doesn't, you'll need to handle the password setting manually.
_info "Setting MySQL root password..."
_execute "sudo mysql -u root -e \"ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'MyNewRootPassword123!';\"" #Hardcoded Password!

#Run the mysql secure installation
_execute "sudo mysql_secure_installation"

_execute "sudo systemctl start mysql.service"
_execute "sudo systemctl enable mysql.service"
_success "MySQL installed and started."

# --- 5. Configure Nginx for React and PHP ---
REACT_ROOT="/var/www/html"
PHP_ROOT="/var/www/backend"
SERVER_NAME="your_domain.com" # CHANGE THIS TO YOUR ACTUAL DOMAIN NAME!

# Create Directories
sudo mkdir -p "$REACT_ROOT"
sudo mkdir -p "$PHP_ROOT"

# Nginx configuration for React and PHP (combined)
NGINX_CONFIG="
server {
    listen 80;
    server_name $SERVER_NAME;
    root $REACT_ROOT;
    index index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    location /api/ {
        alias $PHP_ROOT/public; # Point alias to Laravel's public directory
        index index.php;
        try_files \$uri \$uri/ /api/index.php?\$query_string;

        location ~ \.php$ {
            include snippets/fastcgi-php.conf;
            fastcgi_pass unix:/run/php/php${PHP_VERSION}-fpm.sock;
            fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
            include fastcgi_params;
        }
    }

    location ~ /\.well-known/acme-challenge {
        allow all;
    }
}
"

_create_file "/etc/nginx/sites-available/$SERVER_NAME" "$NGINX_CONFIG"
_execute "sudo ln -sf /etc/nginx/sites-available/$SERVER_NAME /etc/nginx/sites-enabled/"

# Disable default site
if _file_exists "/etc/nginx/sites-enabled/default"; then
  _execute "sudo rm /etc/nginx/sites-enabled/default"
fi
_execute "sudo nginx -t"
_execute "sudo systemctl reload nginx"
_success "Nginx configured for React and PHP."

# --- 6. Set correct permissions ---
_info "Setting file permissions..."
_execute "sudo chown -R www-data:www-data $REACT_ROOT"
_execute "sudo chown -R www-data:www-data $PHP_ROOT"
_execute "sudo chmod -R 755 $REACT_ROOT"
_execute "sudo chmod -R 755 $PHP_ROOT"
_success "File permissions set."

# --- 7. Install Composer ---
_info "Installing Composer..."
COMPOSER_INSTALLER_URL="https://getcomposer.org/installer"
COMPOSER_HASH="$(curl -sS $COMPOSER_INSTALLER_URL | sha256sum | awk '{print $1}')"
_execute "sudo apt install -y curl"
_execute "curl -sS $COMPOSER_INSTALLER_URL -o composer-setup.php"
_execute "if [ \"$(sha256sum composer-setup.php | awk '{print $1}')\" = \"$COMPOSER_HASH\" ]; then echo 'Installer hash matches.'; else echo 'Installer hash does not match, potential security risk!'; exit 1; fi"
_execute "sudo php composer-setup.php --install-dir=/usr/local/bin --filename=composer"
_execute "php -r \"unlink('composer-setup.php');\""
_success "Composer installed."

_success "Nginx, PHP, and MySQL installation and configuration complete!"
_info " "
_info "Next Steps:"
_info "1.  Place your React/Vite.js build output (from 'npm run build' or 'yarn build') in /var/www/html"
_info "2.  Place your PHP (Laravel) backend files in /var/www/backend"
_info "3.  Ensure your Laravel application's storage directory is properly configured and writable."
_info "4.  If your Laravel application requires it, set the correct permissions for the 'bootstrap/cache' directory."
_info "5.  Update your Laravel application's .env file with the correct database credentials and application URL."
_info "6.  Navigate to /var/www/backend and run: php artisan migrate"
_info "7.  Set up your Laravel application's routing in /var/www/backend/routes/api.php or web.php."
_info "8.  Access your React/Vite.js app in your browser at http://$SERVER_NAME"
_info "9.  Your PHP (Laravel) backend API will be accessible at http://$SERVER_NAME/api/"
_info "10. Secure your MySQL server (harden it) by reviewing the output of 'sudo mysql_secure_installation'."
_info "11. Secure your server and configure firewall (e.g., with UFW): sudo ufw enable; sudo ufw allow 'Nginx Full'; sudo ufw allow 'OpenSSH'."
_info "12. Set up a domain name and configure DNS records to point to your server's IP address."
_info "13. Obtain and install an SSL certificate (e.g., with Certbot) for HTTPS: sudo apt install -y certbot python3-certbot-nginx; sudo certbot --nginx -d $SERVER_NAME"