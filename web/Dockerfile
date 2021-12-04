FROM nginx:latest
    COPY files/ /
    COPY --chown=www-data:www-data --from=epuzanov/misp-fpm:latest /var/www/MISP/app/webroot /var/www/MISP/app/webroot
