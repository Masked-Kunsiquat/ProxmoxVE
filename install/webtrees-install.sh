#!/usr/bin/env bash

# Copyright (c)
# Author: YourName
# License: MIT
# Source: GitHub link

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
    php-{fpm,mysql,gd,intl,xml,zip} \
    mariadb-server
msg_ok "Installed Dependencies"

msg_info "Configuring MariaDB"
DB_NAME="webtrees"
DB_USER="webtrees"
DB_PASS=$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | head -c13)
mysql -uroot <<EOF
CREATE DATABASE $DB_NAME;
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF
msg_ok "Configured MariaDB"

msg_info "Installing Webtrees"
RELEASE=$(curl -fsSL https://api.github.com/repos/fisharebest/webtrees/releases/latest | grep -oP '"tag_name": "\K(.*?)(?=")')
wget -q "https://github.com/fisharebest/webtrees/releases/download/${RELEASE}/webtrees-${RELEASE}.zip" -O /tmp/webtrees.zip
unzip -q /tmp/webtrees.zip -d /var/www/
chown -R www-data:www-data /var/www/webtrees
msg_ok "Installed Webtrees"

msg_info "Configuring Web Server"
cat <<EOF >/etc/nginx/sites-available/webtrees
server {
    listen 80;
    server_name localhost;
    root /var/www/webtrees;
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
echo "${RELEASE}" > /opt/webtrees_version.txt
{
    echo "Webtrees Credentials:"
    echo "Database: $DB_NAME"
    echo "User: $DB_USER"
    echo "Password: $DB_PASS"
} >~/webtrees.creds
msg_ok "Webtrees is ready!"
