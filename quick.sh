#!/bin/bash

# ====================================================
# 脚本名称: 系统管理交互式脚本 (全能版)
# 功能: 包含系统更新、常用工具、安全配置、Docker/3x-ui 及 硬盘挂载
# ====================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' 

# 检查权限
[[ $EUID -ne 0 ]] && echo -e "${RED}错误: 必须使用 root 权限运行此脚本！${NC}" && exit 1

# 自动判断系统类型
if [ -f /etc/debian_version ]; then
    PKG_MANAGER="apt"
    UPDATE_CMD="apt update -y && apt upgrade -y"
elif [ -f /etc/redhat-release ]; then
    PKG_MANAGER="yum"
    UPDATE_CMD="yum update -y"
else
    echo -e "${RED}无法识别的系统类型，脚本退出。${NC}"
    exit 1
fi

# --- 功能函数 ---

update_system() {
    echo -e "${YELLOW}正在更新系统并安装常用工具...${NC}"
    eval $UPDATE_CMD
    $PKG_MANAGER install -y wget curl sudo vim git unzip ufw
    echo -e "${GREEN}系统更新及工具安装完成！${NC}"
}

change_ssh_port() {
    read -p "请输入新的 SSH 端口号: " SSH_PORT
    if [[ "$SSH_PORT" =~ ^[0-9]+$ ]] && [ "$SSH_PORT" -ge 1 ] && [ "$SSH_PORT" -le 65535 ]; then
        sed -i "s/^#\?Port .*/Port $SSH_PORT/" /etc/ssh/sshd_config
        if command -v ufw >/dev/null 2>&1; then
            ufw allow "$SSH_PORT"/tcp
        fi
        systemctl restart sshd || systemctl restart ssh
        echo -e "${GREEN}SSH 端口已修改为 $SSH_PORT 并重启服务。${NC}"
    else
        echo -e "${RED}无效的端口号！${NC}"
    fi
}

