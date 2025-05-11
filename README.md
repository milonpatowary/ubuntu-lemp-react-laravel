# ubuntu-lamp-setup
 
This script automates the installation and configuration of Nginx, PHP-FPM, and MySQL on Ubuntu for running a React/Vite.js and PHP (Laravel) application.

Intended to be run on Ubuntu 22.04  May need adjustments for other versions.

# IMPORTANT:
  - Run this script with sudo privileges:  sudo bash setup_web_server.sh
  - The script assumes a basic level of familiarity with the command line.
  - It's HIGHLY recommended to back up any critical data before running this script.
  - The script will attempt to set a MySQL root password. If you have already set one, you may need to modify the script or handle it manually.
  -  The script uses 'your_domain.com' as a placeholder.  You MUST change this
     to your actual domain name or use 'localhost' for testing.