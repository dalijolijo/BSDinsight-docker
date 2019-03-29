# Copyright (c) 2019 The Bitsend BSD Core Developers (dalijolijo)

# Use an official Ubuntu runtime as a parent image
FROM dalijolijo/crypto-lib-ubuntu:16.04

LABEL maintainer="The Bitsend BSD Core Developers"

ENV GIT dalijolijo
USER root
WORKDIR /home
SHELL ["/bin/bash", "-c"]

RUN echo '*** BSD Insight Explorer Docker Solution ***'

# Make ports available to the world outside this container
# Default Port = 8886
# RPC Port = 8800
# Tor Port = 9051
# ZMQ Port = 28332 (Block and Transaction Broadcasting with ZeroMQ)
# API Port = 3001 (Insight Explorer is avaiable at http://yourip:3001/insight and API at http://yourip:3001/insight/api)

# Creating bitsend user
RUN adduser --disabled-password --gecos "" bitsend && \
    usermod -a -G sudo,bitsend bitsend

# Add NodeJS (Version 8) Source
RUN apt-get update && \
    apt-get install -y curl \
                       sudo && \
    curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash -

# Running updates and installing required packages
# New version libzmq5-dev needed?
RUN apt-get update && \
    apt-get dist-upgrade -y && \
    apt-get install -y build-essential \
                            git \
                            libzmq3-dev \
                            nodejs \
                            supervisor \
                            vim \
                            wget

# Update Package npm to latest version
RUN npm i npm@latest -g

# Installing required packages for compiling
RUN apt-get install -y  apt-utils \
                        autoconf \
                        automake \
                        autotools-dev \
                        build-essential \
                        libboost-all-dev \
                        libevent-dev \
                        libminiupnpc-dev \
                        libssl-dev \
                        libtool \
                        pkg-config \
                        software-properties-common
RUN sudo add-apt-repository ppa:bitcoin/bitcoin
RUN sudo apt-get update && \
    sudo apt-get -y upgrade
RUN apt-get install -y libdb4.8-dev \
                       libdb4.8++-dev

# Cloning BitSend Git repository
RUN mkdir -p /home/bitsend/src/ && \
    cd /home/bitsend && \
    git clone https://github.com/LIMXTEC/BitSend.git

# Compiling BitSend Sources
RUN cd /home/bitsend/BitSend && \
    git checkout Insight-Patch-0_14 && \
    ./autogen.sh && ./configure --disable-dependency-tracking --enable-tests=no --without-gui && make

# Strip bitsendd binary 
RUN cd /home/bitsend/BitSend/src && \
    strip bitsendd && \
    chmod 775 bitsendd && \
    cp bitsendd /home/bitsend/src/

# Remove source directory 
RUN rm -rf /home/bitsend/BitSend

# Install bitcore-node-bsd
RUN cd /home/bitsend && \
    git clone https://github.com/${GIT}/bitcore-node-bsd.git bitcore-livenet && \
    cd /home/bitsend/bitcore-livenet && \
    npm install

ENV BSD_NET "/home/bitsend/bitcore-livenet"

# Create Bitcore Node
# Hint: bitcore-node create -d <bitcoin-data-dir> mynode
RUN cd ${BSD_NET}/bin && \
    chmod 777 bitcore-node && \
    sync && \
    ./bitcore-node create -d ${BSD_NET}/bin/mynode/data mynode

# Install insight-api-bsd
RUN cd ${BSD_NET}/bin/mynode/node_modules && \
    git clone https://github.com/${GIT}/insight-api-bsd.git && \
    cd ${BSD_NET}/bin/mynode/node_modules/insight-api-bsd && \
    npm install

# Install insight-ui-bsd
RUN cd ${BSD_NET}/bin/mynode/node_modules && \
    git clone https://github.com/${GIT}/insight-ui-bsd.git && \
    cd ${BSD_NET}/bin/mynode/node_modules/insight-ui-bsd && \
    npm install

# Install bitcore-message-bsd
RUN cd ${BSD_NET}/bin/mynode/node_modules && \
    git clone https://github.com/${GIT}/bitcore-message-bsd.git && \
    cd ${BSD_NET}/bin/mynode/node_modules/bitcore-message-bsd && \
    npm install save

# Remove duplicate node_module 'bitcore-lib' to prevent startup errors such as:
#   "More than one instance of bitcore-lib found. Please make sure to require bitcore-lib and check that submodules do
#   not also include their own bitcore-lib dependency."
RUN rm -Rf ${BSD_NET}/bin/mynode/node_modules/bitcore-node-mec/node_modules/bitcore-lib-mec && \
    rm -Rf ${BSD_NET}/bin/mynode/node_modules/insight-api-mec/node_modules/bitcore-lib-mec && \
    rm -Rf ${BSD_NET}/bin/mynode/node_modules/bitcore-lib-mec

# Install bitcore-lib-bsd (not needed: part of another module)
RUN cd ${BSD_NET}/bin/mynode/node_modules && \
    git clone https://github.com/${GIT}/bitcore-lib-bsd.git && \
    cd ${BSD_NET}/bin/mynode/node_modules/bitcore-lib-bsd && \
    npm install

# Install bitcore-build-bsd
RUN cd ${BSD_NET}/bin/mynode/node_modules && \
    git clone https://github.com/${GIT}/bitcore-build-bsd.git && \
    cd ${BSD_NET}/bin/mynode/node_modules/bitcore-build-bsd && \
    npm install

# Install bitcore-wallet-service
# See: https://github.com/dalijolijo/bitcore-wallet-service-joli/blob/master/installation.md
# Reference: https://github.com/m00re/bitcore-docker
# This will launch the BWS service (with default settings) at http://localhost:3232/bws/api.
# BWS needs mongoDB. You can configure the connection at config.js
#RUN cd ${BSD_NET}/bin/mynode/node_modules && \
#    git clone https://github.com/${GIT}/bitcore-wallet-service-joli.git && \
#    cd ${BSD_NET}/bin/mynode/node_modules/bitcore-wallet-service-joli && \
#    npm install
# Configuration needed before start
#RUN npm start
#RUN rm -Rf ${BSD_NET}/bin/mynode/node_modules/bitcore-wallet-service/node_modules/bitcore-lib-mec

# Cleanup
RUN apt-get -y remove --purge build-essential && \
    apt-get -y autoremove && \
    apt-get -y clean

# Copy bitsendd to the correct bitcore-livenet/bin/ directory
RUN cp /home/bitsend/src/bitsendd ${BSD_NET}/bin/

# Copy JSON bitcore-node.json
COPY bitcore-node.json ${BSD_NET}/bin/mynode/

# Copy Supervisor Configuration
COPY *.sv.conf /etc/supervisor/conf.d/

# Copy start script
COPY start.sh /usr/local/bin/start.sh
RUN rm -f /var/log/access.log && mkfifo -m 0666 /var/log/access.log && \
    chmod 755 /usr/local/bin/*

ENV TERM linux
CMD ["/usr/local/bin/start.sh"]
