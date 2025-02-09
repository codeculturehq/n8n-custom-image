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
      pandoc

# Tell Puppeteer to skip installing Chrome. We'll be using the installed package.
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser

RUN npm install -g cryptr

USER node

# Create the directory and install npm package
RUN mkdir -p ~/.n8n/nodes
RUN cd ~/.n8n/nodes && npm install --production --force n8n-nodes-puppeteer

# Create a virtual environment for Python packages
RUN python3 -m venv /venv

# Activate the virtual environment and install pymupdf4llm
# Note: In a Dockerfile, each RUN command is isolated; to ensure that the virtual environment is used,
# you might need to update the PATH in subsequent commands.
RUN . /venv/bin/activate && pip install -U pymupdf4llm

# Optionally, add the virtual environment to PATH for later steps:
ENV PATH="/venv/bin:$PATH"
