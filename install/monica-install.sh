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

