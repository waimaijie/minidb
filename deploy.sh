#!/bin/bash
REPO_URL="https://github.com/waimaijie/minidb.git"
WORK_DIR="/opt/mini-supabase"

echo "➡️ 开始部署基础设施..."

if ! command -v docker &> /dev/null; then
    echo "⚙️ 未检测到 Docker，正在自动安装..."
    curl -fsSL https://get.docker.com | bash
fi

if [ -d "$WORK_DIR" ]; then
    cd $WORK_DIR && git pull
else
    git clone $REPO_URL $WORK_DIR && cd $WORK_DIR
fi

if [ ! -f ".env" ]; then
    echo "⚠️ 检测到首次部署，已生成 .env 模板！"
    cp .env.template .env
    echo "🛑 部署已暂停。请执行: nano $WORK_DIR/.env 填入密码"
    echo "✍️ 填写保存后，再次执行本脚本拉起容器！"
    exit 1
fi

echo "🚀 正在拉起容器..."
docker compose down
docker compose up -d
echo "✅ 容器拉起完毕！等待后续数据库初始化..."