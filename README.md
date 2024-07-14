# docker_squid_clamav

## Description
This is to deploy Squid Proxy in a DMZ environment. It uses SSLBump to decrypt HTTPS traffic and ClamAV to detect for malicious files.

The Dockerfile is designed to pull the code from Github and build the latest tag. This is to help ease updating with the drawback of potential build and compatability issues.

Currently configured to only server error pages in English, edit in squid.conf.

## TODO
Currently everything runs as root, to change to run as local user  
Some of the folders are set to 777 to just skip access rights issues, to resolve those

## Components
Base Image is fedora:40

Builds and install the following
* Squid (https://github.com/squid-cache/squid)
* ClamAV (https://github.com/Cisco-Talos/clamav)
* C-ICAP-SERVER (https://github.com/c-icap/c-icap-server)
* SquidClamAV (https://github.com/darold/squidclamav)



## Usage
Build the Docker Image Using
> docker build -t squidWithAV .

Run the docker image
> docker run -p 3128:3128 --name squidWithAV --rm squidWithAV

SSLBump uses a self generated certificate, to use own CA/Intermediate CA, mount /etc/squid/ssl_cert with your own certificates
> docker run -p 3128:3128 --name squidWithAVOwnCert -v ./certs:/etc/squid/ssl_cert --rm squidWithAVOwnCert

Save Log Files to Disk, mount /tmp/logFiles
> docker run -p 3128:3128 --name squidWithAVLogFiles -v ./logFiles:/tmp/logFiles --rm squidWithAVLogFiles


## Debugging Command
Spawn the container with entrypoint /bin/bash

Run clamd
> clamd

Run Squid
> /usr/local/squid/sbin/squid -f /tmp/squid.conf -NCd1

Run c-icap in foreground with max debug
> /usr/local/bin/c-icap -f /usr/local/etc/c-icap.conf -N -D -d 10 -S

