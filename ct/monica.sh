#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/Masked-Kunsiquat/ProxmoxVE/main/misc/build.func)

APP="Monica"
TAGS="crm;php"
var_cpu="2"
var_ram="2048"
var_disk="10"
var_os="debian"
var_version="12"
var_unprivileged="1"

header_info "$APP"
base_settings

function update_script() {
    header_info
    check_container_storage
    check_container_resources

    if [[! -d /var/www/monica]]; then
        msg_error "No Monica Installation Found!"
        exit 1
    fi

    RELEASE=$(curl -fsSL https://api.github.com/repos/monicahq/monica/releases/latest | grep "tag_name" | awk '{print substr($2, 3, length($2)-4)}')
    CURRENT=$(cat /opt/${APP}_version.txt)

    if [["${RELEASE}" != "${CURRENT}"]]; then
        msg_info "Updating Monica to v${RELEASE}"
        systemctl stop apache2
        tar -czf "/opt/${APP}_backup_$(date +%F).tar.gz" /var/www/monica

        cd /var/www/monica
        git fetch --tags
        git checkout "tags/v${RELEASE}"

        composer install --no-interaction --no-dev
        yarn install
        yarn run production
        php artisan migrate --force
        systemctl start apache2

        echo "${RELEASE}" > /opt/${APP}_version.txt
        msg_ok "Monica Updated to v${RELEASE}"
    else
        msg_ok "Monica is up-to-date (v${CURRENT})."
    fi
}

start
build_container
description

msg_ok "Setup Completed!\nAccess Monica at http://${IP}/"