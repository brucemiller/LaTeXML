#!/bin/bash
# Script to run the latexml tests
set -e

# Load the current perl
source /usr/local/perlbrew/etc/bashrc

# Print some information

cat <<- EOM
# 
###################################################################
#                     LaTeXML Testing Runtime                     #
###################################################################
# Built with PERL=$PERL TEX=$TEX
###################################################################
EOM

echo " => perl --version"
perl --version

if [[ "$TEX" != "none" ]]; then
    echo " => tex --version";
    tex --version;
fi

echo "###################################################################"

echo " => cpanm -v --installdeps --notest ."
cpanm -v --installdeps --notest .

echo "###################################################################"

echo " => perl Makefile.PL && make fulltest"
perl Makefile.PL && make fulltest