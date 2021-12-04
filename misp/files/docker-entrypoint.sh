#!/bin/bash

PATH_TO_MISP=/var/www/MISP
PATH_TO_MISP_CONFIG=${PATH_TO_MISP}/app/Config
CAKE=${PATH_TO_MISP}/app/Console/cake

[ -z "${GPG_REAL_NAME}" ] && GPG_REAL_NAME="Autogenerated Key"
[ -z "${GPG_COMMENT}" ] && GPG_COMMENT="WARNING: MISP AutoGenerated Key consider this Key VOID!"
[ -z "${GPG_EMAIL_ADDRESS}" ] && GPG_EMAIL_ADDRESS="admin@admin.test"
[ -z "${GPG_KEY_LENGTH}" ] && GPG_KEY_LENGTH="3072"
[ -z "${GPG_PASSPHRASE}" ] && GPG_PASSPHRASE="$(openssl rand -hex 32)"
[ -z "${GPG_BINARY}" ] && GPG_BINARY=$(which gpg)
[ -z "${REDIS_FQDN}" ] && REDIS_FQDN=redis
[ -z "${MYSQL_HOST}" ] && MYSQL_HOST=db
[ -z "${MYSQL_PORT}" ] && MYSQL_PORT=3306
[ -z "${MYSQL_USER}" ] && MYSQL_USER=misp
[ -z "${MYSQL_PASSWORD}" ] && MYSQL_PASSWORD=example
[ -z "${MYSQL_DATABASE}" ] && MYSQL_DATABASE=misp
[ -z "${MYSQLCMD}" ] && MYSQLCMD="mysql -u ${MYSQL_USER} -p${MYSQL_PASSWORD} -P ${MYSQL_PORT} -h ${MYSQL_HOST} -r -N ${MYSQL_DATABASE}"

