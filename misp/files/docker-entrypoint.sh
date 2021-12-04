#!/bin/bash

PATH_TO_MISP=/var/www/MISP
PATH_TO_MISP_CONFIG=$PATH_TO_MISP/app/Config
CAKE=$PATH_TO_MISP/app/Console/cake

[ -z "$GPG_REAL_NAME" ] && GPG_REAL_NAME="Autogenerated Key"
[ -z "$GPG_COMMENT" ] && GPG_COMMENT="WARNING: MISP AutoGenerated Key consider this Key VOID!"
[ -z "$GPG_EMAIL_ADDRESS" ] && GPG_EMAIL_ADDRESS="admin@admin.test"
[ -z "$GPG_KEY_LENGTH" ] && GPG_KEY_LENGTH="3072"
[ -z "$GPG_PASSPHRASE" ] && GPG_PASSPHRASE="$(openssl rand -hex 32)"
[ -z "$REDIS_FQDN" ] && REDIS_FQDN=redis
[ -z "$REDIS_PASSWORD" ] && REDIS_PASSWORD=
[ -z "$MYSQL_HOST" ] && MYSQL_HOST=db
[ -z "$MYSQL_PORT" ] && MYSQL_PORT=3306
[ -z "$MYSQL_USER" ] && MYSQL_USER=misp
[ -z "$MYSQL_PASSWORD" ] && MYSQL_PASSWORD=example
[ -z "$MYSQL_DATABASE" ] && MYSQL_DATABASE=misp
[ -z "$MYSQLCMD" ] && MYSQLCMD="mysql -u $MYSQL_USER -p$MYSQL_PASSWORD -P $MYSQL_PORT -h $MYSQL_HOST -r -N  $MYSQL_DATABASE"

