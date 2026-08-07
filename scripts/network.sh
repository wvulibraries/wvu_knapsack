#!/bin/bash

sudo mkdir -p /Volumes/hyku_imports
sudo chown root:wheel /Volumes/hyku_imports
sudo chmod 755 /Volumes/hyku_imports
sudo mount -t nfs -o vers=3,resvport,tcp,nolocks data.vastdr.lib.wvu.edu:/hyku/hyku_imports /Volumes/hyku_imports