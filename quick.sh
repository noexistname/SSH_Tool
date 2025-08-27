#!/bin/bash

# 定义颜色
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}### 开始执行一键配置脚本 ###${NC}"

# 步骤1: 更新和升级系统
echo -e "${GREEN}--- 1. 更新和升级系统 ---${NC}"
apt update -y
apt upgrade -y
echo -e "${GREEN}系统更新和升级完成。${NC}"

# 步骤2: 安装常用工具
echo -e "${GREEN}--- 2. 安装常用工具 ---${NC}"
apt install wget curl sudo vim git unzip -y
echo -e "${GREEN}常用工具安装完成。${NC}"

# 步骤3: 配置 Bash Shell 别名和提示符
echo -e "${GREEN}--- 3. 配置 Bash Shell ---${NC}"
# 配置自定义提示符 (PS1)
cat <<EOF >> /etc/bash.bashrc
PS1='\[\e[32;40m\e[1m\]\u@\[\e[35;40m\e[1m\]\h\[\e[0m\] \[\e[34;40m\e[1m\]\W\[\e[0m\]]\$ '
EOF

# 配置颜色别名
echo "alias ls='ls --color=auto'" >> /etc/bash.bashrc
echo "alias ll='ls --color=auto -l'" >> /etc/bash.bashrc
echo "alias egrep='egrep --color=auto'" >> /etc/bash.bashrc
echo "alias fgrep='fgrep --color=auto'" >> /etc/bash.bashrc
echo "alias grep='grep --color=auto'" >> /etc/bash.bashrc
source /etc/bash.bashrc

# 步骤4: 开启 TCP BBR 拥塞控制算法
echo -e "${GREEN}--- 4. 开启 TCP BBR 拥塞控制算法 ---${NC}"
# 清空 /etc/sysctl.conf 文件中的相关配置，防止重复写入
sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf

# 写入新配置
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf

# 应用配置
sysctl -p

# 检查 BBR 是否已启用
echo -e "${GREEN}BBR 拥塞控制算法启用状态检查：${NC}"
sysctl net.ipv4.tcp_available_congestion_control
sysctl net.ipv4.tcp_congestion_control
lsmod | grep bbr
echo -e "${GREEN}配置完成。${NC}"

# 步骤5: 配置 UFW 防火墙
echo -e "${GREEN}--- 5. 配置 UFW 防火墙 ---${NC}"
apt install ufw -y

# 启用 UFW
ufw enable -y

# 检查 UFW 状态
ufw status verbose

echo -e "${GREEN}UFW 防火墙安装并启用完成。${NC}"

echo -e "${GREEN}### 脚本执行完毕 ###${NC}"