init_misp_config(){
    if [ ! -f $PATH_TO_MISP_CONFIG/routes.php ]
    then
        cp $PATH_TO_MISP_CONFIG.dist/routes.php $PATH_TO_MISP_CONFIG/routes.php
    fi
    if [ ! -f $PATH_TO_MISP_CONFIG/bootstrap.php ]
    then
        cp $PATH_TO_MISP_CONFIG.dist/bootstrap.default.php $PATH_TO_MISP_CONFIG/bootstrap.php
    fi
    if [ ! -f $PATH_TO_MISP_CONFIG/core.php ]
    then
        cp $PATH_TO_MISP_CONFIG.dist/core.default.php $PATH_TO_MISP_CONFIG/core.php
        sed -i "s/'php',/'cake',/" $PATH_TO_MISP_CONFIG/core.php
    fi
    if [ ! -f $PATH_TO_MISP_CONFIG/resque_config.php ]
    then
        cp $PATH_TO_MISP/INSTALL/setup/config.php $PATH_TO_MISP_CONFIG/resque_config.php
        sed -i "s/'127.0.0.1'/'$REDIS_FQDN'/" $PATH_TO_MISP_CONFIG/resque_config.php
        sed -i "s/App::pluginPath('CakeResque') . 'tmp'/TMP . 'resque'/" $PATH_TO_MISP_CONFIG/resque_config.php
        if [ ! -z "$REDIS_PASSWORD" ]
        then
            sed -i "s/'password' => null/'password' => '$REDIS_PASSWORD'/" $PATH_TO_MISP_CONFIG/resque_config.php
        fi
    fi
    if [ ! -f $PATH_TO_MISP_CONFIG/database.php ]
    then
        echo "Configure MISP | Set DB User, Password and Host in database.php"
        cp $PATH_TO_MISP_CONFIG.dist/database.default.php $PATH_TO_MISP_CONFIG/database.php
        sed -i "s/localhost/$MYSQL_HOST/" $PATH_TO_MISP_CONFIG/database.php
        sed -i "s/db\s*login/$MYSQL_USER/" $PATH_TO_MISP_CONFIG/database.php
        sed -i "s/db\s*password/$MYSQL_PASSWORD/" $PATH_TO_MISP_CONFIG/database.php
        sed -i "s/'database' => 'misp'/'database' => '$MYSQL_DATABASE'/" $PATH_TO_MISP_CONFIG/database.php
    fi
    if [ ! -f $PATH_TO_MISP_CONFIG/email.php ]
    then
        cp $PATH_TO_MISP_CONFIG.dist/email.php $PATH_TO_MISP_CONFIG/email.php
        sed -i -E "/\s+public .smtp = array./,/\s+public .fast = array./{;/\s+public .fast = array./!{;H;b;};x;p;x;}" $PATH_TO_MISP_CONFIG/email.php
        sed -i -E "/\s+'transport'\s+=>\s+'Mail'/,/\s+public .smtp = array./d" $PATH_TO_MISP_CONFIG/email.php
        sed -i "s/'localhost'/'mail'/" $PATH_TO_MISP_CONFIG/email.php
        sed -i "s/'username'/\/\/'username'/" $PATH_TO_MISP_CONFIG/email.php
        sed -i "s/'password'/\/\/'password'/" $PATH_TO_MISP_CONFIG/email.php
        sed -i "s/'\(site\|you\)@localhost'/'misp-dev@admin.test'/" $PATH_TO_MISP_CONFIG/email.php
        sed -i "s/'My Site'/'Misp DEV'/" $PATH_TO_MISP_CONFIG/email.php
    fi
    if [ ! -f $PATH_TO_MISP_CONFIG/config.php ]
    then
        echo "Configure MISP | Set defaults in config.php"
        cp $PATH_TO_MISP_CONFIG.dist/config.default.php $PATH_TO_MISP_CONFIG/config.php
        $CAKE Admin setSetting "MISP.redis_host" "$REDIS_FQDN"
        $CAKE Admin setSetting "MISP.redis_password" "$REDIS_PASSWORD"
        $CAKE Admin setSetting "MISP.baseurl" "$HOSTNAME"
        $CAKE Admin setSetting "MISP.python_bin" $(which python3)
        $CAKE Admin setSetting "MISP.tmpdir" "$PATH_TO_MISP/app/tmp"
        $CAKE Admin setSetting "MISP.attachments_dir" "$PATH_TO_MISP/app/files/attachments"
        $CAKE Admin setSetting "MISP.attachment_scan_module" "clamav"
        $CAKE Admin setSetting "MISP.live" true

        $CAKE Admin setSetting "GnuPG.email" "${GPG_EMAIL_ADDRESS}"
        $CAKE Admin setSetting "GnuPG.homedir" "${PATH_TO_MISP_CONFIG}/.gnupg"
        $CAKE Admin setSetting "GnuPG.password" "${GPG_PASSPHRASE}"
        $CAKE Admin setSetting "GnuPG.obscure_subject" true
        $CAKE Admin setSetting "GnuPG.binary" "$(which gpg)"

        $CAKE Admin setSetting "SimpleBackgroundJobs.redis_host" "$REDIS_FQDN"
        $CAKE Admin setSetting "SimpleBackgroundJobs.redis_password" "$REDIS_PASSWORD"

        $CAKE Admin setSetting "Plugin.ZeroMQ_redis_host" "$REDIS_FQDN"
        $CAKE Admin setSetting "Plugin.ZeroMQ_redis_password" "$REDIS_PASSWORD"
        $CAKE Admin setSetting "Plugin.ZeroMQ_enable" true

        $CAKE Admin setSetting "Plugin.Enrichment_services_enable" true
        $CAKE Admin setSetting "Plugin.Enrichment_services_url" "http://misp-modules"
        $CAKE Admin setSetting "Plugin.Enrichment_clamav_enabled" true
        $CAKE Admin setSetting "Plugin.Enrichment_clamav_connection" "clamav:3310"

        $CAKE Admin setSetting "Plugin.Import_services_enable" true
        $CAKE Admin setSetting "Plugin.Import_services_url" "http://misp-modules"

        $CAKE Admin setSetting "Plugin.Export_services_enable" true
        $CAKE Admin setSetting "Plugin.Export_services_url" "http://misp-modules"

        $CAKE Admin setSetting "Plugin.Cortex_services_enable" false

        chmod 640 $PATH_TO_MISP_CONFIG/*
    fi
}

init_mysql(){
    # Test when MySQL is ready....
    # wait for Database come ready
    isDBup () {
        echo "SHOW STATUS" | $MYSQLCMD 1>/dev/null
        echo $?
    }

    isDBinitDone () {
        # Table attributes has existed since at least v2.1
        echo "DESCRIBE attributes" | $MYSQLCMD 1>/dev/null
        echo $?
    }

    RETRY=100
    until [ $(isDBup) -eq 0 ] || [ $RETRY -le 0 ]
    do
        echo "Waiting for database to come up"
        sleep 5
        RETRY=$(( RETRY - 1))
    done
    if [ $RETRY -le 0 ]
    then
        >&2 echo "Error: Could not connect to Database on $MYSQL_HOST:$MYSQL_PORT"
        exit 1
    fi

    if [ $(isDBinitDone) -eq 0 ]
    then
        echo "Database has already been initialized"
    else
        echo "Database has not been initialized, importing MySQL scheme..."
        $MYSQLCMD < $PATH_TO_MISP/INSTALL/MYSQL.sql
    fi
}

init_misp_persistent_storage(){
    for dir_name in cache/feeds cache/ingest cache/models cache/persistent cache/views cached_exports/rpz files logs resque sessions yara
    do
        if [ ! -d $PATH_TO_MISP/app/tmp/$dir_name ]
        then
            mkdir -p $PATH_TO_MISP/app/tmp/$dir_name
        fi
    done

    mkdir -p $PATH_TO_MISP/app/files/attachments $PATH_TO_MISP/app/files/scripts $PATH_TO_MISP/app/files/terms
    [ ! -d $PATH_TO_MISP/app/files/community-metadata ] && cp -r $PATH_TO_MISP/app/files.dist/community-metadata $PATH_TO_MISP/app/files/community-metadata
    [ ! -d $PATH_TO_MISP/app/files/feed-metadata ] && cp -r $PATH_TO_MISP/app/files.dist/feed-metadata $PATH_TO_MISP/app/files/feed-metadata
    [ ! -d $PATH_TO_MISP/app/files/misp-decaying-models ] && git clone --depth 1 https://github.com/MISP/misp-decaying-models.git $PATH_TO_MISP/app/files/misp-decaying-models
    [ ! -d $PATH_TO_MISP/app/files/misp-galaxy ] && git clone --depth 1 https://github.com/MISP/misp-galaxy.git $PATH_TO_MISP/app/files/misp-galaxy
    [ ! -d $PATH_TO_MISP/app/files/misp-objects ] && git clone --depth 1 https://github.com/MISP/misp-objects.git $PATH_TO_MISP/app/files/misp-objects
    [ ! -d $PATH_TO_MISP/app/files/noticelists ] && git clone --depth 1 https://github.com/MISP/misp-noticelist.git $PATH_TO_MISP/app/files/noticelists
    [ ! -d $PATH_TO_MISP/app/files/taxonomies ] && git clone --depth 1 https://github.com/MISP/misp-taxonomies.git $PATH_TO_MISP/app/files/taxonomies
    [ ! -d $PATH_TO_MISP/app/files/warninglists ] && git clone --depth 1 https://github.com/MISP/misp-warninglists.git $PATH_TO_MISP/app/files/warninglists
    cd $PATH_TO_MISP
    git submodule update --recursive

}

update_GOWNT() {
    $CAKE Admin updateGalaxies
    $CAKE Admin updateTaxonomies
    $CAKE Admin updateWarningLists
    $CAKE Admin updateNoticeLists
    $CAKE Admin updateObjectTemplates "1"
}

sync_persistent_directories(){
    if [ ! -d $PATH_TO_MISP/app/webroot/img ]
    then
        cp -r $PATH_TO_MISP/app/webroot.dist/* $PATH_TO_MISP/app/webroot
    fi
    rsync -a --delete $PATH_TO_MISP/app/files.dist/scripts/ $PATH_TO_MISP/app/files/scripts
    rsync -a --delete --exclude=/files --exclude=/img/orgs --exclude=/img/custom --exclude=/gpg.asc $PATH_TO_MISP/app/webroot.dist/ $PATH_TO_MISP/app/webroot
}

setup_gnupg() {
    echo "%echo Generating a default key
    Key-Type: default
    Key-Length: $GPG_KEY_LENGTH
    Subkey-Type: default
    Name-Real: $GPG_REAL_NAME
    Name-Comment: $GPG_COMMENT
    Name-Email: $GPG_EMAIL_ADDRESS
    Expire-Date: 0
    Passphrase: $GPG_PASSPHRASE
    %commit
    %echo done" > /tmp/gen-key-script

    gpg --homedir $PATH_TO_MISP_CONFIG/.gnupg --batch --gen-key /tmp/gen-key-script
    rm -rf /tmp/gen-key-script

    if [ ! -f $PATH_TO_MISP/app/webroot/gpg.asc ]
    then
        gpg --homedir $PATH_TO_MISP_CONFIG/.gnupg --export --armor $GPG_EMAIL_ADDRESS > $PATH_TO_MISP/app/webroot/gpg.asc
    fi
}

if [ "$FPM" != false ]
then
    if [ ! -f $PATH_TO_MISP_CONFIG/config.php ]
    then
        echo "Setup MySQL..." && init_mysql
        if [ ! -d $PATH_TO_MISP/app/files/attachments ]
        then
            echo "Configure MISP | Initialize misp persistent storage..." && init_misp_persistent_storage
        fi
        echo "Configure MISP | Initialize misp base config..." && init_misp_config
        echo "Configure MISP | Updating Galaxies, ObjectTemplates, Warninglists, Noticelists and Templates..." && update_GOWNT
    fi
    echo "Configure MISP | Sync webroot and files/scripts directories..." && sync_persistent_directories
    if [ ! -d $PATH_TO_MISP_CONFIG/.gnupg ]
    then
        echo "Configure MISP | Generate GnuPG key..." && setup_gnupg
    fi
fi

if [ "$CRON" != false ] && [ ! -d /var/spool/cron/crontabs ]
then
    mkdir -p /var/spool/cron/crontabs
    chmod u=rwx,g=wx,o=t /var/spool/cron/crontabs
fi

exec "$@"
