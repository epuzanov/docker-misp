FROM debian:bullseye-slim as build
    ENV DEBIAN_FRONTEND noninteractive
    ARG MISP_TAG=v2.4.187
    ARG PHP_VER=7.4
    ARG PHP_API=20190902
    ARG PATH_TO_MISP=/var/www/MISP
    ENV PATH_TO_MISP=${PATH_TO_MISP}
    ARG WWW_USER=www-data
    ENV WWW_USER=${WWW_USER}

    # OS Packages
    RUN apt-get update; apt-get install -y --no-install-recommends \
        cron \
        git \
        gpg gpg-agent \
        libbrotli1 \
        libfuzzy2 \
        librdkafka1 \
        libsimdjson5 \
        libzstd1 \
        mariadb-client-core-10.5 \
        nginx \
        openssl \
        php \
        php-apcu \
        php-bcmath \
        php-cli \
        php-curl \
        php-fpm \
        php-gd \
        php-gnupg \
        php-intl \
        php-json \
        php-mbstring \
        php-mysql \
        php-readline \
        php-redis \
        php-xml \
        php-zip \
        php${PHP_VER}-opcache \
        python3 \
        python3-antlr4 \
        python3-brotli \
        python3-deprecated \
        python3-jsonschema \
        python3-lxml \
        python3-magic \
        python3-nose \
        python3-ply \
        python3-plyara \
        python3-redis \
        python3-requests-mock \
        python3-simplejson \
        python3-tz \
        python3-wrapt \
        python3-zmq \
        rsync \
        ssdeep \
        sudo \
        supervisor \
        unzip zip \
        && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

    # Dev Packages
    RUN apt-get update; apt-get install -y --no-install-recommends \
        ca-certificates \
        g++ \
        gcc \
        libbrotli-dev \
        libfuzzy-dev \
        librdkafka-dev \
        libsimdjson-dev \
        libzstd-dev \
        make \
        php-dev \
        php-pear \
        python3-dev \
        python3-pip \
        python3-setuptools \
        python3-wheel \
        && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

    ENV CRYPTOGRAPHY_DONT_BUILD_RUST=1

    # build brotli
    RUN git clone --recursive --depth=1 https://github.com/kjdev/php-ext-brotli.git && \
        cd php-ext-brotli && \
        phpize${PHP_VER} && \
        ./configure --with-libbrotli --with-php-config=/usr/bin/php-config${PHP_VER} && \
        make && \
        make install

    # build pydeep
    RUN pip3 install git+https://github.com/kbandla/pydeep.git lief
    RUN cp /usr/lib/x86_64-linux-gnu/libfuzzy.* /usr/lib && pecl install ssdeep

    # build rdkafka
    RUN cp /usr/lib/x86_64-linux-gnu/librdkafka.* /usr/lib && pecl install rdkafka

    # build simdjson
    RUN cp /usr/lib/x86_64-linux-gnu/libsimdjson.* /usr/lib && pecl install simdjson

    # build zstd
    RUN cp /usr/lib/x86_64-linux-gnu/libzstd.* /usr/lib && pecl install zstd

    # Download MISP code
    RUN git clone --depth 1 --branch ${MISP_TAG} https://github.com/MISP/MISP.git ${PATH_TO_MISP} && \
        git -C ${PATH_TO_MISP} submodule update --progress --init --recursive PyMISP && \
        git -C ${PATH_TO_MISP} submodule update --progress --init --recursive app && \
        git -C ${PATH_TO_MISP} submodule foreach --recursive git config core.filemode false && \
        git -C ${PATH_TO_MISP} config core.filemode false && \
        git -C ${PATH_TO_MISP} reflog expire --expire=now --all && \
        git -C ${PATH_TO_MISP} gc --prune=now --aggressive && \
        git config --global --add safe.directory ${PATH_TO_MISP} && \
        install -d -o ${WWW_USER} -g ${WWW_USER} -m 0755 /var/www/.composer && \
        chown -R ${WWW_USER}:${WWW_USER} ${PATH_TO_MISP}

    # Build and install Python modules
    RUN pip3 install ${PATH_TO_MISP}/PyMISP && \
        cd ${PATH_TO_MISP}/app/files/scripts && \
        for dir_name in mixbox python-cybox python-maec python-stix cti-python-stix2 ; do cd $dir_name && python3 setup.py bdist_wheel && pip3 install dist/* && cd .. && rm -rf $dir_name && git submodule deinit --force $dir_name && git rm $dir_name ; done && \
        cd misp-stix && python3 setup.py bdist_wheel && pip3 install dist/* && cp -r misp_stix_converter /usr/local/lib/python3.9/dist-packages && cd .. && rm -rf misp-stix && git submodule deinit --force misp-stix && git rm misp-stix && \
        cd ${PATH_TO_MISP} && \
        for dir_name in PyMISP app/Lib/cakephp app/files/scripts/misp-opendata ; do mv $dir_name $dir_name\_tmp && git submodule deinit --force $dir_name && git rm $dir_name && mv $dir_name\_tmp $dir_name ; done && \
        for dir_name in misp-decaying-models misp-galaxy misp-objects misp-workflow-blueprints noticelists taxonomies warninglists ; do rm -rf ${PATH_TO_MISP}/app/files/$dir_name ${PATH_TO_MISP}/.git/modules/app/files/$dir_name && mkdir ${PATH_TO_MISP}/app/files/$dir_name && ln -s ../../../../app/files/$dir_name/.git ${PATH_TO_MISP}/.git/modules/app/files/$dir_name ; done && \
        rm -rf ${PATH_TO_MISP}/.git/modules/cti-python-stix2 ${PATH_TO_MISP}/.git/modules/PyMISP ${PATH_TO_MISP}/.git/modules/app/Lib ${PATH_TO_MISP}/.git/modules/app/files/scripts ${PATH_TO_MISP}/PyMISP/pymisp /usr/local/lib/python3.9/dist-packages/pymisp/data/misp-objects && \
        ln -s ${PATH_TO_MISP}/app/files/misp-objects /usr/local/lib/python3.9/dist-packages/pymisp/data/misp-objects && \
        ln -s /usr/local/lib/python3.9/dist-packages/pymisp ${PATH_TO_MISP}/PyMISP/pymisp

    # Move files/scripts to the app
    RUN grep -rl "files/scripts" ${PATH_TO_MISP}/app | xargs -i@ sed -i "s/files\/scripts/scripts/g" @ && \
        grep -rl "files.\s*\.\s*DS\s*\.\s*.scripts" ${PATH_TO_MISP}/app | xargs -i@ sed -i "s/files.\s*\.\s*DS\s*\.\s*.scripts/scripts/" @ && \
        sed -i "s/-3/-2/" ${PATH_TO_MISP}/app/files/scripts/stix2misp.py && \
        cd ${PATH_TO_MISP}/app/files && \
        mv ${PATH_TO_MISP}/app/files/scripts ${PATH_TO_MISP}/app && \
        git submodule deinit --force scripts && \
        git rm -r scripts && \
        rm -rf ${PATH_TO_MISP}/app/scripts/tmp && \
        ln -s ${PATH_TO_MISP}/app/tmp/scripts ${PATH_TO_MISP}/app/scripts/tmp

    USER ${WWW_USER}

    # Install composer plugins and vendors
    RUN cd ${PATH_TO_MISP}/app && \
        php composer.phar install && \
        php composer.phar require --with-all-dependencies elasticsearch/elasticsearch \
            aws/aws-sdk-php \
            jakub-onderka/openid-connect-php \
            supervisorphp/supervisor \
            guzzlehttp/guzzle \
            php-http/message \
            php-http/message-factory \
            lstrojny/fxmlrpc

    RUN cd ${PATH_TO_MISP} && \
        mkdir save && \
        mv app/Config save/Config && \
        mv app/files save/files && \
        mkdir -p app/Config app/files && \
        rm -rf app/webroot/files app/webroot/img/custom app/Plugin/CakeResque/Config/config.php app/tmp/* && \
        ln -s ${PATH_TO_MISP}/app/Config/resque_config.php ${PATH_TO_MISP}/app/Plugin/CakeResque/Config/config.php && \
        ln -s ${PATH_TO_MISP}/app/files/webroot/files ${PATH_TO_MISP}/app/webroot/files && \
        ln -s ${PATH_TO_MISP}/app/files/webroot/img/custom ${PATH_TO_MISP}/app/webroot/img/custom && \
        ln -s ${PATH_TO_MISP}/app/files/webroot/gpg.asc ${PATH_TO_MISP}/app/webroot/gpg.asc

    RUN cd ${PATH_TO_MISP}/app && \
        chmod 0755 composer.phar && \
        ./composer.phar update

FROM debian:bullseye-slim
    ENV DEBIAN_FRONTEND noninteractive
    ARG MISP_TAG=v2.4.187
    ARG PHP_VER=7.4
    ARG PHP_API=20190902
    ARG PATH_TO_MISP=/var/www/MISP
    ENV PATH_TO_MISP=${PATH_TO_MISP}
    ARG WWW_USER=www-data
    ENV WWW_USER=${WWW_USER}

    # OS Packages
    RUN apt-get update; apt-get install -y --no-install-recommends \
        cron \
        git \
        gpg gpg-agent \
        libbrotli1 \
        libfuzzy2 \
        librdkafka1 \
        libsimdjson5 \
        libzstd1 \
        mariadb-client-core-10.5 \
        nginx \
        openssl \
        php \
        php-apcu \
        php-bcmath \
        php-cli \
        php-curl \
        php-fpm \
        php-gd \
        php-gnupg \
        php-intl \
        php-json \
        php-mbstring \
        php-mysql \
        php-readline \
        php-redis \
        php-xml \
        php-zip \
        php${PHP_VER}-opcache \
        python3 \
        python3-antlr4 \
        python3-brotli \
        python3-deprecated \
        python3-jsonschema \
        python3-lxml \
        python3-magic \
        python3-nose \
        python3-ply \
        python3-plyara \
        python3-redis \
        python3-requests-mock \
        python3-simplejson \
        python3-tz \
        python3-wrapt \
        python3-zmq \
        rsync \
        ssdeep \
        sudo \
        supervisor \
        unzip zip \
        && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

    # PHP-FPM Settings
    RUN sed -i "s/memory_limit = .*/memory_limit = 2048M/" /etc/php/${PHP_VER}/fpm/php.ini && \
        sed -i "s/max_execution_time = .*/max_execution_time = 300/" /etc/php/${PHP_VER}/fpm/php.ini && \
        sed -i "s/upload_max_filesize = .*/upload_max_filesize = 50M/" /etc/php/${PHP_VER}/fpm/php.ini && \
        sed -i "s/post_max_size = .*/post_max_size = 50M/" /etc/php/${PHP_VER}/fpm/php.ini && \
        sed -i "s/session.sid_length = .*/session.sid_length = 32/" /etc/php/${PHP_VER}/fpm/php.ini && \
        sed -i "s/session.use_strict_mode = .*/session.use_strict_mode = 1/" /etc/php/${PHP_VER}/fpm/php.ini && \
        sed -i "s/\/run\/php\/php.\..-fpm\.sock/9000/" /etc/php/${PHP_VER}/fpm/pool.d/www.conf && \
        sed -i "s/;catch_workers_output/catch_workers_output/" /etc/php/${PHP_VER}/fpm/pool.d/www.conf && \
        sed -i "s/;decorate_workers_output/decorate_workers_output/" /etc/php/${PHP_VER}/fpm/pool.d/www.conf && \
        sed -i "s/;clear_env/clear_env/" /etc/php/${PHP_VER}/fpm/pool.d/www.conf && \
        sed -i "s/;access.log .*$/access.log = \/proc\/self\/fd\/1/" /etc/php/${PHP_VER}/fpm/pool.d/www.conf && \
        sed -i "s/www-data/${WWW_USER}/" /etc/php/${PHP_VER}/fpm/pool.d/www.conf && \
        sed -i "s/\/var\/log\/php.\..-fpm\.log/\/proc\/self\/fd\/2/" /etc/php/${PHP_VER}/fpm/php-fpm.conf && \
        sed -i "s/run\/php/run/" /etc/php/${PHP_VER}/fpm/php-fpm.conf && \
        sed -i "s/user nginx/user ${WWW_USER}/" /etc/nginx/nginx.conf

    # Python Modules
    COPY --from=build /usr/local/lib/python3.9/dist-packages /usr/local/lib/python3.9/dist-packages

    # PHP Modules
    COPY --from=build /usr/lib/php/${PHP_API}/brotli.so /usr/lib/php/${PHP_API}/brotli.so
    COPY --from=build /usr/lib/php/${PHP_API}/rdkafka.so /usr/lib/php/${PHP_API}/rdkafka.so
    COPY --from=build /usr/lib/php/${PHP_API}/simdjson.so /usr/lib/php/${PHP_API}/simdjson.so
    COPY --from=build /usr/lib/php/${PHP_API}/ssdeep.so /usr/lib/php/${PHP_API}/ssdeep.so
    COPY --from=build /usr/lib/php/${PHP_API}/zstd.so /usr/lib/php/${PHP_API}/zstd.so
    RUN echo "apc.enable_cli=1" >> "/etc/php/${PHP_VER}/mods-available/apcu.ini" && \
        echo "extension=rdkafka.so" > "/etc/php/${PHP_VER}/mods-available/rdkafka.ini" && \
        echo "extension=simdjson.so" > "/etc/php/${PHP_VER}/mods-available/simdjson.ini" && \
        echo "extension=ssdeep.so" > "/etc/php/${PHP_VER}/mods-available/ssdeep.ini" && \
        echo "extension=brotli.so" > "/etc/php/${PHP_VER}/mods-available/brotli.ini" && \
        echo "extension=zstd.so" > "/etc/php/${PHP_VER}/mods-available/zstd.ini" && \
        phpenmod gnupg && \
        phpenmod redis && \
        phpenmod brotli && \
        phpenmod rdkafka && \
        phpenmod simdjson && \
        phpenmod ssdeep && \
        phpenmod zstd

    # Copy MISP Files
    COPY --chown=${WWW_USER}:${WWW_USER} --from=build ${PATH_TO_MISP} ${PATH_TO_MISP}

    # Prepare directories and files
    RUN rm -rf /etc/cron.d/.placeholder /etc/cron.d/* /var/log/nginx && \
        ln -s ${PATH_TO_MISP}/app/Config/.gnupg /var/www/.gnupg && \
        ln -s ${PATH_TO_MISP}/app/tmp/logs /var/log/nginx && \
        sed -i "s#/var/log/nginx/#${PATH_TO_MISP}/app/tmp/logs/nginx-#g" /etc/nginx/nginx.conf && \
        mkdir -p /var/lib/nginx/body /var/lib/nginx/fastcgi /var/lib/nginx/proxy /var/lib/nginx/scgi /var/lib/nginx/uwsgi && \
        chown -R ${WWW_USER}:root /var/lib/nginx && \
        chmod 777 /run && \
        chmod 777 /var/spool/cron && \
        chmod u+s /usr/sbin/cron && \
        chmod u+s /usr/sbin/php-fpm${PHP_VER}

    # Copy files
    COPY files/ /

    # Update supervisor configs
    RUN grep -rl "/var/www/MISP" /etc | xargs -i@ sed -i "s#/var/www/MISP#${PATH_TO_MISP}#g" @ && \
        grep -rl "www-data" /etc/supervisor | xargs -i@ sed -i "s#www-data#${WWW_USER}#g" @

    # Change Work directory
    WORKDIR ${PATH_TO_MISP}

    ENTRYPOINT [ "/docker-entrypoint.sh" ]

    CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/supervisord.conf"]
