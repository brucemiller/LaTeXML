#!/bin/bash
# Script to install all the LaTeXML dependencies
set -e

# Use perlbrew
source /usr/local/perlbrew/etc/bashrc

# Update apt
apt-get update

# Install system dependencies
apt-get install -y \
    libdb-dev \
    libxml2-dev \
    libxslt1-dev \
    zlib1g-dev

# Cleanup apt cache
rm -rf /var/lib/apt/lists/*

# try to install the cpanm dependencies
cpanm \
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
|| /bin/true

# cleanup cpanm cache
rm -rf $HOME/.cpanm