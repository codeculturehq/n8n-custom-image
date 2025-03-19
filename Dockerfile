ARG N8N_VERSION=latest
FROM n8nio/n8n:${N8N_VERSION}
ENV PYTHONUNBUFFERED=1

RUN if [ -z "$N8N_VERSION" ] ; then echo "✋ The N8N_VERSION argument is missing!" ; exit 1; fi

USER root

# Installs latest Chromium (100) package.
RUN apk add --no-cache \
      chromium \
      nss \
      freetype \
      harfbuzz \
      ttf-freefont \
      yarn \
      curl \
      gcc \
      make \
      zlib-dev \
      libffi-dev \
      openssl-dev \
      musl-dev \
      py3-pip \
      python3-dev \
      py3-setuptools \
      pandoc \
      gcc \
      musl-dev \
      linux-headers \
      make \
      g++ \
      clang-dev

# Tell Puppeteer to skip installing Chrome. We'll be using the installed package.
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser

RUN npm install -g cryptr

# Install yt-dlp
RUN curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp \
    && chmod a+rx /usr/local/bin/yt-dlp

# Install the community node
RUN cd /usr/local/lib/node_modules/n8n && \
    npm install @endcycles/n8n-nodes-youtube-transcript n8n-nodes-puppeteer n8n-nodes-advanced-flow n8n-nodes-elevenlabs n8n-nodes-firecrawl n8n-nodes-browserless n8n-nodes-mcp n8n-nodes-playwright
  
USER node

# Install custom n8n nodes
#RUN mkdir -p ~/pymupdfllm 

# Install the Python package within the virtual environment
# RUN pip install -U --break-system-packages --only-binary :all: --target ~/pymupdfllm pymupdf4llm
RUN python3 -m venv /home/node/venv
ENV PATH="/home/node/venv/bin:${PATH}"
# RUN pip install -U --break-system-packages pymupdf4llm
# RUN pip install -U --break-system-packages --only-binary :all: pymupdf4llm
