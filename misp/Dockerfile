FROM composer:1.9 as composer-build
    ARG MISP_TAG
    WORKDIR /tmp
    ADD https://raw.githubusercontent.com/MISP/MISP/${MISP_TAG}/app/composer.json /tmp
    RUN composer install --ignore-platform-reqs

FROM debian:buster-slim as build
    ENV DEBIAN_FRONTEND noninteractive
    ARG MISP_TAG
    ARG PHP_VER
    ARG PHP_API

    # OS Packages
    RUN apt-get update; apt-get install -y --no-install-recommends \
        cron \
        git \
        gpg gpg-agent \
        libfuzzy2 \
        librdkafka1 \
        mariadb-client-core-10.3 \
        openssl \
        php \
        php-fpm \
        php-gd \
        php-gnupg \
        php-mbstring \
        php-mysql \
        php-redis \
        php-xml \
        php-zip \
        python3 \
        python3-dateutil \
        python3-jsonschema \
        python3-lxml \
        python3-magic \
        python3-ply \
        python3-redis \
        python3-requests \
        python3-simplejson \
        python3-tz \
        python3-wrapt \
        python3-zmq \
        rsync \
        ssdeep \
        sudo \
        unzip zip \
        && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

    # Dev Packages
    RUN apt-get update; apt-get install -y --no-install-recommends \
        ca-certificates \
        gcc \
        libfuzzy-dev \
        librdkafka-dev \
        make \
        php-dev \
        php-pear \
        python3-dev \
        python3-pip \
        python3-setuptools \
        python3-wheel \
        && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

    RUN mkdir /wheels

    WORKDIR /tmp

    # build python-mixbox
    RUN git clone --depth 1 https://github.com/CybOXProject/mixbox.git; \
        cd mixbox || exit; python3 setup.py bdist_wheel -d /wheels

    # build python-maec
    RUN git clone --depth 1 https://github.com/MAECProject/python-maec.git; \
        cd python-maec || exit; python3 setup.py bdist_wheel -d /wheels

    # build python-cybox
    RUN git clone --depth 1 https://github.com/CybOXProject/python-cybox.git; \
        cd python-cybox || exit; python3 setup.py bdist_wheel -d /wheels

    # build python stix
    RUN git clone --depth 1 https://github.com/STIXProject/python-stix.git; \
        cd python-stix || exit; python3 setup.py bdist_wheel -d /wheels

    # build STIX2.0 library to support STIX 2.0 export:
    RUN git clone --depth 1 https://github.com/MISP/cti-python-stix2.git; \
        cd cti-python-stix2 || exit; python3 setup.py bdist_wheel -d /wheels

    # build PyMISP
    RUN git clone --depth 1 https://github.com/MISP/PyMISP.git; \
        cd PyMISP || exit; python3 setup.py bdist_wheel -d /wheels

    # build pydeep
    RUN git clone --depth 1 https://github.com/coolacid/pydeep.git; \
        cd pydeep || exit; python3 setup.py bdist_wheel -d /wheels
    RUN cp /usr/lib/x86_64-linux-gnu/libfuzzy.* /usr/lib && pecl install ssdeep

    # build rdkafka
    RUN cp /usr/lib/x86_64-linux-gnu/librdkafka.* /usr/lib && pecl install rdkafka

    # install Python Modules
    RUN pip3 install --no-cache-dir --upgrade six && \
        pip3 install --no-cache-dir /wheels/*.whl lief plyara

    # Download MISP code
    RUN git clone --branch ${MISP_TAG} --depth 1 https://github.com/MISP/MISP.git /var/www/MISP && \
        cd /var/www/MISP/app && \
        git submodule update --init --recursive . && \
        mv /var/www/MISP/app/Config /var/www/MISP/app/Config.dist && mkdir /var/www/MISP/app/Config

    COPY --from=composer-build /tmp/Vendor /var/www/MISP/app/Vendor
    COPY --from=composer-build /tmp/Plugin /var/www/MISP/app/Plugin

    RUN rm -f /var/www/MISP/app/Plugin/CakeResque/Config/config.php && \
        ln -s /var/www/MISP/app/Config/resque_config.php /var/www/MISP/app/Plugin/CakeResque/Config/config.php

    RUN mkdir /var/www/MISP/app/files/attachments && \
        touch /var/www/MISP/app/files/attachments/empty && \
        mkdir /var/www/MISP/app/tmp/resque && \
        touch /var/www/MISP/app/tmp/resque/empty


FROM debian:buster-slim
    ENV DEBIAN_FRONTEND noninteractive
    ARG MISP_TAG
    ARG PHP_VER
    ARG PHP_API

    # OS Packages
    RUN apt-get update; apt-get install -y --no-install-recommends \
        cron \
        git \
        gpg gpg-agent \
        libfuzzy2 \
        librdkafka1 \
        mariadb-client-core-10.3 \
        openssl \
        php \
        php-fpm \
        php-gd \
        php-gnupg \
        php-mbstring \
        php-mysql \
        php-redis \
        php-xml \
        php-zip \
        python3 \
        python3-dateutil \
        python3-jsonschema \
        python3-lxml \
        python3-magic \
        python3-ply \
        python3-redis \
        python3-requests \
        python3-simplejson \
        python3-tz \
        python3-wrapt \
        python3-zmq \
        rsync \
        ssdeep \
        sudo \
        unzip zip \
        && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

    # PHP-FPM Settings
    RUN sed -i "s/memory_limit = .*/memory_limit = 2048M/" /etc/php/${PHP_VER}/fpm/php.ini && \
        sed -i "s/max_execution_time = .*/max_execution_time = 300/" /etc/php/${PHP_VER}/fpm/php.ini && \
        sed -i "s/upload_max_filesize = .*/upload_max_filesize = 50M/" /etc/php/${PHP_VER}/fpm/php.ini && \
        sed -i "s/post_max_size = .*/post_max_size = 50M/" /etc/php/${PHP_VER}/fpm/php.ini && \
        sed -i "s/\/run\/php\/php.\..-fpm\.sock/9000/" /etc/php/${PHP_VER}/fpm/pool.d/www.conf && \
        sed -i "s/;catch_workers_output/catch_workers_output/" /etc/php/${PHP_VER}/fpm/pool.d/www.conf && \
        sed -i "s/;decorate_workers_output/decorate_workers_output/" /etc/php/${PHP_VER}/fpm/pool.d/www.conf && \
        sed -i "s/;clear_env/clear_env/" /etc/php/${PHP_VER}/fpm/pool.d/www.conf && \
        sed -i "s/;access.log .*$/access.log = \/proc\/self\/fd\/1/" /etc/php/${PHP_VER}/fpm/pool.d/www.conf && \
        sed -i "s/\/var\/log\/php.\..-fpm\.log/\/proc\/self\/fd\/2/" /etc/php/${PHP_VER}/fpm/php-fpm.conf && \
        sed -i "s/run\/php/run/" /etc/php/${PHP_VER}/fpm/php-fpm.conf

    # Python Modules
    COPY --from=build /usr/local/lib/python3.7/dist-packages /usr/local/lib/python3.7/dist-packages

    # PHP Modules
    COPY --from=build /usr/lib/php/${PHP_API}/rdkafka.so /usr/lib/php/${PHP_API}/rdkafka.so
    COPY --from=build /usr/lib/php/${PHP_API}/ssdeep.so /usr/lib/php/${PHP_API}/ssdeep.so
    RUN echo "extension=rdkafka.so" > "/etc/php/${PHP_VER}/mods-available/rdkafka.ini" && \
        echo "extension=ssdeep.so" > "/etc/php/${PHP_VER}/mods-available/ssdeep.ini" && \
        phpenmod gnupg && \
        phpenmod redis && \
        phpenmod rdkafka && \
        phpenmod ssdeep

    # MISP
    COPY --chown=www-data:www-data --from=build /var/www/MISP /var/www/MISP

    # Entrypoints
    COPY files/start.sh /
    COPY files/docker-entrypoint.sh /
    ENTRYPOINT [ "/docker-entrypoint.sh" ]

    # Cron configuration
    RUN rm -f /etc/cron.d/.placeholder /etc/cron.d/*
    COPY files/etc /etc

    # Change Workdirectory
    WORKDIR /var/www/MISP

    VOLUME ["/var/www/MISP/app/Config", "/var/www/MISP/app/files", "/var/www/MISP/app/tmp"]

    EXPOSE 9000

    CMD ["/start.sh"]
