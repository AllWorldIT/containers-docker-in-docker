[![pipeline status](https://gitlab.conarx.tech/containers/docker-in-docker/badges/main/pipeline.svg)](https://gitlab.conarx.tech/containers/docker-in-docker/-/commits/main)

# Container Information

[Container Source](https://gitlab.conarx.tech/containers/docker-in-docker) - [GitHub Mirror](https://github.com/AllWorldIT/containers-docker-in-docker)

This is the Conarx Containers Docker-In-Docker image, it provides a Docker service container with full IPv4 and IPv6 NAT support
together with improved security.



# Mirrors

|  Provider  |  Repository                                      |
|------------|--------------------------------------------------|
| DockerHub  | allworldit/docker-in-docker                      |
| Conarx     | registry.conarx.tech/containers/docker-in-docker |



# Conarx Containers

All our Docker images are part of our Conarx Containers product line. Images are generally based on Alpine Linux and track the
Alpine Linux major and minor version in the format of `vXX.YY`.

Images built from source track both the Alpine Linux major and minor versions in addition to the main software component being
built in the format of `vXX.YY-AA.BB`, where `AA.BB` is the main software component version.

Our images are built using our Flexible Docker Containers framework which includes the below features...

- Flexible container initialization and startup
- Integrated unit testing
- Advanced multi-service health checks
- Native IPv6 support for all containers
- Debugging options



# Community Support

Please use the project [Issue Tracker](https://gitlab.conarx.tech/containers/docker-in-docker/-/issues).



# Commercial Support

Commercial support for all our Docker images is available from [Conarx](https://conarx.tech).

We also provide consulting services to create and maintain Docker images to meet your exact needs.



# Environment Variables

Additional environment variables are available from...
* [Conarx Containers Alpine image](https://gitlab.conarx.tech/containers/alpine)


## DOCKER_IPV4_BASE

IPv4 base CIDR range. Defaults to "172.31.0.0/16".


## DOCKER_IPV4_SIZE

IPv4 block size. Defaults to "27" (/27).


## DOCKER_IPV6

Enable IPv6. It can be disabled using "no" as the value.


## DOCKER_IPV6_BASE

IPv6 base CIDR range. Defaults to "64:ff9b:1:ffff::/96".


## DOCKER_IPV6_SIZE

IPv6 block size. Defaults to "112" (/112).


## DOCKER_IPV6_FIXED

Fixed IPv6 address range. This should fit comfortably within the `DOCKER_IPV6_BASE`. Defaults to `DOCKER_IPV6_BASE` with a
`DOCKER_IPV6_SIZE` mask.


## DOCKER_EXPERIMENTAL

Enable experimental docker features. Defaults to "false".


## DOCKER_STORAGE_DRIVER

You should probably never need to change this. Defaults to "overlay2".


## DOCKER_TLS_SAN

Additional TLS SAN name to add to the TLS certificate. This can be in the form of "IP:xxx" or "DNS:xxx".


## DOCKER_TLS_VALIDITY

Docker TLS certificate validity period in days. Defaults "825".


## DOCKER_TLS_CERTDIR

You should probably never need to change this. This is the directory that the TLS certificates are placed in. Defaults to "/etc/docker/tls".



# Volumes


## /var/lib/docker

Docker data directory.


## /certs

If this volume is present, it will be populated with the docker client certificates.



# Exposed Ports

Docker TLS port 2376 is exposed.



# Administration

A convenience script `/usr/local/bin/docker` is available with configuration to interface with the docker daemon over TLS and
should be executed when running `docker`.
