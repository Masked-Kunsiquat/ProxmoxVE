#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)

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

function update_script() {
    header_info
    check_container_storage
    check_container_resources

    if [[ ! -d /var/www/webtrees ]]; then
        msg_error "No Webtrees Installation Found!"
        exit
    fi

    RELEASE=$(curl -fsSL https://api.github.com/repos/fisharebest/webtrees/releases/latest | grep "tag_name" | awk '{print substr($2, 3, length($2)-4) }')
    if [[ "${RELEASE}" != "$(cat /opt/webtrees_version.txt)" ]]; then
        msg_info "Updating Webtrees to v${RELEASE}"
        systemctl stop nginx
        tar -czf "/var/www/webtrees_backup_$(date +%F).tar.gz" /var/www/webtrees
        cd /tmp && wget -q "https://github.com/fisharebest/webtrees/releases/download/${RELEASE}/webtrees-${RELEASE}.zip"
        unzip -o -q webtrees-${RELEASE}.zip -d /var/www/webtrees
        chown -R www-data:www-data /var/www/webtrees
        echo "${RELEASE}" > /opt/webtrees_version.txt
        systemctl start nginx
        msg_ok "Updated Webtrees to v${RELEASE}"
    else
        msg_ok "Webtrees is up-to-date."
    fi
    exit
}

start
build_container
description

msg_ok "Webtrees setup completed successfully!"
echo -e "${INFO}${YW} Access Webtrees at http://${IP}:${PORT}${CL}"
