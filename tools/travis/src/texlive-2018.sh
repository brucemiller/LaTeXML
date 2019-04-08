#!/usr/bin/env bash
set -e

echo "Installing TeXLive 2018 from ppa jonathonf/texlive-2018 ..."

echo " => apt-get update"
apt-get update

echo " => apt-get install software-properties-common -y"
apt-get install software-properties-common -y

echo " => add-apt-repository ppa:jonathonf/texlive-2018 -y"
add-apt-repository ppa:jonathonf/texlive-2018 -y

echo " => apt-get update"
apt-get update

echo " => apt-fast install texlive-full -y"
apt-get install texlive-full -y

echo " => rm -rf /var/lib/apt/lists/*"
rm -rf /var/lib/apt/lists/*