#!/bin/bash
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



fdc_notice "Setting up Docker permissions"
# Make sure our data directory perms are correct
chown root:root /var/lib/docker
chmod 0710 /var/lib/docker


fdc_notice "Initializing Docker settings"

export DOCKER_IPV4_BASE=${DOCKER_IPV4_BASE:-"172.31.0.0/16"}
export DOCKER_IPV4_SIZE=${DOCKER_IPV4_SIZE:-"27"}

# Check if we're automatically going to enable IPv6 support
DOCKER_IPV6_DEFAULT=no
if [ -n "$(ip -6 route show default)" ]; then
	DOCKER_IPV6_DEFAULT=yes
fi
export DOCKER_IPV6=${DOCKER_IPV6:-$DOCKER_IPV6_DEFAULT}

# We use the local use v4/v6 per RFC 8215 for
export DOCKER_IPV6_BASE=${DOCKER_IPV6_BASE:-"64:ff9b:1:ffff::/96"}
export DOCKER_IPV6_SIZE=${DOCKER_IPV6_SIZE:-"112"}
export DOCKER_IPV6_FIXED=${DOCKER_IPV6_FIXED:-"${DOCKER_IPV6_BASE%%/*}/${DOCKER_IPV6_SIZE}"}

export DOCKER_EXPERIMENTAL=${DOCKER_EXPERIMENTAL:-""}

export DOCKER_STORAGE_DRIVER=${DOCKER_STORAGE_DRIVER:-"overlay2"}

export DOCKER_TLS_CERTDIR=${DOCKER_TLS_CERTDIR:-"/etc/docker/tls"}

DOCKER_TLS_VALIDITY=${DOCKER_TLS_VALIDITY:-825}

# Create Docker configuration file
create-dockerd-config



#
# Configure IP forwarding and NAT
#

fdc_notice "Enabling IPv4 forwarding"
if ! echo 1 > /proc/sys/net/ipv4/conf/default/forwarding; then
	fdc_error "Failed to enable IPv4 forwarding, are you running --privileged?"
	false
fi
fdc_notice "Enabling IPv4 masquerading"
iptables --table nat --append POSTROUTING --out-interface eth0 -j MASQUERADE


if [ -n "$DOCKER_IPV6" ] && [ "$DOCKER_IPV6" != "no" ]; then
	fdc_notice "Enabling IPv6 forwarding"
	echo 1 > /proc/sys/net/ipv6/conf/default/forwarding
	fdc_notice "Enabling IPv6 masquerading"
	ip6tables --table nat --append POSTROUTING --out-interface eth0 -j MASQUERADE
else
	fdc_notice "IPv6 not enabled"
fi



#
# Certificate generation
#

# NK: Portions of this code is copied from https://github.com/docker-library/docker/blob/master/23.0/dind/dockerd-entrypoint.sh

# Make sure certificate directory exists
if [ ! -d "$DOCKER_TLS_CERTDIR" ]; then
	mkdir -p "$DOCKER_TLS_CERTDIR"
fi

_tls_create_private_key() {
	local f="$1"
	[ -s "$f" ] || openssl genrsa -out "$f" 4096
	chown root:root "$f"
	chmod 0640 "$f"
}

_tls_generate_sans() {
	{
		ip -oneline address | awk '{ gsub(/\/.+$/, "", $4); print "IP:" $4 }'
		{
			cat /etc/hostname
			echo 'docker'
			echo 'localhost'
			hostname -f
			hostname -s
		} | sed 's/^/DNS:/'
		[ -z "${DOCKER_TLS_SAN:-}" ] || echo "$DOCKER_TLS_SAN"
	} | sort -u | xargs printf '%s,' | sed "s/,\$//"
}

