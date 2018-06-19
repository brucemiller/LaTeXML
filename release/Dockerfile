
# /=====================================================================\ #
# | LaTeXML Dockerfile                                                  | #
# | A Dockerfile to create a Docker Image with LaTeXML preinstalled.    | #
# |=====================================================================| #
# | Thanks to Tom Wiesing <tom.wiesing@gmail.com>                       | #
# | Part of LaTeXML:                                                    | #
# |  Public domain software, produced as part of work done by the       | #
# |  United States Government & not subject to copyright in the US.     | #
# |---------------------------------------------------------------------| #
# | Bruce Miller <bruce.miller@nist.gov>                        #_#     | #
# | http://dlmf.nist.gov/LaTeXML/                              (o o)    | #
# \=========================================================ooo==U==ooo=/ #

# This Dockerfile expects the root directory of LaTeXML as a build context. 
# To achieve this run the following command from the root directory:
#
# > docker build -t latexml -f release/Dockerfile .

# We start from alpine linux 3.7
FROM alpine:3.7

# Install the dependencies
RUN apk add --no-cache \
    db-dev \
    gcc \
    libc-dev \
    libgcrypt \
    libgcrypt-dev \
    libxml2 \
    libxml2-dev \
    libxslt \
    libxslt-dev \
    make \
    perl \
    perl-dev \
    perl-utils \
    wget \
    zlib \
    zlib-dev

# Install cpanminus from edge
RUN apk add --no-cache -U --repository http://dl-3.alpinelinux.org/alpine/edge/community perl-app-cpanminus

# Make a directory for latexml
RUN mkdir -p /opt/latexml

# Add all of the source files
ADD bin/            /opt/latexml/bin
#ADD doc/            /opt/latexml/doc/
ADD lib/            /opt/latexml/lib 
#ADD release/        /opt/latexml/release/
ADD t/              /opt/latexml/t/
ADD tools/          /opt/latexml/tools/
#ADD Changes         /opt/latexml/Changes
#ADD INSTALL         /opt/latexml/INSTALL
#ADD INSTALL.SKIP    /opt/latexml/INSTALL.SKIP
ADD LICENSE         /opt/latexml/LICENSE
ADD Makefile.PL     /opt/latexml/Makefile.PL
#ADD MANIFEST        /opt/latexml/MANIFEST
#ADD MANIFEST.SKIP   /opt/latexml/MANIFEST.SKIP
#ADD manual.pdf      /opt/latexml/manual.pdf
#ADD README.pod      /opt/README.pod

# Installing  via cpanm
WORKDIR /opt/latexml
RUN cpanm .