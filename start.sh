#!/bin/bash
set -e

echo "🚀 Starting OpenClaw Deployment..."

# 1. 初始化目录结构
mkdir -p /root/.openclaw/agents/main/sessions
mkdir -p /root/.openclaw/credentials
mkdir -p /root/.openclaw/sessions
mkdir -p /root/.openclaw/workspace

# 2. 恢复历史数据
echo "🔄 Restoring data from HuggingFace Dataset..."
python3 /app/sync.py

# 3. 清洗 API 地址 (去除末尾多余的斜杠或路径)
CLEAN_BASE=$(echo "$OPENAI_API_BASE" | sed "s|/chat/completions||g" | sed "s|/v1/|/v1|g" | sed "s|/v1$|/v1|g")

# 4. 动态生成 openclaw.json 配置文件
cat > /root/.openclaw/openclaw.json <<EOF
{
  "models": {
    "providers": {
      "nvidia": {
        "baseUrl": "$CLEAN_BASE",
        "apiKey": "$OPENAI_API_KEY",
        "api": "openai-completions",
        "models": [
          {
            "id": "$MODEL",
            "name": "nvidia/$MODEL",
            "contextWindow": 128000,
            "maxTokens": 16384
          }
        ]
      }
    }
  },
  "agents": { 
    "defaults": { 
      "model": { "primary": "nvidia/$MODEL" } 
    } 
  },
  "commands": {
    "restart": true,
    "native": "auto"
  },
  "gateway": {
    "mode": "local",
    "bind": "lan",
    "port": $PORT,
    "trustedProxies": ["0.0.0.0/0"],
    "auth": { 
      "mode": "token", 
      "token": "$OPENCLAW_GATEWAY_PASSWORD" 
    },
    "controlUi": {
      "enabled": true,
      "allowInsecureAuth": true,
      "allowedOrigins": [
        "https://xopscube-openclaw.hf.space"
      ]
    }
  }
}
EOF

echo "⚙️ Configuration generated."

# 5. 启动后台定时备份任务 (每 45 分钟备份一次，避免频繁触发限流)
(while true; do 
    sleep 2700; 
    echo "⏰ Triggering scheduled backup...";
    python3 /app/sync.py backup; 
done) &

# 6. 修复权限并启动 OpenClaw
openclaw doctor --fix || true
echo "🦞 Launching OpenClaw Gateway on port $PORT..."
openclaw gateway run --port $PORT &

GATEWAY_PID=$!

# 7. 等 Gateway 就绪
sleep 3

# 8. 后台轮询：自动批准所有待配对设备
(
  while true; do
    
    # 获取待配对设备列表并逐个批准
    echo "========== DEVICES =========="
    openclaw devices list || true
    sleep 2
    openclaw devices list --json 2>/dev/null | jq -r '.pending[].requestId' | while read -r device_id; do
      openclaw devices approve "$device_id" || true
    done
    sleep 5
  done
) &


wait $GATEWAY_PID
