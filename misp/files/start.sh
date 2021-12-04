#!/bin/bash

_term() {
    if [ -f /run/crond.pid ]
    then
        kill -TERM `cat /run/crond.pid` 2>/dev/null
    fi
    if [ -f /run/php7.4-fpm.pid ]
    then
        if [ -f /var/www/MISP/app/files/scripts/tmp/mispzmq.pid ]
        then
            kill -TERM `cat /var/www/MISP/app/files/scripts/tmp/mispzmq.pid` 2>/dev/null
        fi
        USER=www-data /var/www/MISP/app/Console/worker/stop.sh
    fi
    if [ "${ppid}" ]
    then
        kill -TERM "${ppid}" 2>/dev/null
    fi
}

trap _term SIGTERM

if [ "${CRON}" == true ]
then
    # Import Cron configuration
    crontab /etc/cron.d/misp
    cron
fi

if [ "${FPM}" != false ]
then
    /var/www/MISP/app/Console/worker/start.sh
    /usr/sbin/php-fpm7.4 -F &
else
    touch /var/www/MISP/app/tmp/logs/cron.log
    tail -f /var/www/MISP/app/tmp/logs/cron.log &
fi
ppid=$!
wait ${ppid}
exit 0