setup_ufw_cloudflare() {
    echo -e "${YELLOW}正在配置 UFW 并添加 Cloudflare IP 白名单...${NC}"
    $PKG_MANAGER install -y ufw
    for ip in $(curl -s https://www.cloudflare.com/ips-v4); do
        ufw allow from "$ip" to any port 443 proto tcp
    done
    for ip in $(curl -s https://www.cloudflare.com/ips-v6); do
        ufw allow from "$ip" to any port 443 proto tcp
    done
    ufw default deny incoming
    ufw default allow outgoing
    echo "y" | ufw enable
    echo -e "${GREEN}UFW 配置完成，443 端口已对 Cloudflare 开放。${NC}"
}

install_docker() {
    echo -e "${YELLOW}正在安装 Docker & Docker Compose...${NC}"
    curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh
    systemctl enable --now docker
    curl -L "https://github.com/docker/compose/releases/download/v2.34.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    echo -e "${GREEN}Docker 套件安装完成！${NC}"
}

install_rclone() {
    echo -e "${YELLOW}正在安装 Rclone...${NC}"
    curl https://rclone.org/install.sh | sudo bash
    echo -e "${GREEN}Rclone 安装完成！${NC}"
}

install_3x_ui() {
    echo -e "${YELLOW}正在安装 3x-ui...${NC}"
    bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
}

disable_ipv6() {
    echo -e "${YELLOW}正在禁用 IPv6...${NC}"
    echo -e "net.ipv6.conf.all.disable_ipv6 = 1\nnet.ipv6.conf.default.disable_ipv6 = 1\nnet.ipv6.conf.lo.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf
    sudo sysctl -p
    echo -e "${GREEN}IPv6 已禁用。${NC}"
}

customize_colors() {
    echo -e "${YELLOW}正在优化终端颜色及 Alias...${NC}"
    echo "PS1='[\e[32;40m\e[1m\u\e[32;40m\e[1m@\e[35;40m\e[1m\h\e[0m \e[34;40m\e[1m\W\e[0m]\$ '" >> /etc/bash.bashrc
    echo "alias ls='ls --color=auto'" >> /etc/bash.bashrc
    echo "alias ll='ls --color=auto -l'" >> /etc/bash.bashrc
    echo "alias egrep='egrep --color=auto'" >> /etc/bash.bashrc
    echo "alias fgrep='fgrep --color=auto'" >> /etc/bash.bashrc
    echo "alias grep='grep --color=auto'" >> /etc/bash.bashrc
    # 提醒用户需要重新加载
    echo -e "${GREEN}颜色配置已写入 /etc/bash.bashrc。${NC}"
    echo -e "${YELLOW}提示: 请手动执行 'source /etc/bash.bashrc' 或重新登录查看效果。${NC}"
}

install_nexttrace() {
    echo -e "${YELLOW}正在安装 NextTrace...${NC}"
    curl nxtrace.org/nt | bash
    echo -e "${GREEN}NextTrace 安装完成！${NC}"
}

enable_bbr() {
    echo -e "${YELLOW}正在开启 BBR+FQ 加速...${NC}"
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    sysctl -p
    echo -e "${GREEN}BBR 加速配置完成。当前拥塞控制算法为:${NC}"
    sysctl net.ipv4.tcp_congestion_control
}

mount_disk() {
    echo -e "${YELLOW}当前系统中所有的硬盘和分区：${NC}"
    lsblk
    echo "----------------------------------------"
    read -p "请输入硬盘设备（例如 /dev/sdb）： " DEVICE
    read -p "请输入挂载点（例如 /mnt/mydisk）： " MOUNT_POINT

    # 检查硬盘是否存在
    if [ ! -b "$DEVICE" ]; then
        echo -e "${RED}错误：硬盘 $DEVICE 不存在！${NC}"
        return
    fi

    # 创建挂载点
    echo -e "${YELLOW}正在创建挂载点 $MOUNT_POINT ...${NC}"
    mkdir -p $MOUNT_POINT

    # 挂载硬盘
    echo -e "${YELLOW}正在挂载硬盘 $DEVICE 到 $MOUNT_POINT ...${NC}"
    mount $DEVICE $MOUNT_POINT

    # 验证挂载是否成功
    if mount | grep -q "$MOUNT_POINT"; then
        echo -e "${GREEN}硬盘成功挂载到 $MOUNT_POINT !${NC}"
        
        # 获取 UUID 和 文件系统类型
        UUID=$(blkid -o value -s UUID $DEVICE)
        FSTYPE=$(blkid -o value -s TYPE $DEVICE)
        FSTYPE=${FSTYPE:-ext4} # 如果没查到类型，默认用 ext4

        read -p "是否将硬盘设置为开机自动挂载？(y/N): " AUTO_MOUNT
        if [[ "$AUTO_MOUNT" == "y" || "$AUTO_MOUNT" == "Y" ]]; then
            # 检查 fstab 是否已经存在该 UUID，避免重复写入
            if grep -q "$UUID" /etc/fstab; then
                echo -e "${YELLOW}提示: /etc/fstab 中已存在该硬盘配置。${NC}"
            else
                echo "UUID=$UUID $MOUNT_POINT $FSTYPE defaults 0 2" | tee -a /etc/fstab
                echo -e "${GREEN}开机自动挂载配置已添加到 /etc/fstab。${NC}"
            fi
        fi
    else
        echo -e "${RED}挂载失败，请检查硬盘分区是否已格式化。${NC}"
    fi
}

# --- 主菜单 ---

while true; do
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${GREEN}      系统管理交互脚本 (全能版)${NC}"
    echo -e "${YELLOW}========================================${NC}"
    echo "1) 更新系统并安装常用插件"
    echo "2) 修改自定义 SSH 端口"
    echo "3) 安装 UFW 并配置 CF 443 准入"
    echo "4) 安装 Docker 和 Docker Compose"
    echo "5) 安装 Rclone"
    echo "6) 安装 3x-ui 面板"
    echo "7) 关闭 IPv6"
    echo "8) 终端颜色美化 (PS1 & Alias)"
    echo "9) 安装 NextTrace (路由追踪)"
    echo "10) 开启 BBR+FQ 加速"
    echo "11) 挂载硬盘 (含自动挂载配置)"
    echo "0) 退出脚本"
    echo -e "${YELLOW}----------------------------------------${NC}"
    read -p "请选择操作 [0-11]: " choice

    case $choice in
        1) update_system ;;
        2) change_ssh_port ;;
        3) setup_ufw_cloudflare ;;
        4) install_docker ;;
        5) install_rclone ;;
        6) install_3x_ui ;;
        7) disable_ipv6 ;;
        8) customize_colors ;;
        9) install_nexttrace ;;
        10) enable_bbr ;;
        11) mount_disk ;;
        0) echo "退出脚本..."; exit 0 ;;
        *) echo -e "${RED}无效选项，请重新选择。${NC}" ;;
    esac
    echo ""
    read -n 1 -s -r -p "按任意键返回主菜单..."
    clear
done
