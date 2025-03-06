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

USER node

# Install custom n8n nodes
RUN cd ~/.n8n/node && mkdir custom && mkdir -p ~/pymupdfllm
RUN cd ~/.n8n/node/custom && npm install --production --force n8n-nodes-puppeteer n8n-nodes-advanced-flow n8n-nodes-elevenlabs n8n-nodes-firecrawl n8n-nodes-youtube-transcript n8n-nodes-browserless

# RUN python3 -m venv ~/venv
# ENV PATH="~/venv/bin:$PATH"

# Install the Python package within the virtual environment
RUN pip install -U --break-system-packages --only-binary :all: --target ~/pymupdfllm pymupdf4llm
