#!/bin/bash

# OpenClaw CLI Cloud Run Service - Entrypoint
# 從 Google Secret Manager 讀取密碼
set -u

# 顏色輸出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

if [ -z "${PROJECT_ID:-}" ]; then
  log_error "PROJECT_ID 環境變數未設置"
  exit 1
fi

log_info "✅ PROJECT_ID 已設置：${PROJECT_ID}"

# 從 Secret Manager 讀取密碼
log_info "從 Secret Manager 讀取密碼..."

SHELL_PASSWORD=$(gcloud secrets versions access latest --secret=openclaw-shell-password --project="${PROJECT_ID}" 2>/dev/null)

if [ -z "${SHELL_PASSWORD}" ]; then
  log_error "無法從 Secret Manager 讀取密碼"
  log_error "請確保："
  log_error "  1. Secret 名稱：openclaw-shell-password"
  log_error "  2. Secret 存在於專案：${PROJECT_ID}"
  log_error "  3. Cloud Run 服務帳戶有讀取權限"
  exit 1
fi

log_info "✅ 密碼已從 Secret Manager 讀取"

# 驗證 ttyd
log_info "驗證 ttyd..."
if ! command -v ttyd &> /dev/null; then
  log_error "ttyd 未安裝"
  exit 1
fi

TTYD_VERSION=$(ttyd --version 2>&1 || echo "unknown")
log_info "✅ ttyd 版本：$TTYD_VERSION"

echo ""
log_info "================================"
log_info "  ✅ OpenClaw CLI Cloud Run"
log_info "  📁 專案: ${PROJECT_ID}"
log_info "================================"
echo ""

log_info "啟動 ttyd web shell..."
log_info "訪問地址：http://localhost:8080"
log_info "用戶名：admin"
log_info "密碼：[來自 Secret Manager]"
echo ""

# 啟動 ttyd
# -w: 允許寫入
# --credential: 設置認證信息
# bash: 使用 bash shell
exec ttyd --port 8080 -w \
  --credential "admin:${SHELL_PASSWORD}" \
  bash
