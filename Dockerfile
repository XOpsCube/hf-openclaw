FROM node:22-slim

# 1. 安装系统级依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    git openssh-client build-essential python3 python3-pip \
    g++ make ca-certificates curl jq && rm -rf /var/lib/apt/lists/*

# 2. 安装 Python 依赖 (HuggingFace Hub)
RUN pip3 install --no-cache-dir huggingface_hub --break-system-packages

# 3. 全局安装 OpenClaw (使用最新稳定版)
RUN npm install -g openclaw@latest --unsafe-perm && openclaw --version

# 4. 设置工作目录
WORKDIR /app

# 5. 拷贝脚本文件
COPY sync.py .
COPY start.sh .
RUN chmod +x start.sh

# 6. 设置环境变量
ENV PORT=7860 
ENV HOME=/root

EXPOSE 7860

# 7. 启动命令
CMD ["./start-openclaw.sh"]
