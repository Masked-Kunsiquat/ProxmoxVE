#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/Masked-Kunsiquat/ProxmoxVE/main/misc/build.func)
# Copyright (c)
# Author: Masked-Kunsiquat
# License: MIT
# https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/monicahq/monica

# App Default Values
APP="Monica"
var_tags="crm;php"
var_cpu="2"
var_ram="2048"
var_disk="10"
var_os="debian"
var_version="12"
var_unprivileged="1"

header_info "$APP"
base_settings

variables
color
catch_errors

function update_script() {
    header_info
    check_container_storage
    check_container_resources

    if [[ ! -d /var/www/monica ]]; then
        msg_error "No Monica Installation Found!"
        exit 1
    fi

    RELEASE=$(curl -fsSL https://api.github.com/repos/monicahq/monica/releases/latest | grep "tag_name" | awk '{print substr($2, 3, length($2)-4)}')
    CURRENT=$(cat /opt/${APP}_version.txt)

    if [[ "${RELEASE}" != "${CURRENT}" ]]; then
        msg_info "Updating Monica to v${RELEASE}"
        systemctl stop apache2
        tar -czf "/opt/${APP}_backup_$(date +%F).tar.gz" /var/www/monica

        cd /var/www/monica || exit
        git fetch --tags
        git checkout "tags/v${RELEASE}"

        composer install --no-interaction --no-dev
        yarn install
        yarn run production
        php artisan migrate --force &>/dev/null
        systemctl start apache2

        echo "${RELEASE}" > /opt/${APP}_version.txt
        msg_ok "Monica Updated to v${RELEASE}"
    else
        msg_ok "Monica is up-to-date (v${CURRENT})."
    fi
    exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:80${CL}"