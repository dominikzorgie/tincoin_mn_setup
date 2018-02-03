#!/bin/bash

echo "Installing script dependencies, please wait..."

sudo apt-get update 2>&1 > /dev/null
sudo apt-get install -y ruby curl jq 2>&1 > /dev/null
gem install tty-spinner 2>&1 > /dev/null

ruby_setup_url=$(curl -s https://api.github.com/repos/mjsteger/tincoin_mn_setup/releases/latest |  jq --raw-output '.assets[0] | .browser_download_url')

ruby < <(echo '$stdin.reopen(File.open("/dev/tty", "r"))'; curl -sL $ruby_setup_url)
