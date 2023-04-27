
ARG LIBSIG_VERSION=3.0.3
ARG CARES_VERSION=1.17.2
ARG CURL_VERSION=7.78.0
ARG XMLRPC_VERSION=01.58.00
ARG LIBTORRENT_VERSION=v0.13.8
ARG RTORRENT_VERSION=v0.9.8
ARG MKTORRENT_VERSION=v1.1
ARG GEOIP2_PHPEXT_VERSION=1.3.1

# v4.0.4
ARG RUTORRENT_VERSION=cba1bfc11cc8ebc8a3c65d1d37cfbd4d6261a39e
ARG GEOIP2_RUTORRENT_VERSION=4ff2bde530bb8eef13af84e4413cedea97eda148
# set version label
ARG BUILD_DATE
ARG VERSION
ARG RUTORRENT_RELEASE
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="alex-phillips"
ARG ALPINE_VERSION=3.14
ARG ALPINE_S6_VERSION=${ALPINE_VERSION}-2.2.0.3

FROM --platform=$BUILDPLATFORM alpine:${ALPINE_VERSION} AS src
RUN apk --update --no-cache add curl git subversion tar tree xz
WORKDIR /src
FROM src AS src-libsig
ARG LIBSIG_VERSION
RUN curl -sSL "http://ftp.gnome.org/pub/GNOME/sources/libsigc++/3.0/libsigc++-${LIBSIG_VERSION}.tar.xz" | tar xJv --strip 1

FROM src AS src-cares
ARG CARES_VERSION
RUN curl -sSL "https://c-ares.haxx.se/download/c-ares-${CARES_VERSION}.tar.gz" | tar xz --strip 1

FROM src AS src-xmlrpc
ARG XMLRPC_VERSION
RUN <<EOT
git clone https://github.com/crazy-max/xmlrpc-c.git .
git reset --hard $XMLRPC_VERSION
EOT

FROM src AS src-curl
ARG CURL_VERSION
RUN curl -sSL "https://curl.haxx.se/download/curl-${CURL_VERSION}.tar.gz" | tar xz --strip 1

FROM src AS src-libtorrent
ARG LIBTORRENT_VERSION
RUN <<EOT
git clone https://github.com/rakshasa/libtorrent.git .
git reset --hard $LIBTORRENT_VERSION
EOT

FROM src AS src-rtorrent
ARG RTORRENT_VERSION
RUN <<EOT
git clone https://github.com/rakshasa/rtorrent.git .
git reset --hard $RTORRENT_VERSION
EOT

FROM src AS src-mktorrent
ARG MKTORRENT_VERSION
RUN <<EOT
git clone https://github.com/esmil/mktorrent.git .
git reset --hard $MKTORRENT_VERSION
EOT

FROM src AS src-geoip2-phpext
ARG GEOIP2_PHPEXT_VERSION
RUN <<EOT
git clone https://github.com/rlerdorf/geoip.git .
git reset --hard $GEOIP2_PHPEXT_VERSION
EOT

FROM src AS src-rutorrent
ARG RUTORRENT_VERSION
RUN <<EOT
git clone https://github.com/Novik/ruTorrent.git .
git reset --hard $RUTORRENT_VERSION
rm -rf .git* conf/users plugins/geoip share
EOT

FROM src AS src-geoip2-rutorrent
ARG GEOIP2_RUTORRENT_VERSION
RUN <<EOT
git clone https://github.com/Micdu70/geoip2-rutorrent .
git reset --hard $GEOIP2_RUTORRENT_VERSION
rm -rf .git*
EOT

FROM src AS src-mmdb
RUN curl -SsOL "https://github.com/crazy-max/geoip-updater/raw/mmdb/GeoLite2-City.mmdb" \
  && curl -SsOL "https://github.com/crazy-max/geoip-updater/raw/mmdb/GeoLite2-Country.mmdb"

FROM ghcr.io/linuxserver/baseimage-alpine-nginx:3.14
# copy patches
COPY patches/ /defaults/patches/

RUN \
 echo "**** install build packages ****" && \
 apk add --no-cache --virtual=build-dependencies \
	g++ \
	libffi-dev \
	openssl-dev \
	patch \
	py3-pip \
	python3-dev && \
 echo "**** install runtime packages ****" && \
 apk add --no-cache --upgrade \
	bind-tools \
	curl \
	fcgi \
	ffmpeg \
	geoip \
	gzip \
	libffi \
	mediainfo \
	openssl \
	php7 \
	php7-cgi \
	php7-curl \
	php7-pear \
	php7-zip \
	procps \
	py3-requests \
	python3 \
	rtorrent \
	screen \
	sox \
	unrar \
	zip && \
 echo "**** install pip packages ****" && \
 pip3 install --no-cache-dir -U \
	cfscrape \
	cloudscraper && \
 echo "**** install rutorrent ****" && \
 if [ -z ${RUTORRENT_RELEASE+x} ]; then \
	RUTORRENT_RELEASE=$(curl -sX GET "https://api.github.com/repos/Novik/ruTorrent/releases/latest" \
	| awk '/tag_name/{print $4;exit}' FS='[""]'); \
 fi && echo "rutorrent version is ${RUTORRENT_RELEASE}" &&\
 curl -o \
 /tmp/rutorrent.tar.gz -L \
	"https://github.com/Novik/rutorrent/archive/${RUTORRENT_RELEASE}.tar.gz" && \
 mkdir -p \
	/app/rutorrent \
	/defaults/rutorrent-conf && \
 tar xf \
 /tmp/rutorrent.tar.gz -C \
	/app/rutorrent --strip-components=1 && \
 mv /app/rutorrent/conf/* \
	/defaults/rutorrent-conf/ && \
 rm -rf \
	/defaults/rutorrent-conf/users && \
 echo "**** patch snoopy.inc for rss fix ****" && \
 cd /app/rutorrent/php && \
 patch < /defaults/patches/snoopy.patch && \
 echo "**** cleanup ****" && \
 apk del --purge \
	build-dependencies && \
 rm -rf \
	/etc/nginx/conf.d/default.conf \
	/root/.cache \
	/tmp/*

# add local files
COPY root/ /

# ports and volumes
EXPOSE 80
VOLUME /config /downloads
