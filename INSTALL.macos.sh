#!/bin/bash

# install prereqs via brew
brew install pandoc python3 wkhtmltopdf

# install graphviz, force link
brew install graphviz
brew link --overwrite graphviz

# get plantuml (copy checked in here)
wget 'https://netix.dl.sourceforge.net/project/plantuml/plantuml.jar'

# install openjdk
brew install openjdk

# update python libs
sudo pip3 install dtreeviz
sudo pip3 install pyDAL

# build pytm
make
