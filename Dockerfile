[span_0](start_span)FROM google/cloud-sdk:slim[span_0](end_span)

# Set environment variables
[span_1](start_span)ENV DEBIAN_FRONTEND=noninteractive[span_1](end_span)
[span_2](start_span)ENV PORT=8080[span_2](end_span)
[span_3](start_span)ENV SHELL_PASSWORD=${SHELL_PASSWORD:-admin}[span_3](end_span)

# Install required packages
RUN apt-get update && apt-get install -y \
    curl git vim wget jq fuse nano \
    bash-completion \
    ca-certificates \
    [span_4](start_span)&& apt-get clean && rm -rf /var/lib/apt/lists/*[span_4](end_span)

# Install gcsfuse
RUN curl -fsSL https://github.com/GoogleCloudPlatform/gcsfuse/releases/download/v2.4.0/gcsfuse_2.4.0_amd64.deb \
    -o /tmp/gcsfuse.deb \
    && dpkg -i /tmp/gcsfuse.deb \
    [span_5](start_span)&& rm /tmp/gcsfuse.deb[span_5](end_span)

# Install ttyd
RUN curl -fsSL https://github.com/tsl0922/ttyd/releases/download/1.7.3/ttyd.x86_64 \
    -o /usr/local/bin/ttyd \
    [span_6](start_span)&& chmod +x /usr/local/bin/ttyd[span_6](end_span)

# Create startup script with proper error 
handling
RUN mkdir -p /app && cat > /app/start.sh << 'STARTUP_SCRIPT'
#!/bin/bash
set -e

# Set default values
SHELL_PASSWORD="${SHELL_PASSWORD:-admin}"
PORT="${PORT:-8080}"

echo "=========================================="
echo "GCP Web CLI - Starting"
echo "=========================================="
echo "Port: ${PORT}"
echo "Password: ${SHELL_PASSWORD}"
echo ""

# Create workspace directory
mkdir -p /root/workspace

# Set gcloud project
gcloud config set project llm-mcp-463803 --quiet 2>/dev/null ||
true

# Configure shell environment
export TERM=xterm-256color
export CLICOLOR=1

echo "Starting ttyd on port ${PORT}..."
echo ""

# Start ttyd with proper error handling
exec ttyd \
  --port "${PORT}" \
  --writable \
  --credential "admin:${SHELL_PASSWORD}" \
  --client-option "fontSize=14" \
  bash
STARTUP_SCRIPT

[span_7](start_span)chmod +x /app/start.sh[span_7](end_span)

# Configure shell environment
RUN cat >> /root/.bashrc << 'BASHRC_CONFIG'

# Enable colors
export TERM=xterm-256color
export CLICOLOR=1

# Colored ls
alias ls="ls --color=auto"
alias ll="ls -lah --color=auto"
alias la="ls -A --color=auto"
alias grep="grep --color=auto"
alias diff="diff --color=auto"

# Colored prompt
export PS1="\[\e[01;32m\]\u@gcp-cli\[\e[00m\]:\[\e[01;34m\]\w\[\e[00m\]\$ "

# Enable bash completion
if [ -f /usr/share/bash-completion/bash_completion ];
then
    . /usr/share/bash-completion/bash_completion
fi

# Enable gcloud completion
if [ -f /usr/lib/google-cloud-sdk/completion.bash.inc ]; then
    .
/usr/lib/google-cloud-sdk/completion.bash.inc
fi

echo ""
echo "================================"
echo "  ✅ GCP Web CLI 已就緒"
echo "  📁 專案: llm-mcp-463803"
echo "================================"
echo ""
echo "💡 常用指令："
echo "  掛載 GCS : gcsfuse --implicit-dirs llm-mcp-463803-shell-home /root/workspace"
echo "  卸載 GCS : fusermount -u /root/workspace"
echo "  確認身份 : gcloud auth list"
echo "  列出 Bucket: gcloud storage buckets list"
echo ""
[span_8](start_span)BASHRC_CONFIG[span_8](end_span)

# Health check script
RUN cat > /app/health-check.sh << 'HEALTH_CHECK'
#!/bin/bash
# Simple health check - just verify the port is listening
if netstat -tuln 2>/dev/null |
grep -q ":${PORT}"; then
    exit 0
else
    exit 1
fi
HEALTH_CHECK

[span_9](start_span)chmod +x /app/health-check.sh[span_9](end_span)

# Expose the port
[span_10](start_span)EXPOSE 8080[span_10](end_span)

# Set working directory
[span_11](start_span)WORKDIR /root[span_11](end_span)

# Start the application
[span_12](start_span)CMD ["/app/start.sh"][span_12](end_span)
