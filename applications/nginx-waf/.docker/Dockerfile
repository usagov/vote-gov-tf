ARG modsecurity_nginx_version="1.0.3"
ARG nginx_version="1.27.3"
ARG ubuntu_version="jammy"

FROM docker.io/ubuntu:${ubuntu_version}

ARG modsecurity_nginx_version
ARG nginx_version

RUN sed -i 's/^# deb-src./deb-src /' /etc/apt/sources.list

RUN  apt-get update && \
     apt-get install -y \
      autoconf \
      automake \
      build-essential \
      doxygen \
      dpkg-dev \
      gcc \
      gettext \
      libcurl4 \
      libcurl4-openssl-dev \
      libfuzzy-dev \
      libgeoip-dev \
      liblua5.3-dev \
      libmodsecurity3 \
      libmodsecurity-dev \
      libpcre2-dev \
      libpcre3 \
      libpcre3-dev \
      libtool \
      libxml2 \
      libxml2-dev \
      libyajl-dev \
      make \
      pkg-config \
      software-properties-common \
      ssdeep \
      uuid-dev \
      wget

ARG modsecurity_path=/usr/local/src/modsecurity_nginx
RUN mkdir -p ${modsecurity_path}
WORKDIR ${modsecurity_path}
RUN wget https://github.com/SpiderLabs/ModSecurity-nginx/archive/refs/tags/v${modsecurity_nginx_version}.tar.gz
RUN tar -xf v${modsecurity_nginx_version}.tar.gz && \
    rm -f v${modsecurity_nginx_version}.tar.gz

WORKDIR /usr/share/nginx/src/
RUN apt-get build-dep -y nginx

RUN wget https://nginx.org/download/nginx-${nginx_version}.tar.gz && \
    tar -xf nginx-${nginx_version}.tar.gz && \
    rm -f nginx-${nginx_version}.tar.gz

WORKDIR /usr/share/nginx/src/nginx-${nginx_version}

RUN ./configure --add-dynamic-module=${modsecurity_path}/ModSecurity-nginx-${modsecurity_nginx_version} --with-compat && \
    make modules && \
    cp ./objs/ngx_http_modsecurity_module.so /ngx_http_modsecurity_module.so

HEALTHCHECK NONE
USER nginx
