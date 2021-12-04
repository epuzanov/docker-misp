#!/bin/bash
if [[ (! -f /etc/nginx/certs/cert.pem) || (! -f /etc/nginx/certs/key.pem) ]];
then
    cd /etc/nginx/certs
    openssl req -x509 -subj '/CN=localhost' -nodes -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365
fi
if [[ ! -f /etc/nginx/certs/dhparams.pem ]]; then
    openssl dhparam -out /etc/nginx/certs/dhparams.pem 2048
fi

exit 0
