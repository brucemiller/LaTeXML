#!/bin/bash
set -e

# cd into the travis/ directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
cd "$DIR/.."

# Read in the arguments
PERL="$1"
TEX="$2"

# figure out the image tag and basic paths
IMAGE_TAG="latexml/latexml-test-runtime:${PERL}_${TEX}"
DOCKERPATH="dist/${PERL}_${TEX}"
DOCKERFILE="$DOCKERPATH/Dockerfile"

# if we don't have a tex, then comment out all the TeX lines
if [[ "$TEX" == "none" ]]; then
    TLP="#"
fi

# Prepare the Dockerfile
echo " => Writing $DOCKERFILE"
mkdir -p "$DOCKERPATH"; touch "$DOCKERFILE"

cat > "$DOCKERFILE" <<- EOF
## Dockerfile for LaTeXML Testing Runtime (Perl $PERL, LaTeX $TEX)
##################################################################
# This file has been generated automatically and should not be   #
# modified by hand.                                              #
##################################################################

FROM ubuntu:xenial

# Install packages required by perlbrew and LaTeXML
RUN apt-get update && \
    apt-get -y install git curl build-essential perl && \
    rm -rf /var/lib/apt/lists/*

# Prepare perlbrew installation
RUN mkdir -p /usr/local/perlbrew /root
ENV HOME /root
ENV PERLBREW_ROOT /usr/local/perlbrew
ENV PERLBREW_HOME /root/.perlbrew

# run the perlbrew installation
RUN curl -kL http://install.perlbrew.pl | bash
ENV PATH /usr/local/perlbrew/bin:$PATH
ENV PERLBREW_PATH /usr/local/perlbrew/bin
RUN perlbrew install-cpanm && \
    perlbrew info

# set perl version
ENV PERL $PERL

# run the installation of the given version of perl
RUN /bin/bash -c "source /usr/local/perlbrew/etc/bashrc; perlbrew --notest install $PERL; perlbrew clean; perlbrew switch $PERL"

# set tex version
ENV TEX $TEX

${TLP}# run the texlive script
${TLP}ADD installtex.sh /root/installtex.sh
${TLP}RUN /bin/bash /root/installtex.sh

# Install LaTeXML Dependencies
ADD installdeps.sh /root/installdeps.sh
RUN /bin/bash /root/installdeps.sh

# Make latexml directory
VOLUME /root/latexml
WORKDIR /root/latexml

# Add the testing script
ADD entrypoint.sh /root/entrypoint.sh
CMD ["/bin/bash", "/root/entrypoint.sh"]

EOF

echo " => copy build context"
cp "src/installdeps.sh" "$DOCKERPATH/installdeps.sh"
cp "src/entrypoint.sh" "$DOCKERPATH/entrypoint.sh"

if [[ "$TEX" != "none" ]]; then
    cp "src/$TEX.sh" "$DOCKERPATH/installtex.sh";
fi

echo " => docker build -t $IMAGE_TAG $DOCKERPATH"
docker build -t "$IMAGE_TAG" "$DOCKERPATH"

echo " => rm -rf $DOCKERPATH"
rm -rf "$DOCKERPATH"

echo "Done. Built $IMAGE_TAG. "