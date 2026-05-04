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
RUN printf '\n\
export TERM=xterm-256color\n\
export CLICOLOR=1\n\
alias ls="ls --color=auto"\n\
alias ll="ls -lah --color=auto"\n\
alias la="ls -A --color=auto"\n\
alias grep="grep --color=auto"\n\
alias diff="diff --color=auto"\n\
export PS1="\\[\\e[01;32m\\]\\u@openclaw-cli\\[\\e[00m\\]:\\[\\e[01;34m\\]\\w\\[\\e[00m\\]\\$ "\n\
\n\
if [ -f /usr/share/bash-completion/bash_completion ]; then\n\
    . /usr/share/bash-completion/bash_completion\n\
fi\n\
if [ -f /usr/lib/google-cloud-sdk/completion.bash.inc ]; then\n\
    . /usr/lib/google-cloud-sdk/completion.bash.inc\n\
fi\n\
\n\
echo ""\n\
echo "================================"\n\
echo "  ✅ OpenClaw CLI 已就緒"\n\
echo "  📁 專案: llm-mcp-463803"\n\
echo "================================"\n\
echo ""\n\
echo "💡 使用方式："\n\
echo "  執行 openclaw-cli 進入 OpenClaw 互動式 CLI"\n\
echo "  或直接執行 openclaw-cli 命令"\n\
echo ""\n\
' >> /root/.bashrc

# 暴露 ttyd 端口
EXPOSE 8080

# 啟動腳本
ENTRYPOINT ["/entrypoint.sh"]
