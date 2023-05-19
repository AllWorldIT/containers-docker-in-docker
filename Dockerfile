# Copyright (c) 2022-2023, AllWorldIT.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to
# deal in the Software without restriction, including without limitation the
# rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
# sell copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.


FROM registry.conarx.tech/containers/alpine/3.18

# 3.17 = 1.41
# 3.18 = 1.42
ENV DOCKER_API_VERSION=1.42


ARG VERSION_INFO=
LABEL org.opencontainers.image.authors   "Nigel Kukard <nkukard@conarx.tech>"
LABEL org.opencontainers.image.version   "3.18"
LABEL org.opencontainers.image.base.name "registry.conarx.tech/containers/alpine/3.18"



RUN set -eux; \
	true "Docker"; \
	apk add --no-cache \
		btrfs-progs \
		curl \
		docker \
		e2fsprogs \
		e2fsprogs-extra \
		ip6tables \
		iptables \
		openssl \
		pigz \
		shadow-uidmap \
		xfsprogs \
		xz \
		; \
	true "Cleanup"; \
	rm -f /var/cache/apk/*


# Set up subuid/subgid so that "--userns-remap=default" works
RUN set -eux; \
	addgroup -S dockremap; \
	adduser -S -G dockremap dockremap; \
	echo 'dockremap:165536:65536' >> /etc/subuid; \
	echo 'dockremap:165536:65536' >> /etc/subgid


# Docker
COPY etc/supervisor/conf.d/dockerd.conf /etc/supervisor/conf.d/dockerd.conf
COPY usr/local/share/flexible-docker-containers/healthcheck.d/42-docker-in-docker.sh /usr/local/share/flexible-docker-containers/healthcheck.d
COPY usr/local/share/flexible-docker-containers/init.d/42-docker-in-docker.sh /usr/local/share/flexible-docker-containers/init.d
COPY usr/local/share/flexible-docker-containers/pre-init-tests.d/42-docker-in-docker.sh /usr/local/share/flexible-docker-containers/pre-init-tests.d
COPY usr/local/share/flexible-docker-containers/tests.d/42-docker-in-docker.sh /usr/local/share/flexible-docker-containers/tests.d
COPY usr/local/bin/create-dockerd-config /usr/local/bin
COPY usr/local/bin/start-dockerd /usr/local/bin
COPY usr/local/bin/docker /usr/local/bin
RUN set -eux; \
	true "Flexible Docker Containers"; \
	if [ -n "$VERSION_INFO" ]; then echo "$VERSION_INFO" >> /.VERSION_INFO; fi; \
	mkdir /etc/docker; \
	chown root:root \
		/etc/docker \
		/usr/local/bin/docker \
		/usr/local/bin/create-dockerd-config \
		/usr/local/bin/start-dockerd; \
	chmod 0755 \
		/etc/docker \
		/usr/local/bin/docker \
		/usr/local/bin/create-dockerd-config \
		/usr/local/bin/start-dockerd; \
	fdc set-perms


VOLUME ["/var/lib/docker"]

EXPOSE 2376
