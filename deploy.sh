#!/bin/sh
sleep 1
git pull
~/.local/bin/mkdocs build
sudo cp -r site/* /srv/router-lab-docs/
