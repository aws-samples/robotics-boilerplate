#!/bin/bash

if [ ${SIMULATOR} == "Gazebo" ]; then
# Install Gazebo models
wget https://d3lm3wzny7xda7.cloudfront.net/models.tar
mkdir /home/ubuntu/.gazebo
tar -xvf models.tar -C ~ubuntu/.gazebo/
chown -R ubuntu:ubuntu /home/ubuntu/.gazebo
elif [ ${SIMULATOR} == "Carla" ]; then
# Install Carla
apt install -y libomp5
pip install --user pygame numpy
pip3 install --user pygame numpy
sudo apt install -y libglfw3 libglfw3-dev libjpeg-dev libtiff5-dev libomp-dev fontconfig wget pgp
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 1AF1527DE64CB8D9
sudo add-apt-repository "deb [arch=amd64] http://dist.carla.org/carla $(lsb_release -sc) main"
sudo apt-get update # Update the Debian package index
sudo apt-get install -y carla-simulator # Install the latest CARLA version, or update the current installation
pip3 install carla # Install the CARLA client
cd /opt/carla-simulator # Open the folder where CARLA is installed
# Add the extra assets
wget https://carla-releases.s3.eu-west-3.amazonaws.com/Linux/AdditionalMaps_0.9.13.tar.gz
./ImportAssets.sh
else
echo "No Simulator"
fi
