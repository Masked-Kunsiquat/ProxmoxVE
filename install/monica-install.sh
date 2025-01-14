#!/usr/bin/env bash

# Copyright (c)
# Author: Masked-Kunsiquat
# License: MIT
# https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/monicahq/monica

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y \
    sudo \
    curl \
    mc \
    apache2 \
    software-properties-common \
    git \
    mariadb-server \
    php8.1-{bcmath,curl,gd,gmp,intl,mbstring,mysql,redit,tokenizer,xml,zip} \
    composer \
    nodejs \
    npm \
    unzip
msg_ok "Installed Dependencies"

DB_NAME="monica"
DB_USER="monica"
DB_PASS=$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | head -c13)
ADMIN_EMAIL="admin@example.com"
ADMIN_PASS=$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | head -c13)

msg_info "Setting up Database"
mysql -u root -e "CREATE DATABASE $DB_NAME CHARACTER SET utf8mb4_unicode_ci;"
mysql -u root -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
mysql -u root -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
mysql -u root -e "FLUSH PRIVILEGES;"
{
    echo "Monica CRM Credentials:"
    echo "Database Name: $DB_NAME"
    echo "Database User: $DB_USER"
    echo "Database Password: $DB_PASS"
    echo "App Username: $ADMIN_EMAIL"
    echo "App Password: $ADMIN_PASS"
} >> ~/monica.creds
msg_ok "Database Configured"

msg_info "Setting up Monica"
cd /var/www/ || exit
git clone https://github.com/monicahq/monica.git
cd monica || exit
git fetch --tags
git checkout tags/v3.0.0

cp .env.example .env
sed -i -e "s/DB_USERNAME=.*/DB_USERNAME=$DB_USER/"\
    -e "s/DB_PASSWORD=.*/DB_PASSWORD=$DB_PASS/" .env

composer install --no-interaction --no-dev
yarn install
yarn run production
php artisan key:generate &>/dev/null
php artisan setup:production --email="$ADMIN_EMAIL" --password="$ADMIN_PASS" &>/dev/null
msg_ok "Monica Setup Completed"

msg_info "Configuring Apache"
chown -R www-data:www-data /var/www/monica
chmod -R 775 /var/www/monica/storage
a2enmod rewrite

cat <<EOF >/etc/apache2/sites-available/monica.conf
<VirtualHost *:80>
    ServerName localhost

    DocumentRoot /var/www/monica/public
    <Directory /var/www/monica/public>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

a2ensite monica.conf
systemctl reload apache2
msg_ok "Apache Configured"

msg_info "Setting up Crontab"
(crontab -u www-data -l 2>/dev/null; echo "***** php /var/www/monica/artisan schedule:run >> /dev/null 2>&1") | crontab -u www-data -
msg_ok "Crontab configured"

msg_info "Cleaning Up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleanup Completed"