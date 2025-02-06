ARG N8N_VERSION
FROM n8nio/n8n:${N8N_VERSION}
ENV PYTHONUNBUFFERED=1
ARG PYTHON_VERSION=3.11.9

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
      && cd /opt \
      && wget https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz \
      && tar xzf Python-${PYTHON_VERSION}.tgz \
      && cd /opt/Python-${PYTHON_VERSION} \
      && ./configure --prefix=/usr --enable-optimizations --with-ensurepip=install \
      && make install \
      && rm /opt/Python-${PYTHON_VERSION}.tgz /opt/Python-${PYTHON_VERSION} -rf \
      && ln -sf python3 /usr/bin/python \
      && ln -sf pip3 /usr/bin/pip

# Tell Puppeteer to skip installing Chrome. We'll be using the installed package.
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser

RUN npm install -g cryptr

USER node

RUN mkdir -p ~/.n8n/nodes

# Add custom n8n nodes from Codely
RUN cd ~/.n8n/nodes && \
    npm install --production --force n8n-nodes-puppeteer \
    && pip install --break-system-packages pymupdf4llm  \
    && pip install --break-system-packages --no-cache-dir docling --extra-index-url https://download.pytorch.org/whl/cpu
