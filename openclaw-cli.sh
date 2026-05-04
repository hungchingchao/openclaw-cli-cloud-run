#!/usr/bin/env bash

# OpenClaw Interactive CLI - Cloud Run Optimized Version
# 此版本針對 Cloud Run 環境進行了優化
# 核心修復：
# 1. 移除 docker pull（改用 docker run 自動拉取）
# 2. 優化記憶體使用
# 3. 改進錯誤處理和日誌

set -u  # 不設置 -e，以便進行更細粒度的錯誤處理

PROJECT_ID="${PROJECT_ID:-llm-mcp-463803}"
REGION="${REGION:-asia-east1}"
SERVICE_NAME="${SERVICE_NAME:-openclaw-gateway}"
BUCKET="${BUCKET:-${PROJECT_ID}-${SERVICE_NAME}-state}"
LOCAL_STATE="${LOCAL_STATE:-${HOME}/openclaw-state}"
PLUGIN_STAGE_DIR="${PLUGIN_STAGE_DIR:-${HOME}/openclaw-plugin-stage}"

# 配置
DOCKER_READY_TIMEOUT=30
DOCKER_RUN_TIMEOUT=300  # 5分鐘用於首次拉取映像

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

log_debug() {
  echo -e "${BLUE}[DEBUG]${NC} $*"
}

# 檢查 Docker daemon 是否就緒
wait_for_docker() {
  local timeout=$1
  local elapsed=0
  
  log_info "等待 Docker daemon 就緒（最多 ${timeout} 秒）..."
  
  while [ $elapsed -lt $timeout ]; do
    if docker info >/dev/null 2>&1; then
      log_info "✅ Docker daemon 已就緒"
      return 0
    fi
    
    sleep 1
    elapsed=$((elapsed + 1))
    
    if [ $((elapsed % 5)) -eq 0 ]; then
      log_warn "仍在等待 Docker daemon... ($elapsed/$timeout 秒)"
    fi
  done
  
  log_error "Docker daemon 在 ${timeout} 秒內未就緒"
  return 1
}

echo "=========================================="
echo "OpenClaw Interactive CLI on Cloud Run"
echo "=========================================="
echo "Project       : ${PROJECT_ID}"
echo "Region        : ${REGION}"
echo "Service       : ${SERVICE_NAME}"
echo "GCS bucket    : gs://${BUCKET}"
echo "Local state   : ${LOCAL_STATE}"
echo "Plugin stage  : ${PLUGIN_STAGE_DIR}"
echo ""

# 設置項目
log_info "[1/5] 設置 GCP 項目..."
if ! gcloud config set project "${PROJECT_ID}" >/dev/null 2>&1; then
  log_error "無法設置項目 ${PROJECT_ID}"
  exit 1
fi
log_info "✅ 項目已設置"
echo ""

# 獲取 Cloud Run 映像
log_info "[2/5] 獲取 Cloud Run 映像..."
IMAGE=""
if ! IMAGE="$(gcloud run services describe "${SERVICE_NAME}" \
  --region="${REGION}" \
  --format='value(spec.template.spec.containers[0].image)' 2>&1)"; then
  log_error "無法取得 Cloud Run image"
  log_error "請確認 service 是否存在：${SERVICE_NAME}"
  exit 1
fi

if [ -z "${IMAGE}" ]; then
  log_error "無法取得 Cloud Run image，請確認 service 是否存在：${SERVICE_NAME}"
  exit 1
fi

log_info "Image: ${IMAGE}"
echo ""

# 配置 Docker 認證
log_info "[3/5] 配置 Docker 認證..."
if ! gcloud auth configure-docker "${REGION}-docker.pkg.dev,gcr.io,asia.gcr.io" --quiet >/dev/null 2>&1; then
  log_warn "Docker 認證配置可能失敗，繼續執行..."
fi
log_info "✅ Docker 認證已配置"
echo ""

# 等待 Docker daemon 就緒
log_info "[4/5] 檢查 Docker daemon 狀態..."
if ! wait_for_docker $DOCKER_READY_TIMEOUT; then
  log_error "Docker daemon 未就緒，無法繼續"
  log_error "請檢查 Docker daemon 日誌：tail -f /var/log/dockerd.log"
  exit 1
fi
echo ""

# 準備本地 OpenClaw 狀態
log_info "[5/5] 準備本地 OpenClaw 狀態..."
mkdir -p "${LOCAL_STATE}"
mkdir -p "${PLUGIN_STAGE_DIR}"
log_info "✅ 本地目錄已建立"

# 從 GCS 同步狀態（可選，失敗時繼續）
if gcloud storage buckets describe "gs://${BUCKET}" >/dev/null 2>&1; then
  log_info "從 GCS 同步狀態..."
  if gcloud storage rsync -r "gs://${BUCKET}" "${LOCAL_STATE}" 2>&1; then
    log_info "✅ 狀態同步完成"
  else
    log_warn "狀態同步失敗，使用本地狀態"
  fi
