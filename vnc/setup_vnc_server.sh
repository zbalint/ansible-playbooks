#!/bin/bash

# setup vnc-server for my netbook

readonly USER="zbalint"
readonly USER_HOME="/home/zbalint"

IFS='' read -r -d '' XSTARTUP_CONTENT <<"EOF"
#!/bin/bash
xrdb $HOME/.Xresources
startxfce4 &
EOF

IFS='' read -r -d '' VNCSERVER_SERVICE_CONTENT <<"EOF"
[Unit]
Description=Start TightVNC server at startup
After=syslog.target network.target

[Service]
Type=forking
User=zbalint
Group=zbalint
WorkingDirectory=/home/zbalint

PIDFile=/home/zbalint/.vnc/%H:%i.pid
ExecStartPre=-/usr/bin/vncserver -kill :%i > /dev/null 2>&1
ExecStart=/usr/bin/vncserver -depth 24 -geometry 1228x720 :%i
ExecStop=/usr/bin/vncserver -kill :%i

[Install]
WantedBy=multi-user.target
EOF

function create_user() {
    groupadd -g 5000 zbalint && \
    useradd -u 5000 -g 5000 zbalint -m && \
    usermod -aG sudo zbalint && \
    usermod --shell /bin/bash zbalint && \
    passwd zbalint
}

function set_timezone() {
    timedatectl set-timezone Europe/Budapest
}

function insall_apks() {
    apt update && \
    apt upgrade -y && \
    apt install -y curl wget htop tmux nano git unattended-upgrades apt-config-auto-update apt-transport-https ca-certificates gnupg ufw xfce4 xfce4-goodies dbus-x11 tightvncserver
}

function install_vscodium_ide() {
    wget -qO - https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg \
    | gpg --dearmor \
    | dd of=/usr/share/keyrings/vscodium-archive-keyring.gpg && \
    echo 'deb [ signed-by=/usr/share/keyrings/vscodium-archive-keyring.gpg ] https://download.vscodium.com/debs vscodium main' \
    | tee /etc/apt/sources.list.d/vscodium.list && \
    apt update && apt install -y codium
}

function install_firefox() {
    install -d -m 0755 /etc/apt/keyrings && \
    wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- | tee /etc/apt/keyrings/packages.mozilla.org.asc > /dev/null && \
    echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" | tee -a /etc/apt/sources.list.d/mozilla.list > /dev/null && \
    echo '
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
' | tee /etc/apt/preferences.d/mozilla  && \
    apt update && apt install -y firefox
}

function install_tailscale() {
    curl -fsSL https://tailscale.com/install.sh | sh
    tailscale up
}

function setup_ufw() {
    ufw enable
    ufw reload
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow in on tailscale0
    ufw reload
}

function set_vnc_password() {
    mkdir /home/zbalint/.vnc
    # echo "${VNC_PASSWORD}" | vncpasswd -f > /home/zbalint/.vnc/passwd && \
    vncpasswd
    chown -R zbalint:zbalint /home/zbalint/.vnc
    mv .vnc/passwd /home/zbalint/.vnc 
    chown -R zbalint:zbalint /home/zbalint/.vnc/
    chmod 0600 /home/zbalint/.vnc/passwd
}

function kill_vnc_server() {
    vncserver -kill :1 || true
}

function write_xstartup_file() {
    echo "${XSTARTUP_CONTENT}" > /home/zbalint/.vnc/xstartup && \
    chown -R zbalint:zbalint /home/zbalint/.vnc && \
    chmod +x /home/zbalint/.vnc/xstartup
}

function write_vncserver_service_file() {
    echo "${VNCSERVER_SERVICE_CONTENT}" >> /etc/systemd/system/vncserver@.service && \
    systemctl daemon-reload && \
    systemctl enable vncserver@1.service && \
    systemctl start vncserver@1.service
}

function main() {
    create_user && \
    set_timezone && \
    insall_apks && \
    install_vscodium_ide && \
    install_firefox && \
    install_tailscale && \
    setup_ufw && \
    set_vnc_password && \
    write_xstartup_file && \
    write_vncserver_service_file
}

main