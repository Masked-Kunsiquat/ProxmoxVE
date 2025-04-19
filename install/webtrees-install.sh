#!/usr/bin/env bash

# Copyright (c)
# Author: Maked-Kunsiquat
# License: MIT
# https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/fisharebest/webtrees

source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y \
    mc \
    sudo \
    curl \
    unzip \
    nginx \
    mariadb-server \
    lsb-release \
    ca-certificates \
    apt-transport-https \
    software-properties-common
msg_ok "Installed Dependencies"

msg_info "Adding PHP 8.3 repository and dependencies"
$STD curl -sSLo /usr/share/keyrings/deb.sury.org-php.gpg https://packages.sury.org/php/apt.gpg
$STD sh -c "echo 'deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php $(lsb_release -sc) main' > /etc/apt/sources.list.d/php.list"
$STD apt update
$STD apt-get install -y php8.3-{fpm,mysql,gd,intl,xml,zip,curl,mbstring}
msg_ok "Added PHP-8.3 repository and its dependencies"

msg_info "Setting PHP 8.3 as default"
$STD update-alternatives --install /usr/sbin/php php /usr/bin/php8.3 83
$STD update-alternatives --set php /usr/bin/php8.3

$STD update-alternatives --install /usr/sbin/php-fpm php-fpm /usr/sbin/php-fpm8.3 83
$STD update-alternatives --set php-fpm /usr/sbin/php-fpm8.3
msg_ok "Set PHP 8.3 as default"

msg_info "Configuring MariaDB"
DB_NAME="webtrees"
DB_USER="webtrees"
DB_PASS=$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | head -c13)

mysql -u root -e "CREATE DATABASE $DB_NAME;"
mysql -u root -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
mysql -u root -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
mysql -u root -e "FLUSH PRIVILEGES;"
{
    echo "Webtrees Database Credentials:"
    echo "Database: $DB_NAME"
    echo "User: $DB_USER"
    echo "Password: $DB_PASS"
} >> ~/webtrees.creds
msg_ok "Configured MariaDB"

msg_info "Installing Webtrees"
RELEASE=$(curl -fsSL https://api.github.com/repos/fisharebest/webtrees/releases/latest | grep -oP '"tag_name": "\K(.*?)(?=")')
wget -q "https://github.com/fisharebest/webtrees/releases/download/${RELEASE}/webtrees-${RELEASE}.zip" -O /tmp/webtrees.zip
unzip -q /tmp/webtrees.zip -d /var/opt/
chown -R www-data:www-data /opt/webtrees
chown -R 755 /opt/webtrees
msg_ok "Installed Webtrees"

msg_info "Configuring Web Server"
cat <<EOF >/etc/nginx/sites-available/webtrees
server {
    listen 80;
    server_name localhost;
    root /opt/webtrees;
    index index.php;

    location / {
        try_files \$uri \$uri/ /index.php;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

ln -s /etc/nginx/sites-available/webtrees /etc/nginx/sites-enabled/webtrees
rm /etc/nginx/sites-enabled/default
systemctl reload nginx
msg_ok "Configured Web Server"

msg_info "Finalizing Installation"
echo "${RELEASE}" > "/opt/webtrees_version.txt"
msg_ok "Webtrees is ready!"
