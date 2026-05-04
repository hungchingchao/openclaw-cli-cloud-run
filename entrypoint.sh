#!/bin/bash

# OpenClaw CLI Cloud Run Service - Entrypoint
# 此腳本是 Cloud Run 容器的啟動點
# 功能：啟動 ttyd web shell，提供互動式 openclaw-cli 訪問

set -u

# 顏色輸出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日誌函數
log_info() {
  echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $*"
}

# 驗證必要的環境變數
log_info "驗證環境變數..."

if [ -z "${SHELL_PASSWORD:-}" ]; then
  log_error "SHELL_PASSWORD 環境變數未設置"
  log_error "請在 Cloud Run 服務中設置此環境變數"
  exit 1
fi

log_info "✅ SHELL_PASSWORD 已設置"

# 驗證 GCP 認證
log_info "驗證 GCP 認證..."
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
  log_error "未找到活躍的 GCP 認證"
  log_error "請確保 Cloud Run 服務有正確的 IAM 權限"
  exit 1
fi

log_info "✅ GCP 認證已驗證"

# 驗證 ttyd
log_info "驗證 ttyd..."
if ! command -v ttyd &> /dev/null; then
  log_error "ttyd 未安裝"
  exit 1
fi

TTYD_VERSION=$(ttyd --version 2>&1 || echo "unknown")
log_info "✅ ttyd 版本：$TTYD_VERSION"

# 驗證 openclaw-cli
log_info "驗證 openclaw-cli..."
if ! command -v openclaw-cli &> /dev/null; then
  log_error "openclaw-cli 未安裝"
  exit 1
fi

log_info "✅ openclaw-cli 已安裝"

echo ""
log_info "================================"
log_info "  ✅ OpenClaw CLI Cloud Run"
log_info "  📁 專案: llm-mcp-463803"
log_info "================================"
echo ""

log_info "啟動 ttyd web shell..."
log_info "訪問地址：http://localhost:8080"
log_info "用戶名：admin"
log_info "密碼：${SHELL_PASSWORD}"
echo ""

# 啟動 ttyd
# -w: 允許寶入
# --credential: 設置認證信息
# /bin/bash --login: 使用完整路徑的 bash 並載入登入脚本
exec ttyd --port 8080 -w \
  --credential "admin:${SHELL_PASSWORD}" \
  /bin/bash --login
