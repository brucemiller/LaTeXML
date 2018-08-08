#!/usr/bin/env bash
set -e

echo "Installing latest TeXLive manually ..."

# curl and unpack
echo " => curl -#L http://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz | tar zxf -"
curl -#L http://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz | tar zxf -

# Move into appropriate directory
mv install-tl-* install-tl

# Setup profile
echo "selected_scheme scheme-full" > install-tl/profile
echo "TEXDIR /opt/texlive/" >> install-tl/profile

# Run the command with arguments
echo " => ./install-tl/install-tl -profile install-tl/profile"
./install-tl/install-tl -profile install-tl/profile

# Setup path
echo " => echo \"PATH=/opt/texlive/bin/x86_64-linux/\$PATH\" >> \$HOME/.bashrc"
echo "PATH=/opt/texlive/bin/x86_64-linux/\$PATH" >> $HOME/.bashrc

# and cleanup
echo " => rm -rf install-tl"
rm -rf install-tl