_tls_generate_certs() {
	local dir="$1"

	# If server/{ca,key,cert}.pem && !ca/key.pem, do NOTHING except verify (user likely managing CA themselves)
	if [ -s "$dir/server/ca.pem" ] && [ -s "$dir/server/cert.pem" ] && [ -s "$dir/server/key.pem" ] && [ ! -s "$dir/ca/key.pem" ]; then
		openssl verify -CAfile "$dir/server/ca.pem" "$dir/server/cert.pem"
		return
	fi

	# If ca/key.pem || !ca/cert.pem, generate CA public if necessary
	if [ -s "$dir/ca/key.pem" ] || [ ! -s "$dir/ca/cert.pem" ]; then
		# if we either have a CA private key or do *not* have a CA public key, then we should create/manage the CA
		mkdir -p "$dir/ca"
		_tls_create_private_key "$dir/ca/key.pem"
		openssl req -new -key "$dir/ca/key.pem" \
			-out "$dir/ca/cert.pem" \
			-subj '/CN=Conarx docker-in-docker CA' -x509 -days "$DOCKER_TLS_VALIDITY"
	fi

	# If ca/key.pem, generate server public
	if [ -s "$dir/ca/key.pem" ]; then
		# if we have a CA private key, we should create/manage a server key
		mkdir -p "$dir/server"
		_tls_create_private_key "$dir/server/key.pem"
		openssl req -new -key "$dir/server/key.pem" \
			-out "$dir/server/csr.pem" \
			-subj '/CN=Conarx docker-in-docker server'

		# Regenerate server cert to account for SAN and validity changes
		cat > "$dir/server/openssl.cnf" <<-EOF
			[ x509_exts ]
			subjectAltName = $(_tls_generate_sans)
		EOF
		openssl x509 -req \
				-in "$dir/server/csr.pem" \
				-CA "$dir/ca/cert.pem" \
				-CAkey "$dir/ca/key.pem" \
				-CAcreateserial \
				-out "$dir/server/cert.pem" \
				-days "$DOCKER_TLS_VALIDITY" \
				-extfile "$dir/server/openssl.cnf" \
				-extensions x509_exts
		cp "$dir/ca/cert.pem" "$dir/server/ca.pem"
		openssl verify -CAfile "$dir/server/ca.pem" "$dir/server/cert.pem"
		# Remove cruft
		rm -f "$dir/server/openssl.cnf"
		rm -f "$dir/server/csr.pem"
	fi

	# If ca/key.pem, generate client public
	if [ -s "$dir/ca/key.pem" ]; then
		# if we have a CA private key, we should create/manage a client key
		mkdir -p "$dir/client"
		_tls_create_private_key "$dir/client/key.pem"
		openssl req -new \
				-key "$dir/client/key.pem" \
				-out "$dir/client/csr.pem" \
				-subj '/CN=Conarx docker-in-docker client'
		cat > "$dir/client/openssl.cnf" <<-'EOF'
			[ x509_exts ]
			extendedKeyUsage = clientAuth
		EOF

		# Regenerate client cert to account for SAN and validity changes
		openssl x509 -req \
				-in "$dir/client/csr.pem" \
				-CA "$dir/ca/cert.pem" \
				-CAkey "$dir/ca/key.pem" \
				-CAcreateserial \
				-out "$dir/client/cert.pem" \
				-days "$DOCKER_TLS_VALIDITY" \
				-extfile "$dir/client/openssl.cnf" \
				-extensions x509_exts
		cp "$dir/ca/cert.pem" "$dir/client/ca.pem"
		openssl verify -CAfile "$dir/client/ca.pem" "$dir/client/cert.pem"
		# We create pack.pem for both the certificate and key so we can use curl for health checks
		cat "$dir/client/cert.pem" "$dir/client/key.pem" > "$dir/client/pack.pem"
		chown root:root "$dir/client/pack.pem"
		chmod 0640 "$dir/client/pack.pem"
		# Remove cruft
		rm -f "$dir/client/openssl.cnf"
		rm -f "$dir/client/csr.pem"
	fi
}

# Generate certificates
fdc_notice "Generating TLS certificates"
_tls_generate_certs "$DOCKER_TLS_CERTDIR"

# Write out client configuration environment
echo "DOCKER_CERT_PATH=$DOCKER_TLS_CERTDIR/client" > /etc/docker/client.env

# If we have a /certs directory it means we're being used as a service and have a volume mounted, so we can safely copy the client certs over
if [ -d /certs ]; then
	fdc_notice "Copying Docker client TLS certificates to /certs"
	cp -r "$DOCKER_TLS_CERTDIR"/client /certs/
fi


#
# Ideas and portions below partly based on https://github.com/moby/moby/blob/master/hack/dind
#

# AppArmor compatability
export container=docker

# If we have /sys/kernel/security and its not mounted, try mount it
# This filesystem is required by various security modules
if [ -d /sys/kernel/security ] && ! mountpoint -q /sys/kernel/security; then
	fdc_notice "Mounting security filesystem"
	if ! mount -t securityfs none /sys/kernel/security; then
		fdc_error "Failed to mount /sys/kernel/security, some things may break"
	fi
fi

# Mount our own /tmp
if ! mountpoint -q /tmp; then
	fdc_notice "Mounting tmp filesystem"
	mount -t tmpfs none /tmp
fi

# Enable cgroup v2 nesting
if [ -f /sys/fs/cgroup/cgroup.controllers ]; then
	fdc_notice "Moving processes to /init group"
	# Move the processes from the root group to the /init group, otherwise writing subtree_control fails with EBUSY
	# An error during moving non-existent process (i.e., "cat") is ignored.
	mkdir -p /sys/fs/cgroup/init
	xargs -rn1 < /sys/fs/cgroup/cgroup.procs > /sys/fs/cgroup/init/cgroup.procs || :
	# Enable controllers for cgroup subtrees
	sed -e 's/ / +/g' -e 's/^/+/' < /sys/fs/cgroup/cgroup.controllers > /sys/fs/cgroup/cgroup.subtree_control
fi

# Change mount propagation to shared to make the environment more similar to a modern Linux system, e.g. with SystemD as PID 1.
fdc_notice "Changing mount propagation to shared"
mount --make-rshared /
