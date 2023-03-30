FROM debian:bullseye-slim as builder
ENV DEBIAN_FRONTEND noninteractive
ARG MODULES_TAG=v2.4.169

RUN apt-get update && apt-get install -y --no-install-recommends \
        curl \
        imagemagick \
        libcaca0 \
        libcjson1 \
        libfuzzy2 \
        libgl1 \
        libglib2.0-0 \
        libjpeg62-turbo \
        liblua5.3-0 \
        libpq5 \
        libpoppler-cpp0v5 \
        libxext6 \
        libxrender1 \
        libzbar0 \
        python3 \
        python3-distutils \
        python3-dnspython \
        tesseract-ocr \
        zbar-tools \
    && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        cmake \
        git \
        libcaca-dev \
        libcjson-dev \
        libfuzzy-dev \
        libjpeg-dev \
        liblua5.3-dev \
        libpoppler-cpp-dev \
        libzbar-dev \
        pkg-config \
        python3-dev \
        python3-pip \
    && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Build MISP and Install Modules
    WORKDIR /srv

    RUN git clone --depth 1 https://github.com/stricaud/gtcaca.git /srv/gtcaca; \
        mkdir -p /srv/gtcaca/build; cd /srv/gtcaca/build || exit; cmake .. && make install

    RUN git clone --depth 1 https://github.com/stricaud/faup.git /srv/faup; \
        mkdir -p /srv/faup/build; cd /srv/faup/build || exit; cmake .. && make install; \
        cd /srv/faup/src/lib/bindings/python || exit; pip3 install . --no-cache-dir

    RUN git clone --branch ${MODULES_TAG} --depth 1  https://github.com/MISP/misp-modules.git /srv/misp-modules; \
        cd /srv/misp-modules || exit; pip3 install pyeti-python3; pip3 install -I -r REQUIREMENTS --no-cache-dir; \
        pip3 install . --no-cache-dir

    RUN ldconfig; \
        sed -i "s/db=db/db=db, password=password/g" /usr/local/lib/python3.9/dist-packages/misp_modules/helpers/cache.py; \
        sed -i "s/else 0/else 0\npassword = os.getenv\(\"REDIS_PW\"\)/g" /usr/local/lib/python3.9/dist-packages/misp_modules/helpers/cache.py; \
        python3 -m compileall /usr/local/lib/python3.9 || :

FROM debian:bullseye-slim
ENV DEBIAN_FRONTEND noninteractive
ARG MODULES_TAG=v2.4.169

RUN apt-get update && apt-get install -y --no-install-recommends \
        curl \
        imagemagick \
        libcaca0 \
        libcjson1 \
        libfuzzy2 \
        libgl1 \
        libglib2.0-0 \
        libjpeg62-turbo \
        liblua5.3-0 \
        libpq5 \
        libpoppler-cpp0v5 \
        libxext6 \
        libxrender1 \
        libzbar0 \
        python3 \
        python3-distutils \
        python3-dnspython \
        tesseract-ocr \
        zbar-tools \
    && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local/ /usr/local/

ENTRYPOINT [ "/usr/local/bin/misp-modules", "-l", "0.0.0.0"]
