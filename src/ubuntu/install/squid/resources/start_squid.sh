#!/usr/bin/env bash
set -ex

{
    IP=$(ip route get 1.1.1.1 | grep -oP "src \\K\\S+")

    mkdir -p /tmp/working_certs
    cd /tmp/working_certs

    if [ -f /etc/centos-release ]; then
        DISTRO=centos
    elif [ -f /etc/oracle-release ] || [ -f /etc/rocky-release ] || [ -f /etc/almalinux-release ]; then
        DISTRO=oracle7
    elif [ -f /usr/bin/zypper ]; then
        DISTRO=opensuse
    elif [ -f /etc/fedora-release ]; then
        DISTRO=fedora
    elif [ -f /etc/dpkg/origins/parrot ]; then
        DISTRO=parrotos6
    elif [ -f /etc/alpine-release ]; then
        DISTRO=alpine
    fi

    if [[ "${DISTRO}" == @(centos|oracle7|fedora) ]]; then
        CERT_FILE=/etc/pki/ca-trust/source/anchors/squid.crt
    elif [ "${DISTRO}" == "opensuse" ]; then
        CERT_FILE=/usr/share/pki/trust/anchors/squid.crt
    else
        CERT_FILE=/usr/local/share/ca-certificates/squid.crt
    fi
    CERT_NAME="Squid Root CA"

    if [ ! -f "/usr/local/squid/etc/ssl_cert/squid.pem" ]; then
        echo "Generating Squid Cert"
        openssl req -new -newkey rsa:2048 -sha256 -days 3650 -nodes -x509 -extensions v3_ca -subj "/C=US/ST=CA/O=Kasm Technologies/CN=kasm.localhost.net" -keyout myCA.pem  -out myCA.pem
        openssl x509 -in myCA.pem -outform DER -out myCA.der
        openssl x509 -in myCA.pem -outform DER -out myCA.der
        cp myCA.pem  ${CERT_FILE}
        cp myCA.pem  /usr/local/squid/etc/ssl_cert/squid.pem
    else
        cp /usr/local/squid/etc/ssl_cert/squid.pem ${CERT_FILE}
    fi

    if [[ "${DISTRO}" == @(centos|oracle7|fedora) ]]; then
        update-ca-trust
    else
        update-ca-certificates
    fi

    cd $HOME
    rm -rf /tmp/working_certs

    for certDB in $(find / -name "cert9.db")
    do
        certdir=$(dirname ${certDB});
        echo "Updating $certdir"
        certutil -A -n "${CERT_NAME}" -t "TCu,," -i ${CERT_FILE} -d sql:${certdir}
        chown -R 1000:1000 ${certdir}
    done

    export MEMCACHE_PASSWORD="$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 13 )"
    echo $MEMCACHE_PASSWORD | saslpasswd2 -a memcached -c -f /etc/sasl2/memcached-sasldb2 kasm
    if [[ "${DISTRO}" == @(centos|oracle7|opensuse|fedora|alpine) ]]; then
        MEMCACHE_USER=memcached
    else
        MEMCACHE_USER=memcache
    fi
    chown $MEMCACHE_USER:$MEMCACHE_USER /etc/sasl2/memcached-sasldb2


    if [[ "${DISTRO}" == @(centos|oracle7|fedora|parrotos6|alpine) ]]; then
        /usr/bin/memcached -u $MEMCACHE_USER &
    elif [ "${DISTRO}" == "opensuse" ]; then
        /usr/sbin/memcached -u $MEMCACHE_USER &
    else
        /etc/init.d/memcached start
    fi
    /etc/squid/kasm_squid_adapter  --load-cache
    /usr/local/squid/sbin/squid -f /etc/squid/squid.conf

    echo "Done!"
} 2>&1 | tee /usr/local/squid/var/logs/start_squid.log
