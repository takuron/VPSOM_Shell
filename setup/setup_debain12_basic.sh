#!/bin/bash

# ==============================================================================
# Debian 12 自动化部署脚本 (简化版)
#
# 功能:
# 1. 配置 TCP BBR 拥塞控制算法
# 2. 更改 SSH 端口为随机高位端口
# 3. 更新系统软件包
# 4. 安装和配置 UFW 防火墙 (允许 80, 443, 新SSH端口)
# 5. 提示用户进行后续操作
#
# 使用方法:
# 1. 将此脚本保存为 .sh 文件 (例如: setup_debian12_simplified.sh)
# 2. 添加执行权限: chmod +x setup_debian12_simplified.sh
# 3. 以 root 用户身份运行: sudo ./setup_debian12_simplified.sh
# ==============================================================================

# --- 基本设置 ---
# 如果任何命令失败，则立即退出
set -e
# 将未设置的变量视为错误
set -u
# 管道中的命令失败也视为失败
set -o pipefail

# --- 检查是否为 Root 用户 ---
if [[ $EUID -ne 0 ]]; then
   echo "错误：此脚本必须以 root 权限运行。"
   exit 1
fi

echo "===================================================="
echo " Debian 12 自动化部署脚本 (简化版) 开始执行 "
echo "===================================================="
sleep 2

# --- 1. 配置 TCP BBR ---
echo "--- [1/4] 正在配置 TCP BBR ---"
# 检查并添加 BBR 配置到 sysctl.conf
if ! grep -q "^net.core.default_qdisc=fq" /etc/sysctl.conf; then
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
fi
if ! grep -q "^net.ipv4.tcp_congestion_control=bbr" /etc/sysctl.conf; then
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
fi

# 应用 sysctl 配置
sysctl -p > /dev/null # 将输出重定向，避免过多信息

echo "BBR 配置已写入 /etc/sysctl.conf 并已尝试应用。"
echo "验证 (BBR 可能需要重启或网络活动后才能完全加载):"
echo -n "当前拥塞控制: "
sysctl net.ipv4.tcp_congestion_control
echo -n "BBR 模块加载状态: "
if lsmod | grep -q bbr; then
    echo "已加载"
else
    echo "未加载 (可能需要重启或网络流量)"
fi
echo "完成 BBR 配置。"
sleep 1

# --- 2. 更改 SSH 端口 ---
echo "--- [2/4] 正在更改 SSH 端口 ---"
# 生成一个 10000 到 65535 之间的随机端口
NEW_SSH_PORT=$(shuf -i 10000-65535 -n 1)
SSH_CONFIG_FILE="/etc/ssh/sshd_config"
echo "将生成新的 SSH 端口: $NEW_SSH_PORT"

# 备份原始 sshd_config 文件
cp "$SSH_CONFIG_FILE" "${SSH_CONFIG_FILE}.bak_$(date +%F_%T)"
echo "已备份 SSH 配置文件到 ${SSH_CONFIG_FILE}.bak_..."

# 查找并替换或添加端口设置
if grep -qE "^#?\s*Port\s+" "$SSH_CONFIG_FILE"; then
    # 如果存在 Port 行 (可能被注释)，则替换它
    sed -i -E "s/^#?\s*Port\s+.*/Port $NEW_SSH_PORT/" "$SSH_CONFIG_FILE"
    echo "已在 $SSH_CONFIG_FILE 中更新 Port 设置。"
else
    # 如果不存在 Port 行，则在文件末尾添加
    echo "Port $NEW_SSH_PORT" >> "$SSH_CONFIG_FILE"
    echo "已在 $SSH_CONFIG_FILE 末尾添加 Port 设置。"
fi

# 提醒用户记住新端口
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "!! 重要: 新的 SSH 端口已设置为: $NEW_SSH_PORT            !!"
echo "!! 请务必记下这个端口，否则重启 SSH 服务后将无法登录！ !!"
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
sleep 5 # 给用户时间阅读

echo "完成 SSH 端口更改 (服务将在后续步骤提示重启)。"
sleep 1

# --- 3. 更新系统软件 ---
echo "--- [3/4] 正在更新系统软件包 ---"
apt update
echo "正在升级软件包..."
apt upgrade -y
echo "正在清理不再需要的软件包..."
apt autoremove -y
echo "系统软件包更新完成。"
sleep 1

# --- 4. 安装和配置 UFW 防火墙 ---
echo "--- [4/4] 正在安装和配置 UFW 防火墙 ---"
apt install ufw -y

# 设置默认策略
ufw default deny incoming
ufw default allow outgoing

# 允许必要的端口 (新的 SSH 端口)
# 使用变量 $NEW_SSH_PORT
ufw allow "$NEW_SSH_PORT" comment 'Allow New SSH Port'

echo "UFW 已安装并配置规则，允许端口 $NEW_SSH_PORT。"
echo "UFW 当前状态:"
ufw status verbose # 显示规则，但防火墙尚未启用

echo "重要提示：UFW 防火墙尚未启用。请在确认可以通过新端口 $NEW_SSH_PORT 登录后，手动运行 'ufw enable' 来启用。"
sleep 1

# --- 5. 提示用户进行后续操作 ---
echo ""
echo "===================================================================="
echo "  自动化部署脚本核心任务已完成！请务必执行以下手动步骤："
echo "===================================================================="
echo ""
echo " [ 重要 ] 1. 修改 ROOT 密码:"
echo "    为了安全，请立即运行 \`passwd\` 命令设置一个新的、强健的 root 密码。"
echo ""
echo " [ 重要 ] 2. 重启 SSH 服务或服务器以应用新端口:"
echo "    记住，新的 SSH 端口是: $NEW_SSH_PORT"
echo "    * 选项 A (仅重启 SSH 服务): \`systemctl restart sshd\`"
echo "    * 选项 B (重启整个服务器): \`reboot\`"
echo ""
echo "    !! 警告 !! 在您断开当前的 SSH 会话之前，请务必:"
echo "       a. 打开一个新的终端窗口。"
echo "       b. 使用新端口尝试重新连接到服务器:"
echo "          \`ssh root@<你的服务器IP> -p $NEW_SSH_PORT\`"
echo "       c. 确认您可以成功登录后，再断开当前会话或重启服务器。"
echo "       d. 如果无法连接，请检查 /etc/ssh/sshd_config 文件和 UFW 规则 (虽然 UFW 尚未启用)。"
echo ""
echo " [ 重要 ] 3. 启用 UFW 防火墙:"
echo "    在您确认可以通过新的 SSH 端口 ($NEW_SSH_PORT) 成功登录之后，"
echo "    请运行以下命令来启用防火墙："
echo "    \`ufw enable\`"
echo "    (启用时会提示确认，输入 'y' 并回车)"
echo ""
echo " [ 提示 ] 4. BBR 生效确认:"
echo "    TCP BBR 配置通常在服务器重启后或有显著网络流量时才会完全生效。"
echo "    您可以在重启后再次运行 \`sysctl net.ipv4.tcp_congestion_control\` 和 \`lsmod | grep bbr\` 来检查。"
echo ""
echo "===================================================================="
echo "  请再次确认并记下新的 SSH 端口: $NEW_SSH_PORT"
echo "  部署完成，祝您使用愉快！"
echo "===================================================================="

exit 0
