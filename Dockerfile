FROM google/cloud-sdk:slim

# 安裝必要的工具
RUN apt-get update && apt-get install -y \
    curl git vim wget jq nano \
    bash-completion ca-certificates gnupg \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 安裝 ttyd（用於提供 web shell）
RUN curl -fsSL https://github.com/tsl0922/ttyd/releases/download/1.7.3/ttyd.x86_64 \
    -o /usr/local/bin/ttyd \
    && chmod +x /usr/local/bin/ttyd

# 建立應用目錄
WORKDIR /app

# 複製 openclaw-cli.sh
COPY openclaw-cli.sh /usr/local/bin/openclaw-cli
RUN chmod +x /usr/local/bin/openclaw-cli

# 複製啟動腳本
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# 設置環境變數
ENV PATH="/usr/local/bin:${PATH}" \
    HOME="/root" \
    SHELL="/bin/bash"

# 設置 Shell 環境
RUN cat >> /root/.bashrc << 'EOF'

export TERM=xterm-256color
export CLICOLOR=1
alias ls="ls --color=auto"
alias ll="ls -lah --color=auto"
alias la="ls -A --color=auto"
alias grep="grep --color=auto"
alias diff="diff --color=auto"
export PS1="\[\e[01;32m\]\u@openclaw-cli\[\e[00m\]:\[\e[01;34m\]\w\[\e[00m\]\$ "

if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
fi
if [ -f /usr/lib/google-cloud-sdk/completion.bash.inc ]; then
    . /usr/lib/google-cloud-sdk/completion.bash.inc
fi

echo ""
echo "================================"
echo "  ✅ OpenClaw CLI 已就緒"
echo "  📁 專案: llm-mcp-463803"
echo "================================"
echo ""
echo "💡 使用方式："
echo "  執行 openclaw-cli 進入 OpenClaw 互動式 CLI"
echo "  或直接執行 openclaw-cli 命令"
echo ""

EOF

# 暴露 ttyd 端口
EXPOSE 8080

# 啟動腳本
ENTRYPOINT ["/entrypoint.sh"]