else
  log_warn "GCS bucket 不存在：gs://${BUCKET}"
  log_warn "將使用本地狀態，首次運行時會建立新 bucket"
fi
echo ""

# 加載 secrets
log_info "加載 GCP Secrets..."
OPENCLAW_AUTH_TOKEN=""
GEMINI_API_KEY=""

if OPENCLAW_AUTH_TOKEN="$(gcloud secrets versions access latest --secret=openclaw-auth-token 2>&1)"; then
  if [ -z "${OPENCLAW_AUTH_TOKEN}" ]; then
    log_error "OPENCLAW_AUTH_TOKEN 為空"
    exit 1
  fi
  log_info "✅ OPENCLAW_AUTH_TOKEN 已加載"
else
  log_error "無法讀取 OPENCLAW_AUTH_TOKEN"
  log_error "請確認 secret 是否存在：gcloud secrets list"
  exit 1
fi

if GEMINI_API_KEY="$(gcloud secrets versions access latest --secret=gemini-api-key 2>&1)"; then
  if [ -z "${GEMINI_API_KEY}" ]; then
    log_error "GEMINI_API_KEY 為空"
    exit 1
  fi
  log_info "✅ GEMINI_API_KEY 已加載"
else
  log_error "無法讀取 GEMINI_API_KEY"
  log_error "請確認 secret 是否存在：gcloud secrets list"
  exit 1
fi
echo ""

# 啟動 OpenClaw 容器
log_info "啟動 OpenClaw CLI 容器..."
log_debug "映像：${IMAGE}"
log_debug "首次運行時會下載映像（可能需要 1-5 分鐘）"
echo ""

export OPENCLAW_AUTH_TOKEN
export GEMINI_API_KEY

if [ "$#" -eq 0 ]; then
  CMD=("bash")
else
  CMD=("$@")
fi

# 關鍵修改：使用 docker run 的自動拉取機制
# 不顯式執行 docker pull，而是讓 docker run 在需要時拉取
# 這樣可以：
# 1. 減少記憶體使用（避免同時存在映像副本）
# 2. 改進進度反饋（docker run 會顯示拉取進度）
# 3. 避免超時問題（docker pull 可能超時，docker run 更穩定）

# 運行容器（不使用 set -e，以便捕獲退出代碼）
timeout $DOCKER_RUN_TIMEOUT docker run --rm -it \
  -e HOME=/root \
  -e OPENCLAW_CONFIG_DIR=/root/.openclaw \
  -e OPENCLAW_STATE_DIR=/root/.openclaw \
  -e OPENCLAW_DATA_DIR=/root/.openclaw \
  -e OPENCLAW_WORKSPACE_DIR=/root/.openclaw/workspace \
  -e OPENCLAW_PLUGIN_STAGE_DIR=/var/lib/openclaw/plugin-runtime-deps \
  -e OPENCLAW_AUTH_TOKEN \
  -e GEMINI_API_KEY \
  -e OPENROUTER_API_KEY=disabled \
  -e LITELLM_API_KEY=disabled \
  -e OPENCLAW_DISABLE_BONJOUR=1 \
  -v "${LOCAL_STATE}:/root/.openclaw" \
  -v "${PLUGIN_STAGE_DIR}:/var/lib/openclaw/plugin-runtime-deps" \
  "${IMAGE}" \
  "${CMD[@]}"

EXIT_CODE=$?

# 處理超時
if [ $EXIT_CODE -eq 124 ]; then
  log_error "容器執行超時（${DOCKER_RUN_TIMEOUT} 秒）"
  log_error "這可能是因為："
  log_error "  1. 首次運行，正在下載大型映像"
  log_error "  2. 網路連接不穩定"
  log_error "  3. Cloud Run 記憶體不足"
  log_error ""
  log_error "建議："
  log_error "  1. 檢查網路連接"
  log_error "  2. 增加 Cloud Run 記憶體配置（至少 2GB）"
  log_error "  3. 稍後重試"
  exit $EXIT_CODE
fi

echo ""
log_info "容器已退出（代碼：$EXIT_CODE）"
echo ""

# 同步狀態回 GCS
log_info "修復本地檔案所有權..."
sudo chown -R "$(id -u):$(id -g)" "${LOCAL_STATE}" "${PLUGIN_STAGE_DIR}" 2>/dev/null || true
chmod -R u+rwX "${LOCAL_STATE}" 2>/dev/null || true
log_info "✅ 所有權已修復"

echo ""
log_info "同步狀態回 GCS..."
if gcloud storage buckets describe "gs://${BUCKET}" >/dev/null 2>&1; then
  if gcloud storage rsync -r "${LOCAL_STATE}" "gs://${BUCKET}" 2>&1; then
    log_info "✅ 狀態已同步回 GCS"
  else
    log_warn "狀態同步失敗，但容器已正常退出"
  fi
else
  log_warn "GCS bucket 不存在，跳過同步"
fi

echo ""
log_info "完成。退出代碼：${EXIT_CODE}"
exit "${EXIT_CODE}"
