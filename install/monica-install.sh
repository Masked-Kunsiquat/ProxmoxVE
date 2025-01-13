#!/usr/bin/env bash

# Import functions and setup environment
source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"

color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

APP="Monica"
DB_NAME="monica"
DB_USER="monica"
DB_PASS=$(openssl rand -base64 18 | tr -dc 'a-zA-Z0-9' | head -c13)

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

msg_info "Setting up Database"
$STD mysql -u root -e "CREATE DATABASE $DB_NAME CHARACTER SET utf8mb4_unicode_ci;"
$STD mysql -u root -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
$STD mysql -u root -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
$STD mysql -u root -e "FLUSH PRIVILEGES;"
{
    echo "Monica CRM Credentials"
    echo "Database Name: $DB_NAME"
    echo "Database User: $DB_USER"
    echo "Database Password: $DB_PASS"
} >> ~/monica.creds
msg_ok "Database Configured"


msg_info "Setting up Monica"
cd /var/www/
sudo git clone https://github.com/monicahq/monica.git
cd monica
sudo git fetch --tags
sudo git checkout tags/v3.0.0

sudo cp .env.example .env
sed -i -e "s/DB_USERNAME=.*/DB_USERNAME=$DB_USER/"\
    -e "s/DB_PASSWORD=.*/DB_PASSWORD=$DB_PASS/" .env

composer install --no-interaction --no-dev
yarn install
yarn run production
php artisan key:generate
php artisan setup:production --email=admin@example.com --password=securepassword
msg_ok "Monica Setup Completed"

msg_info "Configuring Apache"
sudo chown -R www-data:www-data /var/www/monica
sudo chmod -R 775 /var/www/monica/storage
sudo a2enmod rewrite

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

sudo a2ensite monica.conf
sudo systemctl reload apache2
msg_ok "Apache Configured"

msg_info "Setting up Crontab"
sudo crontab -u www-data -e <<EOF
***** php /var/www/monica/artisan schedule:run >> /dev/null 2>&1
EOF
msg_ok "Crontab configured"

msg_info "Cleaning Up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleanup Completed"