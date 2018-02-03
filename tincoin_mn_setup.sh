#!/bin/bash

echo "Installing script dependencies, please wait..."

sudo apt-get install -y ruby curl 2>&1 > /dev/null
gem install tty-spinner 2>&1 > /dev/null

curl tinfaucet.com/install_tin_mn.rb | ruby
