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
# 使用 upgrade 确保环境变量和底层库最新，防止 cpu_arch 报错
pkg upgrade -y -o Dpkg::Options::="--force-confnew"
pkg install -y openssh lsof proot-distro jq npm curl wget

echo -e "\n${YELLOW}[2/4] 正在安装Node.js进程管家 (PM2)...${NC}"
npm install -g pm2

# ---------------- 阶段 2：强制安装核心Ubuntu ----------------
echo -e "\n${YELLOW}[3/4] 正在拉取并初始化 Ubuntu 核心容器...${NC}"
# 明确执行官方容器安装，防止依赖缺失
proot-distro install ubuntu

# 执行原作者的核心安装脚本 (拆解网址防格式化)
REPO="raw.githubusercontent.com/mithun50"
curl -fsSL https://${REPO}/openclaw-termux/main/install.sh | bash

# ---------------- 阶段 3：交互式获取凭证 ----------------
echo -e "\n${CYAN}====================================================${NC}"
echo -e "${GREEN} 🔑 请输入你的MemOS API Key (在控制台获取):${NC}"
echo -e "${CYAN}====================================================${NC}"
read -p "API Key: " USER_API_KEY

if [ -z "$USER_API_KEY" ]; then
    echo -e "${RED}错误：API Key不能为空！脚本终止。${NC}"
    exit 1
fi

# ---------------- 阶段 4：进入容器内部进行“微创手术” ----------------
echo -e "\n${YELLOW}[4/4] 正在进入 Ubuntu 容器内部注入配置...${NC}"

# 核心修复：不再从外部强行写文件，而是直接登录进 ubuntu 内部执行一连串命令！
proot-distro login ubuntu -- bash -c "
    export DEBIAN_FRONTEND=noninteractive
    
    # 1. 写入 API Key
    mkdir -p /root/.openclaw
    echo 'MEMOS_API_KEY=${USER_API_KEY}' > /root/.openclaw/.env
    
    # 2. 安装直连插件
    npm install -g @memtensor/memos-cloud-openclaw-plugin@latest
    
    # 3. 安装 jq 并修复 JSON
    apt update && apt install -y jq
    JSON_FILE=\"/root/.openclaw/openclaw.json\"
    if [ -f \"\$JSON_FILE\" ]; then
        jq 'del(.tools[\"@memtensor/memos-cloud-openclaw-plugin\"].apiKey) | .tools.profile = \"default\"' \"\$JSON_FILE\" > \"\$JSON_FILE.tmp\" && mv \"\$JSON_FILE.tmp\" \"\$JSON_FILE\"
    fi
"

# ---------------- 注入终极防死锁指令 (内外兼修) ----------------
sed -i '/alias reboot-memos/d' ~/.bashrc
echo '#!/bin/bash' > ~/start.sh
echo 'pm2 kill' >> ~/start.sh
# 杀掉外层的残余
echo 'pkill -9 -f openclaw 2>/dev/null' >> ~/start.sh
# 派杀手进 Ubuntu 内部彻底清理 Node 进程和死锁文件
echo 'proot-distro login ubuntu -- pkill -9 node 2>/dev/null' >> ~/start.sh
echo 'proot-distro login ubuntu -- rm -f /root/.openclaw/openclaw.lock 2>/dev/null' >> ~/start.sh
echo 'proot-distro login ubuntu -- rm -f /root/.openclaw/gateway.pid 2>/dev/null' >> ~/start.sh
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
echo -e "1. 执行${GREEN}openclawx onboarding${NC}，根据提示填入你自己的飞书应用凭证。"
echo -e "2. 在电脑上安装 Browser Relay 插件协同工作！"
echo -e "${CYAN}====================================================${NC}"
echo -e "日常维护请直接输入 ${YELLOW}reboot-memos${NC} 并回车！"
