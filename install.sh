#!/bin/bash

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}====================================================${NC}"
echo -e "${GREEN}  🚀 OpenClaw + MemOS安卓云端节点一键安装向导 ${NC}"
echo -e "${CYAN}====================================================${NC}"
sleep 2

# ---------------- 阶段 1：Termux基础环境 ----------------
echo -e "\n${YELLOW}[1/4] 正在优化基础环境 (切换清华源，安装基础工具)...${NC}"
DOMAIN="mirrors.tuna.tsinghua.edu.cn"
echo "deb https://${DOMAIN}/termux/apt/termux-main stable main" > $PREFIX/etc/apt/sources.list
pkg update -y -o Dpkg::Options::="--force-confnew"
pkg install -y openssh lsof proot-distro jq npm

echo -e "\n${YELLOW}[2/4] 正在安装Node.js进程管家 (PM2)...${NC}"
npm install -g pm2

# ---------------- 阶段 2：安装核心Ubuntu ----------------
echo -e "\n${YELLOW}[3/4] 正在拉取Ubuntu核心容器 (时间较长，请耐心等待)...${NC}"
curl -fsSL https://raw.githubusercontent.com/mithun50/openclaw-termux/main/install.sh | bash

# ---------------- 阶段 3：交互式获取凭证 ----------------
echo -e "\n${CYAN}====================================================${NC}"
echo -e "${GREEN} 🔑 请输入你的MemOS API Key (在控制台获取):${NC}"
echo -e "${CYAN}====================================================${NC}"
read -p "API Key: " USER_API_KEY

if [ -z "$USER_API_KEY" ]; then
    echo -e "${RED}错误：API Key不能为空！脚本终止。${NC}"
    exit 1
fi

# ---------------- 阶段 4：跨容器自动化手术 ----------------
echo -e "\n${YELLOW}[4/4] 正在进行系统纯净手术：注入配置、修复冲突、安装中文字体...${NC}"

UBUNTU_ROOTFS="$PREFIX/var/lib/proot-distro/installed-rootfs/ubuntu"
cat << 'EOF' > "$UBUNTU_ROOTFS/root/setup_inside.sh"
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive

# 1. 写入API Key
mkdir -p /root/.openclaw
echo "MEMOS_API_KEY=$1" > /root/.openclaw/.env

# 2. 安装直连插件
npm install -g @memtensor/memos-cloud-openclaw-plugin@latest

# 3. 修复JSON
JSON_FILE="/root/.openclaw/openclaw.json"
if [ -f "$JSON_FILE" ]; then
    apt update && apt install -y jq
    jq 'del(.tools["@memtensor/memos-cloud-openclaw-plugin"].apiKey) | .tools.profile = "default"' "$JSON_FILE" > "$JSON_FILE.tmp" && mv "$JSON_FILE.tmp" "$JSON_FILE"
fi

# 4. 仅安装中文字体防乱码 (舍弃沉重的Chromium)
apt update
apt install -y fonts-wqy-zenhei fonts-wqy-microhei fonts-noto-cjk
EOF

chmod +x "$UBUNTU_ROOTFS/root/setup_inside.sh"
proot-distro login ubuntu -- bash /root/setup_inside.sh "$USER_API_KEY"

# ---------------- 注入终极指令 ----------------
sed -i '/alias reboot-memos/d' ~/.bashrc
echo '#!/bin/bash' > ~/start.sh
echo 'pm2 kill' >> ~/start.sh
echo 'pkill -9 -f openclaw 2>/dev/null' >> ~/start.sh
echo 'rm -f ~/.openclaw/openclaw.lock 2>/dev/null' >> ~/start.sh
echo 'rm -f ~/.openclaw/gateway.pid 2>/dev/null' >> ~/start.sh
echo 'sleep 1' >> ~/start.sh
echo 'pm2 flush' >> ~/start.sh
echo 'pm2 start "openclawx gateway --verbose" --name "memos-node"' >> ~/start.sh
echo 'pm2 logs --raw 2>&1 | grep --line-buffered -vE "pidusage|PAGESIZE|unknown entries"' >> ~/start.sh
chmod +x ~/start.sh

echo "alias reboot-memos='bash ~/start.sh'" >> ~/.bashrc
source ~/.bashrc

# ---------------- 收尾工作 ----------------
echo -e "\n${CYAN}====================================================${NC}"
echo -e "${GREEN} 🎉 安装大功告成！${NC}"
echo -e "${CYAN}====================================================${NC}"
echo -e "为了方便以后在电脑上控制，我们需要最后设置一下SSH密码。"
echo -e "你当前的局域网IP是: ${YELLOW}$(ifconfig wlan0 | grep 'inet ' | awk '{print $2}')${NC}"
echo -e "你当前的用户名是: ${YELLOW}$(whoami)${NC}"
echo -e "请在下方输入你想要的SSH密码 (输入时不会显示)："
passwd
sshd

echo -e "\n${CYAN}====================================================${NC}"
echo -e "💡  ${YELLOW}【接下来该做什么？】${NC}"
echo -e "1. 执行${GREEN}openclawx onboarding${NC}，根据提示填入你自己的飞书应用凭证（遇到是否新装飞书插件请选“否/自带”）。"
echo -e "2. 在你的电脑Chrome浏览器上安装${GREEN}OpenClaw Browser Relay${NC}插件，让手机网关借用电脑的算力看网页！"
echo -e "${CYAN}====================================================${NC}"

echo -e "\n${GREEN}一切准备就绪！${NC}"
echo -e "日常维护请直接输入${YELLOW}reboot-memos${NC}并回车，一键启动你的AI网关吧！"

