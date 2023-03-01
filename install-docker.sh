#!/bin/bash -v

curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
# add user to docker group so sudo isn't needed
sudo groupadd docker
sudo usermod -aG docker ubuntu
