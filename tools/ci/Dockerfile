##################################################################
## Dockerfile for LaTeXML Testing Runtime                       ##
##################################################################

ARG SRC_TAG=none
FROM ghcr.io/tkw1536/texlive-docker:$SRC_TAG

# store source tag
ARG SRC_TAG
ENV SRC_TAG=$SRC_TAG

# Install packages required by perlbrew and LaTeXML
RUN \
    # install apt dependencies, then clear the cache
    apt-get update && \
    apt-get -y install \
        build-essential \
        libdb-dev \
        libxml2-dev \
        libxslt1-dev \
        pkg-config \
        zlib1g-dev \
    && \
    rm -rf /var/lib/apt/lists/* && \
    # install cpanm dependencies, then clear cache
    cpanm -v --notest \
        Archive::Zip \
        DB_File \
        File::Which \
        Getopt::Long \
        Image::Size \
        IO::String \
        JSON::XS \
        LWP \
        MIME::Base64 \
        Parse::RecDescent \
        Pod::Parser \
        Text::Unidecode \
        Test::More \
        URI \
        XML::LibXML \
        XML::LibXSLT \
        UUID::Tiny \
    && \
    rm -rf $HOME/.cpanm
