#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/Masked-Kunsiquat/ProxmoxVE/main/misc/build.func)
# Copyright (c)
# Author: Maked-Kunsiquat
# License: MIT
# https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/fisharebest/webtrees

# App Default Values
APP="Webtrees"
var_tags="genealogy;web"
var_cpu="2"
var_ram="512"
var_disk="2"
var_os="debian"
var_version="12"
var_unprivileged="1"

header_info "$APP"
base_settings

# Core
variables
color
catch_errors

get_latest_release() {
    curl -fsSL https://api.github.com/repos/fisharebest/webtrees/releases/latest |
        grep -oP '"tag_name": "\K(.*?)(?=")'
}


function update_script() {
    header_info
    check_container_storage
    check_container_resources

    if [[ ! -d /opt/webtrees ]]; then
        msg_error "No ${APP} Installation Found!"
        exit 1
    fi

    RELEASE=$(get_latest_release)
    if [[ ! -f /opt/webtrees_version.txt ]] || [[ "${RELEASE}" != "$(cat /opt/webtrees_version.txt)" ]]; then
        msg_info "Updating ${APP} to v${RELEASE}"
        $STD systemctl stop nginx
        $STD tar -czf "/opt/webtrees_backup_$(date +%F).tar.gz" /opt/webtrees
        cd /tmp && wget -q "https://github.com/fisharebest/webtrees/releases/download/${RELEASE}/webtrees-${RELEASE}.zip"
        unzip -o -q webtrees-${RELEASE}.zip -d /opt/webtrees
        rm -f "webtrees-${RELEASE}.zip"
        $STD chown -R www-data:www-data /opt/webtrees
        echo "${RELEASE}" > /opt/webtrees_version.txt
        $STD systemctl start nginx
        msg_ok "Updated ${APP} to v${RELEASE}"
    else
        msg_ok "${APP} is up-to-date."
    fi
    exit 0
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:80${CL}"