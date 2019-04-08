#!/usr/bin/env bash
set -e

echo "Installing TeXLive 2015 via packages ..."

echo " => apt-get update"
apt-get update

echo " => apt-get install texlive-full -y"
apt-get install texlive-full -y

echo " => rm -rf /var/lib/apt/lists/*"
rm -rf /var/lib/apt/lists/*