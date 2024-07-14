FROM fedora:40


RUN dnf install -y \
    autoconf \
    automake \
    bzip2 \
    ccache \
    clang \
    cppunit \
    cppunit-devel \
    curl \
    diffutils \
    ed \
    expat-devel \
    gcc-c++ \
    git \
    gnutls-devel \
    gnutls-utils \
    icecream \
    libatomic \
    libatomic-static \
    libcap-devel \
    libtdb-devel \
    libtool \
    libtool-ltdl-devel \
    libxml2-devel \
    make \
    nettle-devel \
    openldap-devel \
    openssl-devel \
    pam-devel \
    pandoc \
    perl-Pod-MinimumVersion \
    pkgconf-pkg-config \
    xz \
    openssl \
    libarchive-devel \
    bzip2-devel \
    cmake \
    autoconf-archive \
  && \
  yum clean all && \
  rm /etc/profile.d/ccache* && \
  true


# -------------------------------Creating Logging Directory-------------------------------
RUN mkdir /tmp/logFiles
RUN chmod 777 /tmp/logFiles

# -------------------------------Create CA-------------------------------
WORKDIR /etc/squid
RUN mkdir ssl_cert
RUN chmod 700 ssl_cert
WORKDIR /etc/squid/ssl_cert
RUN openssl req -new -newkey rsa:2048 -sha256 -days 365 -nodes -x509 -subj "/C=US/ST=Denial/L=Springfield/O=Dis/CN=testCA" -extensions v3_ca -keyout myCA.pem  -out myCA.pem

# -------------------------------Build Squid-------------------------------
# Obtain latest version of Squid using latest SQUID_ tag
RUN git clone https://github.com/squid-cache/squid.git /tmp/squid
WORKDIR /tmp/squid
RUN git checkout tags/`git tag --sort=committerdate | grep SQUID_ | tail -1`

# Create configure and make file
RUN libtoolize
RUN aclocal
RUN autoheader
RUN autoconf
RUN automake --add-missing

# Run configure for Squid
RUN ./configure --enable-async-io --enable-http-violations --enable-ssl --with-openssl --enable-ssl-crtd 
RUN make -j12
RUN make install




# --------------------------------Install Clam AV--------------------------------
RUN dnf install -y gcc gcc-c++ make python3 python3-pip valgrind bzip2-devel check-devel json-c-devel libcurl-devel libxml2-devel ncurses-devel openssl-devel pcre2-devel sendmail-devel zlib-devel cargo rust
RUN python3 -m pip install --user cmake pytest

RUN git clone https://github.com/Cisco-Talos/clamav.git /tmp/clamav
WORKDIR /tmp/clamav
RUN git checkout tags/`git tag --sort=committerdate | grep "clamav-" | grep -v "\-rc" | grep -v "clamav-20080204" | tail -1`
RUN mkdir build
WORKDIR /tmp/clamav/build
RUN cmake ../
RUN make -j12
RUN make install

# Configure and run freshclam, ClamAV update
COPY configFiles/freshclam.conf /usr/local/etc/freshclam.conf
RUN mkdir /usr/local/share/clamav
RUN chmod 777 /usr/local/share/clamav
RUN freshclam --user=root --foreground --show-progress


# --------------------------------Build C-ICAP-SERVER--------------------------------
# Obtain latest version of C-ICAP using latest SQUID_ tag
RUN git clone https://github.com/c-icap/c-icap-server.git /tmp/c-icap
WORKDIR /tmp/c-icap
RUN git checkout tags/`git tag -l | sort -V | grep "C_ICAP_" | tail -1`

# Create configure and make file
RUN libtoolize
RUN aclocal
RUN autoheader
RUN autoconf
RUN automake --add-missing

# Configure and Build C-ICAP-SERVER
RUN ./configure 'CXXFLAGS=-O2 -m64 -pipe' 'CFLAGS=-O2 -m64 -pipe' --without-bdb --prefix=/usr/local
RUN make -j12
RUN make install-strip
  

# -------------------------------Build SquidClamAV-------------------------------
RUN git clone https://github.com/darold/squidclamav.git /tmp/squidclamav
WORKDIR /tmp/squidclamav
RUN git checkout tags/`git tag -l | sort -V | tail -1`

RUN ./configure 'CXXFLAGS=-O2 -m64 -pipe' 'CFLAGS=-O2 -m64 -pipe' --with-c-icap=/usr/local/
RUN make
RUN make install-strip


# Prepare Squid for SSL Bump
RUN /usr/local/squid/libexec/security_file_certgen -c -s /usr/local/squid/var/cache/squid/ssl_db -M 40MB
RUN chown -R nobody /usr/local/squid/var/cache/squid/ssl_db
# ADD errors /usr/local/squid/share/errors

RUN touch /usr/local/squid/var/logs/cache.log; chmod 777 -R /usr/local/squid/
RUN touch /usr/local/squid/var/logs/access.log; chmod 777 -R /usr/local/squid/
COPY configFiles/squid.conf /tmp/squid.conf
RUN /usr/local/squid/sbin/squid -z

# Set C-ICAP-SERVER and SquidClamAV config
COPY configFiles/c-icap.conf /usr/local/etc/c-icap.conf
COPY configFiles/squidclamav.conf /usr/local/etc/squidclamav.conf
COPY configFiles/clamd.conf /usr/local/etc/clamd.conf

RUN cp /tmp/squidclamav/etc/templates/en/MALWARE_FOUND /usr/local/squid/share/errors/MALWARE_FOUND

ENTRYPOINT freshclam --user=root & clamd; /usr/local/bin/c-icap -f /usr/local/etc/c-icap.conf; /usr/local/squid/sbin/squid -f /tmp/squid.conf -NCd1