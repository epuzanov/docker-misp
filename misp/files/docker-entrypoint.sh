#!/bin/bash

MISP_APP_CONFIG_PATH=/var/www/MISP/app/Config
[ -z "$MYSQL_HOST" ] && MYSQL_HOST=db
[ -z "$MYSQL_PORT" ] && MYSQL_PORT=3306
[ -z "$MYSQL_USER" ] && MYSQL_USER=misp
[ -z "$MYSQL_PASSWORD" ] && MYSQL_PASSWORD=example
[ -z "$MYSQL_DATABASE" ] && MYSQL_DATABASE=misp
[ -z "$REDIS_FQDN" ] && REDIS_FQDN=redis
[ -z "$MYSQLCMD" ] && MYSQLCMD="mysql -u $MYSQL_USER -p$MYSQL_PASSWORD -P $MYSQL_PORT -h $MYSQL_HOST -r -N  $MYSQL_DATABASE"

init_misp_config(){
    if [ ! -f $MISP_APP_CONFIG_PATH/routes.php ]
    then
        install -g www-data -o www-data $MISP_APP_CONFIG_PATH.dist/routes.php $MISP_APP_CONFIG_PATH/routes.php
    fi
    if [ ! -f $MISP_APP_CONFIG_PATH/bootstrap.php ]
    then
        install -g www-data -o www-data  $MISP_APP_CONFIG_PATH.dist/bootstrap.default.php $MISP_APP_CONFIG_PATH/bootstrap.php
    fi
    if [ ! -f $MISP_APP_CONFIG_PATH/core.php ]
    then
        install -g www-data -o www-data  $MISP_APP_CONFIG_PATH.dist/core.default.php $MISP_APP_CONFIG_PATH/core.php
        sed -i "s/'php',/'cake',/" $MISP_APP_CONFIG_PATH/core.php
    fi
    if [ ! -f $MISP_APP_CONFIG_PATH/resque_config.php ]
    then
        install -g www-data -o www-data  /var/www/MISP/INSTALL/setup/config.php $MISP_APP_CONFIG_PATH/resque_config.php
        sed -i "s/'127.0.0.1'/'$REDIS_FQDN'/" $MISP_APP_CONFIG_PATH/resque_config.php
        sed -i "s/App::pluginPath('CakeResque') . 'tmp'/TMP . 'resque'/" $MISP_APP_CONFIG_PATH/resque_config.php
    fi
    if [ ! -f $MISP_APP_CONFIG_PATH/database.php ]
    then
        echo "Configure MISP | Set DB User, Password and Host in database.php"
        install -g www-data -o www-data  $MISP_APP_CONFIG_PATH.dist/database.default.php $MISP_APP_CONFIG_PATH/database.php
        sed -i "s/localhost/$MYSQL_HOST/" $MISP_APP_CONFIG_PATH/database.php
        sed -i "s/db\s*login/$MYSQL_USER/" $MISP_APP_CONFIG_PATH/database.php
        sed -i "s/db\s*password/$MYSQL_PASSWORD/" $MISP_APP_CONFIG_PATH/database.php
        sed -i "s/'database' => 'misp'/'database' => '$MYSQL_DATABASE'/" $MISP_APP_CONFIG_PATH/database.php
    fi
    if [ ! -f $MISP_APP_CONFIG_PATH/email.php ]
    then
        install -g www-data -o www-data  $MISP_APP_CONFIG_PATH.dist/email.php $MISP_APP_CONFIG_PATH/email.php
        sed -i -E "/\s+public .smtp = array./,/\s+public .fast = array./{;/\s+public .fast = array./!{;H;b;};x;p;x;}" $MISP_APP_CONFIG_PATH/email.php
        sed -i -E "/\s+'transport'\s+=>\s+'Mail'/,/\s+public .smtp = array./d" $MISP_APP_CONFIG_PATH/email.php
        sed -i "s/'localhost'/'mail'/" $MISP_APP_CONFIG_PATH/email.php
        sed -i "s/'username'/\/\/'username'/" $MISP_APP_CONFIG_PATH/email.php
        sed -i "s/'password'/\/\/'password'/" $MISP_APP_CONFIG_PATH/email.php
        sed -i "s/'\(site\|you\)@localhost'/'misp-dev@admin.test'/" $MISP_APP_CONFIG_PATH/email.php
        sed -i "s/'My Site'/'Misp DEV'/" $MISP_APP_CONFIG_PATH/email.php
    fi
    if [ ! -f $MISP_APP_CONFIG_PATH/config.php ]
    then
        echo "Configure MISP | Set defaults in config.php"
        install -g www-data -o www-data $MISP_APP_CONFIG_PATH.dist/config.default.php $MISP_APP_CONFIG_PATH/config.php
        sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting "MISP.redis_host" "$REDIS_FQDN"
        sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting "MISP.baseurl" "$HOSTNAME"
        sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting "MISP.python_bin" $(which python3)
        sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting "MISP.tmpdir" "/var/www/MISP/app/tmp"
        sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting "MISP.attachments_dir" "/var/www/MISP/app/files/attachments"
        sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting "MISP.live" true

        sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting "Plugin.ZeroMQ_redis_host" "$REDIS_FQDN"
        sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting "Plugin.ZeroMQ_enable" true

        sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting "Plugin.Enrichment_services_enable" true
        sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting "Plugin.Enrichment_services_url" "http://misp-modules"

        sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting "Plugin.Import_services_enable" true
        sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting "Plugin.Import_services_url" "http://misp-modules"

        sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting "Plugin.Export_services_enable" true
        sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting "Plugin.Export_services_url" "http://misp-modules"

        sudo -u www-data /var/www/MISP/app/Console/cake Admin setSetting "Plugin.Cortex_services_enable" false
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
        $MYSQLCMD < /var/www/MISP/INSTALL/MYSQL.sql
    fi
}


if [[ "$INIT" == true ]]
then
    echo "Setup MySQL..." && init_mysql
    echo "Configure MISP | Initialize misp base config..." && init_misp_config
fi

exec "$@"
