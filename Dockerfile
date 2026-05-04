FROM google/cloud-sdk:slim

# 安裝必要的工具
RUN apt-get update && apt-get install -y \
    curl git vim wget jq nano \
    bash-completion ca-certificates gnupg \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 安裝 ttyd
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

# 設置 Shell 環境 - 不使用 heredoc，直接使用 echo 命令
RUN echo 'export TERM=xterm-256color' >> /root/.bashrc && \
    echo 'export CLICOLOR=1' >> /root/.bashrc && \
    echo 'alias ls="ls --color=auto"' >> /root/.bashrc && \
    echo 'alias ll="ls -lah --color=auto"' >> /root/.bashrc && \
    echo 'alias la="ls -A --color=auto"' >> /root/.bashrc && \
    echo 'alias grep="grep --color=auto"' >> /root/.bashrc && \
    echo 'alias diff="diff --color=auto"' >> /root/.bashrc && \
    echo '' >> /root/.bashrc && \
    echo 'if [ -f /usr/share/bash-completion/bash_completion ]; then' >> /root/.bashrc && \
    echo '    . /usr/share/bash-completion/bash_completion' >> /root/.bashrc && \
    echo 'fi' >> /root/.bashrc && \
    echo 'if [ -f /usr/lib/google-cloud-sdk/completion.bash.inc ]; then' >> /root/.bashrc && \
    echo '    . /usr/lib/google-cloud-sdk/completion.bash.inc' >> /root/.bashrc && \
    echo 'fi' >> /root/.bashrc && \
    echo '' >> /root/.bashrc && \
    echo 'echo ""' >> /root/.bashrc && \
    echo 'echo "================================"' >> /root/.bashrc && \
    echo 'echo "  ✅ OpenClaw CLI 已就緒"' >> /root/.bashrc && \
    echo 'echo "  📁 專案: llm-mcp-463803"' >> /root/.bashrc && \
    echo 'echo "================================"' >> /root/.bashrc && \
    echo 'echo ""' >> /root/.bashrc

# 暴露 ttyd 端口
EXPOSE 8080

# 啟動腳本
ENTRYPOINT ["/entrypoint.sh"]