init_misp_config() {
    if [ ! -f ${PATH_TO_MISP_CONFIG}/routes.php ]
    then
        cp ${PATH_TO_MISP}/save/Config/routes.php ${PATH_TO_MISP_CONFIG}/routes.php
    fi
    if [ ! -f ${PATH_TO_MISP_CONFIG}/bootstrap.php ]
    then
        cp ${PATH_TO_MISP}/save/Config/bootstrap.default.php ${PATH_TO_MISP_CONFIG}/bootstrap.php
    fi
    if [ ! -f ${PATH_TO_MISP_CONFIG}/core.php ]
    then
        cp ${PATH_TO_MISP}/save/Config/core.default.php ${PATH_TO_MISP_CONFIG}/core.php
        sed -i "s/'php',/'cake',/" ${PATH_TO_MISP_CONFIG}/core.php
    fi
    if [ ! -f ${PATH_TO_MISP_CONFIG}/resque_config.php ]
    then
        cp ${PATH_TO_MISP}/INSTALL/setup/config.php ${PATH_TO_MISP_CONFIG}/resque_config.php
        sed -i "s/'127.0.0.1'/'${REDIS_FQDN}'/" ${PATH_TO_MISP_CONFIG}/resque_config.php
        sed -i "s/App::pluginPath('CakeResque') . 'tmp'/TMP . 'resque'/" ${PATH_TO_MISP_CONFIG}/resque_config.php
        if [ ! -z "${REDIS_PASSWORD}" ]
        then
            sed -i "s/'password' => null/'password' => '${REDIS_PASSWORD}'/" ${PATH_TO_MISP_CONFIG}/resque_config.php
        fi
    fi
    if [ ! -f ${PATH_TO_MISP_CONFIG}/database.php ]
    then
        echo "Configure MISP | Set DB User, Password and Host in database.php"
        cp ${PATH_TO_MISP}/save/Config/database.default.php ${PATH_TO_MISP_CONFIG}/database.php
        sed -i "s/localhost/${MYSQL_HOST}/" ${PATH_TO_MISP_CONFIG}/database.php
        sed -i "s/db\s*login/${MYSQL_USER}/" ${PATH_TO_MISP_CONFIG}/database.php
        sed -i "s/db\s*password/${MYSQL_PASSWORD}/" ${PATH_TO_MISP_CONFIG}/database.php
        sed -i "s/'database' => 'misp'/'database' => '${MYSQL_DATABASE}'/" ${PATH_TO_MISP_CONFIG}/database.php
    fi
    if [ ! -f ${PATH_TO_MISP_CONFIG}/email.php ]
    then
        cp ${PATH_TO_MISP}/save/Config/email.php ${PATH_TO_MISP_CONFIG}/email.php
        sed -i -E "/\s+public .smtp = array./,/\s+public .fast = array./{;/\s+public .fast = array./!{;H;b;};x;p;x;}" ${PATH_TO_MISP_CONFIG}/email.php
        sed -i -E "/\s+'transport'\s+=>\s+'Mail'/,/\s+public .smtp = array./d" ${PATH_TO_MISP_CONFIG}/email.php
        sed -i "s/'localhost'/'mail'/" ${PATH_TO_MISP_CONFIG}/email.php
        sed -i "s/'username'/\/\/'username'/" ${PATH_TO_MISP_CONFIG}/email.php
        sed -i "s/'password'/\/\/'password'/" ${PATH_TO_MISP_CONFIG}/email.php
        sed -i "s/'\(site\|you\)@localhost'/'misp-dev@admin.test'/" ${PATH_TO_MISP_CONFIG}/email.php
        sed -i "s/'My Site'/'Misp DEV'/" ${PATH_TO_MISP_CONFIG}/email.php
    fi
    if [ ! -f ${PATH_TO_MISP_CONFIG}/config.php ]
    then
        cp ${PATH_TO_MISP}/save/Config/config.default.php ${PATH_TO_MISP_CONFIG}/config.php
        chmod 640 ${PATH_TO_MISP_CONFIG}/*
    fi
}

init_mysql() {
    # Test when MySQL is ready....
    # wait for Database come ready
    isDBup () {
        echo "SHOW STATUS" | ${MYSQLCMD} 1>/dev/null
        echo $?
    }

    isDBinitDone () {
        # Table attributes has existed since at least v2.1
        echo "DESCRIBE attributes" | ${MYSQLCMD} 1>/dev/null
        echo $?
    }

    RETRY=100
    until [ $(isDBup) -eq 0 ] || [ ${RETRY} -le 0 ]
    do
        echo "Waiting for database to come up"
        sleep 5
        RETRY=$(( RETRY - 1))
    done
    if [ ${RETRY} -le 0 ]
    then
        >&2 echo "Error: Could not connect to Database on ${MYSQL_HOST}:${MYSQL_PORT}"
        exit 1
    fi

    if [ $(isDBinitDone) -eq 0 ]
    then
        echo "Database has already been initialized"
    else
        echo "Database has not been initialized, importing MySQL scheme..."
        ${MYSQLCMD} < ${PATH_TO_MISP}/INSTALL/MYSQL.sql
    fi
}

init_misp_persistent_storage() {
    for dir_name in cache/feeds cache/ingest cache/models cache/persistent cache/views cached_exports/rpz files logs resque sessions yara
    do
        if [ ! -d ${PATH_TO_MISP}/app/tmp/${dir_name} ]
        then
            mkdir -p ${PATH_TO_MISP}/app/tmp/${dir_name}
        fi
    done

    mkdir -p ${PATH_TO_MISP}/app/files/attachments ${PATH_TO_MISP}/app/files/scripts/tmp ${PATH_TO_MISP}/app/files/terms ${PATH_TO_MISP}/app/files/webroot/files ${PATH_TO_MISP}/app/files/webroot/img/custom ${PATH_TO_MISP}/app/files/webroot/img/orgs
    [ ! -d ${PATH_TO_MISP}/app/files/community-metadata ] && cp -r ${PATH_TO_MISP}/save/files/community-metadata ${PATH_TO_MISP}/app/files/community-metadata
    [ ! -d ${PATH_TO_MISP}/app/files/feed-metadata ] && cp -r ${PATH_TO_MISP}/save/files/feed-metadata ${PATH_TO_MISP}/app/files/feed-metadata
    [ ! -d ${PATH_TO_MISP}/app/files/misp-decaying-models ] && git clone --depth 1 https://github.com/MISP/misp-decaying-models.git ${PATH_TO_MISP}/app/files/misp-decaying-models
    [ ! -d ${PATH_TO_MISP}/app/files/misp-galaxy ] && git clone --depth 1 https://github.com/MISP/misp-galaxy.git ${PATH_TO_MISP}/app/files/misp-galaxy
    [ ! -d ${PATH_TO_MISP}/app/files/misp-objects ] && git clone --depth 1 https://github.com/MISP/misp-objects.git ${PATH_TO_MISP}/app/files/misp-objects
    [ ! -d ${PATH_TO_MISP}/app/files/noticelists ] && git clone --depth 1 https://github.com/MISP/misp-noticelist.git ${PATH_TO_MISP}/app/files/noticelists
    [ ! -d ${PATH_TO_MISP}/app/files/taxonomies ] && git clone --depth 1 https://github.com/MISP/misp-taxonomies.git ${PATH_TO_MISP}/app/files/taxonomies
    [ ! -d ${PATH_TO_MISP}/app/files/warninglists ] && git clone --depth 1 https://github.com/MISP/misp-warninglists.git ${PATH_TO_MISP}/app/files/warninglists
    cd ${PATH_TO_MISP}
    git submodule update --recursive
}

update_GOWNT() {
    ${CAKE} Admin updateGalaxies
    ${CAKE} Admin updateTaxonomies
    ${CAKE} Admin updateWarningLists
    ${CAKE} Admin updateNoticeLists
    ${CAKE} Admin updateObjectTemplates "1"
}

sync_persistent_directories() {
    rsync -a --delete --exclude=/tmp ${PATH_TO_MISP}/save/files/scripts/ ${PATH_TO_MISP}/app/files/scripts
    rsync -a ${PATH_TO_MISP}/save/orgs/ ${PATH_TO_MISP}/app/webroot/img/orgs
}

setup_gnupg() {
    echo "%echo Generating a default key
    Key-Type: default
    Key-Length: ${GPG_KEY_LENGTH}
    Subkey-Type: default
    Name-Real: ${GPG_REAL_NAME}
    Name-Comment: ${GPG_COMMENT}
    Name-Email: ${GPG_EMAIL_ADDRESS}
    Expire-Date: 0
    Passphrase: ${GPG_PASSPHRASE}
    %commit
    %echo done" > /tmp/gen-key-script

    ${GPG_BINARY} --homedir ${PATH_TO_MISP_CONFIG}/.gnupg --batch --gen-key /tmp/gen-key-script
    rm -rf /tmp/gen-key-script

    if [ ! -f ${PATH_TO_MISP}/app/files/webroot/gpg.asc ]
    then
        ${GPG_BINARY} --homedir ${PATH_TO_MISP_CONFIG}/.gnupg --export --armor ${GPG_EMAIL_ADDRESS} > ${PATH_TO_MISP}/app/files/webroot/gpg.asc
    fi
}

set_config_defaults() {
    # IF you have logged in prior to running this, it will fail but the fail is NON-blocking
    ${CAKE} userInit -q

    # This makes sure all Database upgrades are done, without logging in.
    ${CAKE} Admin runUpdates

    # Tune global time outs
    ${CAKE} Admin setSetting "Session.autoRegenerate" 0
    ${CAKE} Admin setSetting "Session.timeout" 600
    ${CAKE} Admin setSetting "Session.cookieTimeout" 3600

    # Set the default temp dir
    ${CAKE} Admin setSetting "MISP.tmpdir" "${PATH_TO_MISP}/app/tmp"

    # Change base url, either with this CLI command or in the UI
    [[ ! -z ${MISP_BASEURL} ]] && ${CAKE} Baseurl ${MISP_BASEURL}
    [[ ! -z ${MISP_BASEURL} ]] && ${CAKE} Admin setSetting "MISP.external_baseurl" ${MISP_BASEURL}

    # Enable GnuPG
    ${CAKE} Admin setSetting "GnuPG.email" "${GPG_EMAIL_ADDRESS}"
    ${CAKE} Admin setSetting "GnuPG.homedir" "${PATH_TO_MISP_CONFIG}/.gnupg"
    ${CAKE} Admin setSetting "GnuPG.password" "${GPG_PASSPHRASE}"
    ${CAKE} Admin setSetting "GnuPG.obscure_subject" true
    ${CAKE} Admin setSetting "GnuPG.binary" "${GPG_BINARY}"

    # Enable installer org and tune some configurables
    ${CAKE} Admin setSetting "MISP.host_org_id" 1
    ${CAKE} Admin setSetting "MISP.email" "info@admin.test"
    ${CAKE} Admin setSetting "MISP.disable_emailing" true --force
    ${CAKE} Admin setSetting "MISP.contact" "info@admin.test"
    ${CAKE} Admin setSetting "MISP.disablerestalert" true
    ${CAKE} Admin setSetting "MISP.showCorrelationsOnIndex" true
    ${CAKE} Admin setSetting "MISP.default_event_tag_collection" 0

    # Enable Enrichment, set better timeouts
    ${CAKE} Admin setSetting "Plugin.Enrichment_services_enable" true
    ${CAKE} Admin setSetting "Plugin.Enrichment_hover_enable" true
    ${CAKE} Admin setSetting "Plugin.Enrichment_hover_popover_only" false
    ${CAKE} Admin setSetting "Plugin.Enrichment_hover_timeout" 150
    ${CAKE} Admin setSetting "Plugin.Enrichment_timeout" 300
    ${CAKE} Admin setSetting "Plugin.Enrichment_bgpranking_enabled" true
    ${CAKE} Admin setSetting "Plugin.Enrichment_countrycode_enabled" true
    ${CAKE} Admin setSetting "Plugin.Enrichment_cve_enabled" true
    ${CAKE} Admin setSetting "Plugin.Enrichment_cve_advanced_enabled" true
    ${CAKE} Admin setSetting "Plugin.Enrichment_cpe_enabled" true
    ${CAKE} Admin setSetting "Plugin.Enrichment_dns_enabled" true
    ${CAKE} Admin setSetting "Plugin.Enrichment_eql_enabled" true
    ${CAKE} Admin setSetting "Plugin.Enrichment_btc_steroids_enabled" true
    ${CAKE} Admin setSetting "Plugin.Enrichment_ipasn_enabled" true
    ${CAKE} Admin setSetting "Plugin.Enrichment_reversedns_enabled" true
    ${CAKE} Admin setSetting "Plugin.Enrichment_yara_syntax_validator_enabled" true
    ${CAKE} Admin setSetting "Plugin.Enrichment_yara_query_enabled" true
    ${CAKE} Admin setSetting "Plugin.Enrichment_wiki_enabled" true
    ${CAKE} Admin setSetting "Plugin.Enrichment_threatminer_enabled" true
    ${CAKE} Admin setSetting "Plugin.Enrichment_threatcrowd_enabled" true
    ${CAKE} Admin setSetting "Plugin.Enrichment_hashdd_enabled" true
    ${CAKE} Admin setSetting "Plugin.Enrichment_rbl_enabled" true
    ${CAKE} Admin setSetting "Plugin.Enrichment_sigma_syntax_validator_enabled" true
    ${CAKE} Admin setSetting "Plugin.Enrichment_stix2_pattern_syntax_validator_enabled" true
    ${CAKE} Admin setSetting "Plugin.Enrichment_sigma_queries_enabled" true
    ${CAKE} Admin setSetting "Plugin.Enrichment_dbl_spamhaus_enabled" true
    ${CAKE} Admin setSetting "Plugin.Enrichment_btc_scam_check_enabled" true
    ${CAKE} Admin setSetting "Plugin.Enrichment_macvendors_enabled" true
    ${CAKE} Admin setSetting "Plugin.Enrichment_qrcode_enabled" true
    ${CAKE} Admin setSetting "Plugin.Enrichment_ocr_enrich_enabled" true
    ${CAKE} Admin setSetting "Plugin.Enrichment_pdf_enrich_enabled" true
    ${CAKE} Admin setSetting "Plugin.Enrichment_docx_enrich_enabled" true
    ${CAKE} Admin setSetting "Plugin.Enrichment_xlsx_enrich_enabled" true
    ${CAKE} Admin setSetting "Plugin.Enrichment_pptx_enrich_enabled" true
    ${CAKE} Admin setSetting "Plugin.Enrichment_ods_enrich_enabled" true
    ${CAKE} Admin setSetting "Plugin.Enrichment_odt_enrich_enabled" true
    ${CAKE} Admin setSetting "Plugin.Enrichment_urlhaus_enabled" true
    ${CAKE} Admin setSetting "Plugin.Enrichment_malwarebazaar_enabled" true
    ${CAKE} Admin setSetting "Plugin.Enrichment_html_to_markdown_enabled" true
    ${CAKE} Admin setSetting "Plugin.Enrichment_socialscan_enabled" true
    ${CAKE} Admin setSetting "Plugin.Enrichment_services_url" "http://misp-modules"
    ${CAKE} Admin setSetting "Plugin.Enrichment_services_port" 6666
    ${CAKE} Admin setSetting "Plugin.Enrichment_clamav_enabled" true
    ${CAKE} Admin setSetting "Plugin.Enrichment_clamav_connection" "clamav:3310"

    # Enable Import modules, set better timeout
    ${CAKE} Admin setSetting "Plugin.Import_services_enable" true
    ${CAKE} Admin setSetting "Plugin.Import_services_url" "http://misp-modules"
    ${CAKE} Admin setSetting "Plugin.Import_services_port" 6666
    ${CAKE} Admin setSetting "Plugin.Import_timeout" 300
    ${CAKE} Admin setSetting "Plugin.Import_ocr_enabled" true
    ${CAKE} Admin setSetting "Plugin.Import_mispjson_enabled" true
    ${CAKE} Admin setSetting "Plugin.Import_openiocimport_enabled" true
    ${CAKE} Admin setSetting "Plugin.Import_threatanalyzer_import_enabled" true
    ${CAKE} Admin setSetting "Plugin.Import_csvimport_enabled" true

    # Enable Export modules, set better timeout
    ${CAKE} Admin setSetting "Plugin.Export_services_enable" true
    ${CAKE} Admin setSetting "Plugin.Export_services_url" "http://misp-modules"
    ${CAKE} Admin setSetting "Plugin.Export_services_port" 6666
    ${CAKE} Admin setSetting "Plugin.Export_timeout" 300
    ${CAKE} Admin setSetting "Plugin.Export_pdfexport_enabled" true

    # Provisional Cortex tunes
    ${CAKE} Admin setSetting "Plugin.Cortex_services_enable" false
    ${CAKE} Admin setSetting "Plugin.Cortex_services_url" "http://cortex"
    ${CAKE} Admin setSetting "Plugin.Cortex_services_port" 9000
    ${CAKE} Admin setSetting "Plugin.Cortex_timeout" 120
    ${CAKE} Admin setSetting "Plugin.Cortex_authkey" false
    ${CAKE} Admin setSetting "Plugin.Cortex_ssl_verify_peer" false
    ${CAKE} Admin setSetting "Plugin.Cortex_ssl_verify_host" false
    ${CAKE} Admin setSetting "Plugin.Cortex_ssl_allow_self_signed" true

    # Various plugin sightings settings
    ${CAKE} Admin setSetting "Plugin.Sightings_policy" 0
    ${CAKE} Admin setSetting "Plugin.Sightings_anonymise" false
    ${CAKE} Admin setSetting "Plugin.Sightings_anonymise_as" 1
    ${CAKE} Admin setSetting "Plugin.Sightings_range" 365
    ${CAKE} Admin setSetting "Plugin.Sightings_sighting_db_enable" false

    # Plugin CustomAuth tuneable
    ${CAKE} Admin setSetting "Plugin.CustomAuth_disable_logout" false

    # RPZ Plugin settings
    ${CAKE} Admin setSetting "Plugin.RPZ_policy" "DROP"
    ${CAKE} Admin setSetting "Plugin.RPZ_walled_garden" "127.0.0.1"
    ${CAKE} Admin setSetting "Plugin.RPZ_serial" "\$date00"
    ${CAKE} Admin setSetting "Plugin.RPZ_refresh" "2h"
    ${CAKE} Admin setSetting "Plugin.RPZ_retry" "30m"
    ${CAKE} Admin setSetting "Plugin.RPZ_expiry" "30d"
    ${CAKE} Admin setSetting "Plugin.RPZ_minimum_ttl" "1h"
    ${CAKE} Admin setSetting "Plugin.RPZ_ttl" "1w"
    ${CAKE} Admin setSetting "Plugin.RPZ_ns" "localhost."
    ${CAKE} Admin setSetting "Plugin.RPZ_ns_alt" false
    ${CAKE} Admin setSetting "Plugin.RPZ_email" "root.localhost"

    # Kafka settings
    ${CAKE} Admin setSetting "Plugin.Kafka_enable" false
    ${CAKE} Admin setSetting "Plugin.Kafka_brokers" "kafka:9092"
    ${CAKE} Admin setSetting "Plugin.Kafka_rdkafka_config" "${PATH_TO_MISP_CONFIG}/rdkafka.ini"
    ${CAKE} Admin setSetting "Plugin.Kafka_include_attachments" false
    ${CAKE} Admin setSetting "Plugin.Kafka_event_notifications_enable" false
    ${CAKE} Admin setSetting "Plugin.Kafka_event_notifications_topic" "misp_event"
    ${CAKE} Admin setSetting "Plugin.Kafka_event_publish_notifications_enable" false
    ${CAKE} Admin setSetting "Plugin.Kafka_event_publish_notifications_topic" "misp_event_publish"
    ${CAKE} Admin setSetting "Plugin.Kafka_object_notifications_enable" false
    ${CAKE} Admin setSetting "Plugin.Kafka_object_notifications_topic" "misp_object"
    ${CAKE} Admin setSetting "Plugin.Kafka_object_reference_notifications_enable" false
    ${CAKE} Admin setSetting "Plugin.Kafka_object_reference_notifications_topic" "misp_object_reference"
    ${CAKE} Admin setSetting "Plugin.Kafka_attribute_notifications_enable" false
    ${CAKE} Admin setSetting "Plugin.Kafka_attribute_notifications_topic" "misp_attribute"
    ${CAKE} Admin setSetting "Plugin.Kafka_shadow_attribute_notifications_enable" false
    ${CAKE} Admin setSetting "Plugin.Kafka_shadow_attribute_notifications_topic" "misp_shadow_attribute"
    ${CAKE} Admin setSetting "Plugin.Kafka_tag_notifications_enable" false
    ${CAKE} Admin setSetting "Plugin.Kafka_tag_notifications_topic" "misp_tag"
    ${CAKE} Admin setSetting "Plugin.Kafka_sighting_notifications_enable" false
    ${CAKE} Admin setSetting "Plugin.Kafka_sighting_notifications_topic" "misp_sighting"
    ${CAKE} Admin setSetting "Plugin.Kafka_user_notifications_enable" false
    ${CAKE} Admin setSetting "Plugin.Kafka_user_notifications_topic" "misp_user"
    ${CAKE} Admin setSetting "Plugin.Kafka_organisation_notifications_enable" false
    ${CAKE} Admin setSetting "Plugin.Kafka_organisation_notifications_topic" "misp_organisation"
    ${CAKE} Admin setSetting "Plugin.Kafka_audit_notifications_enable" false
    ${CAKE} Admin setSetting "Plugin.Kafka_audit_notifications_topic" "misp_audit"

    # ZeroMQ settings
    ${CAKE} Admin setSetting "Plugin.ZeroMQ_host" "misp"
    ${CAKE} Admin setSetting "Plugin.ZeroMQ_port" 50000
    ${CAKE} Admin setSetting "Plugin.ZeroMQ_redis_host" "${REDIS_FQDN}"
    ${CAKE} Admin setSetting "Plugin.ZeroMQ_redis_password" "${REDIS_PASSWORD}"
    ${CAKE} Admin setSetting "Plugin.ZeroMQ_redis_port" 6379
    ${CAKE} Admin setSetting "Plugin.ZeroMQ_redis_database" 1
    ${CAKE} Admin setSetting "Plugin.ZeroMQ_redis_namespace" "mispq"
    ${CAKE} Admin setSetting "Plugin.ZeroMQ_event_notifications_enable" false
    ${CAKE} Admin setSetting "Plugin.ZeroMQ_object_notifications_enable" false
    ${CAKE} Admin setSetting "Plugin.ZeroMQ_object_reference_notifications_enable" false
    ${CAKE} Admin setSetting "Plugin.ZeroMQ_attribute_notifications_enable" false
    ${CAKE} Admin setSetting "Plugin.ZeroMQ_sighting_notifications_enable" false
    ${CAKE} Admin setSetting "Plugin.ZeroMQ_user_notifications_enable" false
    ${CAKE} Admin setSetting "Plugin.ZeroMQ_organisation_notifications_enable" false
    ${CAKE} Admin setSetting "Plugin.ZeroMQ_include_attachments" false
    ${CAKE} Admin setSetting "Plugin.ZeroMQ_tag_notifications_enable" false
    ${CAKE} Admin setSetting "Plugin.ZeroMQ_enable" true

    # Force defaults to make MISP Server Settings less RED
    ${CAKE} Admin setSetting "MISP.language" "eng"
    ${CAKE} Admin setSetting "MISP.proposals_block_attributes" false

    # Redis block
    ${CAKE} Admin setSetting "MISP.redis_host" "${REDIS_FQDN}"
    ${CAKE} Admin setSetting "MISP.redis_port" 6379
    ${CAKE} Admin setSetting "MISP.redis_database" 13
    ${CAKE} Admin setSetting "MISP.redis_password" "${REDIS_PASSWORD}"

    # Force defaults to make MISP Server Settings less YELLOW
    ${CAKE} Admin setSetting "MISP.ssdeep_correlation_threshold" 40
    ${CAKE} Admin setSetting "MISP.extended_alert_subject" false
    ${CAKE} Admin setSetting "MISP.default_event_threat_level" 4
    ${CAKE} Admin setSetting "MISP.newUserText" "Dear new MISP user,\\n\\nWe would hereby like to welcome you to the \$org MISP community.\\n\\n Use the credentials below to log into MISP at \$misp, where you will be prompted to manually change your password to something of your own choice.\\n\\nUsername: \$username\\nPassword: \$password\\n\\nIf you have any questions, don't hesitate to contact us at: \$contact.\\n\\nBest regards,\\nYour \$org MISP support team"
    ${CAKE} Admin setSetting "MISP.passwordResetText" "Dear MISP user,\\n\\nA password reset has been triggered for your account. Use the below provided temporary password to log into MISP at \$misp, where you will be prompted to manually change your password to something of your own choice.\\n\\nUsername: \$username\\nYour temporary password: \$password\\n\\nIf you have any questions, don't hesitate to contact us at: \$contact.\\n\\nBest regards,\\nYour \$org MISP support team"
    ${CAKE} Admin setSetting "MISP.enableEventBlocklisting" true
    ${CAKE} Admin setSetting "MISP.enableOrgBlocklisting" true
    ${CAKE} Admin setSetting "MISP.log_client_ip" true
    ${CAKE} Admin setSetting "MISP.log_auth" false
    ${CAKE} Admin setSetting "MISP.log_user_ips" true
    ${CAKE} Admin setSetting "MISP.log_user_ips_authkeys" true
    ${CAKE} Admin setSetting "MISP.disableUserSelfManagement" false
    ${CAKE} Admin setSetting "MISP.disable_user_login_change" false
    ${CAKE} Admin setSetting "MISP.disable_user_password_change" false
    ${CAKE} Admin setSetting "MISP.disable_user_add" false
    ${CAKE} Admin setSetting "MISP.block_event_alert" false
    ${CAKE} Admin setSetting "MISP.block_event_alert_tag" "no-alerts=\"true\""
    ${CAKE} Admin setSetting "MISP.block_old_event_alert" false
    ${CAKE} Admin setSetting "MISP.block_old_event_alert_age" ""
    ${CAKE} Admin setSetting "MISP.block_old_event_alert_by_date" ""
    ${CAKE} Admin setSetting "MISP.event_alert_republish_ban" false
    ${CAKE} Admin setSetting "MISP.event_alert_republish_ban_threshold" 5
    ${CAKE} Admin setSetting "MISP.event_alert_republish_ban_refresh_on_retry" false
    ${CAKE} Admin setSetting "MISP.incoming_tags_disabled_by_default" false
    ${CAKE} Admin setSetting "MISP.maintenance_message" "Great things are happening! MISP is undergoing maintenance, but will return shortly. You can contact the administration at \$email."
    ${CAKE} Admin setSetting "MISP.footermidleft" "This is an initial install"
    ${CAKE} Admin setSetting "MISP.footermidright" "Please configure and harden accordingly"
    ${CAKE} Admin setSetting "MISP.welcome_text_top" "Initial Install, please configure"
    ${CAKE} Admin setSetting "MISP.welcome_text_bottom" "Welcome to MISP, change this message in MISP Settings"
    ${CAKE} Admin setSetting "MISP.attachments_dir" "${PATH_TO_MISP}/app/files/attachments"
    ${CAKE} Admin setSetting "MISP.download_attachments_on_load" true
    ${CAKE} Admin setSetting "MISP.attachment_scan_module" "clamav"
    ${CAKE} Admin setSetting "MISP.event_alert_metadata_only" false
    ${CAKE} Admin setSetting "MISP.title_text" "MISP"
    ${CAKE} Admin setSetting "MISP.terms_download" false
    ${CAKE} Admin setSetting "MISP.showorgalternate" false
    ${CAKE} Admin setSetting "MISP.event_view_filter_fields" "id, uuid, value, comment, type, category, Tag.name"
    ${CAKE} Admin setSetting "MISP.python_bin" $(which python3)

    # Force defaults to make MISP Server Settings less GREEN
    ${CAKE} Admin setSetting "debug" 0
    ${CAKE} Admin setSetting "Security.auth_enforced" false
    ${CAKE} Admin setSetting "Security.log_each_individual_auth_fail" false
    ${CAKE} Admin setSetting "Security.rest_client_baseurl" ""
    ${CAKE} Admin setSetting "Security.advanced_authkeys" false
    ${CAKE} Admin setSetting "Security.password_policy_length" 12
    ${CAKE} Admin setSetting "Security.password_policy_complexity" '/^((?=.*\d)|(?=.*\W+))(?![\n])(?=.*[A-Z])(?=.*[a-z]).*$|.{16,}/'

    # Appease the security audit, #hardening
    ${CAKE} Admin setSetting "Security.disable_browser_cache" true
    ${CAKE} Admin setSetting "Security.check_sec_fetch_site_header" true
    ${CAKE} Admin setSetting "Security.csp_enforce" true
    ${CAKE} Admin setSetting "Security.advanced_authkeys" true
    ${CAKE} Admin setSetting "Security.do_not_log_authkeys" true

    # Appease the security audit, #loggin
    ${CAKE} Admin setSetting "Security.username_in_response_header" true

    # Set redis settings for the Simple Background Jobs
    ${CAKE} Admin setSetting "SimpleBackgroundJobs.redis_host" "${REDIS_FQDN}"
    ${CAKE} Admin setSetting "SimpleBackgroundJobs.redis_password" "${REDIS_PASSWORD}"

    # Set MISP Live
    ${CAKE} Live "1"
}

if [ "${FPM}" != false ]
then
    if [ ! -f ${PATH_TO_MISP_CONFIG}/config.php ]
    then
        echo "Setup MySQL..." && init_mysql
        if [ ! -d ${PATH_TO_MISP}/app/files/attachments ]
        then
            echo "Configure MISP | Initialize misp persistent storage..." && init_misp_persistent_storage
        fi
        echo "Configure MISP | Initialize misp base config..." && init_misp_config
        echo "Configure MISP | Set defaults in config.php..." && set_config_defaults
        echo ""
        echo "Configure MISP | Updating Galaxies, ObjectTemplates, Warninglists, Noticelists and Templates..." && update_GOWNT
    fi
    echo "Configure MISP | Sync webroot and files/scripts directories..." && sync_persistent_directories
    if [ ! -d ${PATH_TO_MISP_CONFIG}/.gnupg ]
    then
        echo "Configure MISP | Generate GnuPG key..." && setup_gnupg
    fi
fi

if [ "${CRON}" != false ] && [ ! -d /var/spool/cron/crontabs ]
then
    mkdir -p /var/spool/cron/crontabs
    chmod u=rwx,g=wx,o=t /var/spool/cron/crontabs
fi

exec "$@"
