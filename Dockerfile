# Multi-stage build for Autocoder
FROM node:20-slim AS frontend-builder

WORKDIR /app/ui
COPY ui/package*.json ./
RUN npm ci
COPY ui/ ./
RUN npm run build

# Python backend with Claude Code
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies + Node.js for Claude Code
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    ca-certificates \
    gnupg \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install Playwright system dependencies (required for browser automation)
# These are needed for Chromium to run in headless mode
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Core browser dependencies
    libnss3 \
    libnspr4 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libdbus-1-3 \
    libxkbcommon0 \
    libatspi2.0-0 \
    # X11 extensions (needed even in headless)
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    # Graphics and rendering
    libgbm1 \
    libpango-1.0-0 \
    libcairo2 \
    # Audio (some pages need it)
    libasound2 \
    # Fonts for proper text rendering
    fonts-liberation \
    fonts-noto-color-emoji \
    # Additional libs that Chromium may need
    libx11-xcb1 \
    libxcb-dri3-0 \
    && rm -rf /var/lib/apt/lists/*

# Install Claude Code CLI globally
RUN npm install -g @anthropic-ai/claude-code

# Pre-install Playwright browsers (Chromium only to save space)
# This speeds up first run and ensures browsers are available
RUN npx playwright install chromium

# Copy requirements and install Python dependencies
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Copy built frontend from builder stage
COPY --from=frontend-builder /app/ui/dist ./ui/dist

# Copy entrypoint script
COPY entrypoint.sh /app/entrypoint.sh

# Create non-root user for security
RUN useradd -m -u 1000 autocoder && \
    chown -R autocoder:autocoder /app && \
    mkdir -p /home/autocoder/.claude/debug && \
    mkdir -p /home/autocoder/.claude/statsig && \
    mkdir -p /home/autocoder/.cache/ms-playwright && \
    chown -R autocoder:autocoder /home/autocoder && \
    chmod -R 777 /home/autocoder/.claude && \
    chmod +x /app/entrypoint.sh
USER autocoder

# Set Claude Code environment
ENV ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
# Force headless mode in Docker (no display available)
ENV PLAYWRIGHT_HEADLESS=true

# Expose port
EXPOSE 8888

# Health check using /api/health endpoint (excluded from auth)
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8888/api/health')" || exit 1

# Use entrypoint to clone projects at startup
ENTRYPOINT ["/app/entrypoint.sh"]
