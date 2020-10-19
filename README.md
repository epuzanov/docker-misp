# MISP Docker images

A Dockered MISP

This is based on some of the work from the CoolAcid's docker build.

-   Components are split out where possible
-   Do not rely on supervisord
-   Over writable configuration files
-   Allows volumes for file store
-   Cron job runs updates, pushes, and pulls - Logs go to docker logs
-   Cron daemon can be startet within misp-fpm container or separated container
-   Docker-Compose uses off the shelf images for Nginx, Redis and MySQL
-   Images directly from docker hub, no build required
-   Slimmed down images by using build stages and slim parent image, removes unnecessary files from images
-   Build Kafka modules
-   Contaioner can be started with read-only rootfs

## Docker Tags

builds the images automatically based on git tags. I try and tag using the following details

***\[MISP Version]\[Our build version]***

-   MISP version is the MISP tag we're building
-   Our build version is the iteration for our changes with the same MISP version

## Getting Started

### Development/Test

-   A dry run will create sane default configurations

-   `docker-compose up -d`

-   Login to `https://localhost`
    -   User: `admin@admin.test`
    -   Password: `admin`

-   Profit

### Using the image for development

Pull the entire repository, you can build the images using `docker-compose build`

Once you have the docker container up you can access the container by running `docker-compose exec misp /bin/bash`.
This will provide you with a root shell. You can use `apt update` and then install any tools you wish to use.
Finally, copy any changes you make outside of the container for commiting to your branch. 
`git diff -- [dir with changes]` could be used to reduce the number of changes in a patch file, however, becareful when using the `git diff` command.

### Updating

Updating the images should be as simple as `docker-compose pull` which, unless changed in the `docker-compose.yml` file will pull the latest built images.

### Production
-   It is recommended to specify which build you want to be running, and modify that version number when you would like to upgrade

-   Use docker-compose, or some other config management tool

-   Directory volume mount SSL Certs `./ssl`: `/etc/nginx/certs`
    -   Certificate File: `cert.pem`
    -   Certificate Key File: `key.pem`

-   Directory volume mount and create configs: `/var/www/MISP/app/Config/`

-   Additional directory volume mounts:
    -   `/var/www/MISP/app/files`
    -   `/var/www/MISP/app/tmp`

## Image file sizes

-   Core server(Saved: 2.6GB)
    -   Original Image: 3.17GB
    -   First attempt: 2.24GB
    -   Remove chown: 1.56GB
    -   PreBuild python modules, and only pull submodules we need: 800MB
    -   PreBuild PHP modules: 596MB

-   Modules (Saved: 732MB)
    -   Original: 1.36GB
    -   Pre-build modules: 661MB
