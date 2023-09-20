#!/bin/bash -v

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

# Intended for running in a Cloud9 environment, to install ROS2 Humble and NICE DCV on Ubuntu 22.04

# log_to_/var/log/user-data.log
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
sleep 10
apt-get update && apt-get upgrade -y linux-aws && apt upgrade -y


# install_python_and_pip
apt-get install -y python python-dev python-pip python3 python3-dev python3-pip python2.7

# update_pip_and_boto
pip3 install --upgrade pip boto3 botocore requests


export ROSVERSION="ROS2Humble"
export SIMULATORS="Gazebo"

### 1. Resize Cloud9 Volume
wget https://raw.githubusercontent.com/aws-samples/robotics-boilerplate/main/install-resize.sh
bash ./install-resize.sh

### 2. Install Desktop
wget https://raw.githubusercontent.com/aws-samples/robotics-boilerplate/main/install-desktop.sh
bash ./install-desktop.sh

### 3. DCV
wget https://raw.githubusercontent.com/aws-samples/robotics-boilerplate/main/install-dcv.sh
bash ./install-dcv.sh

### 4. ROS
wget https://raw.githubusercontent.com/aws-samples/robotics-boilerplate/main/install-ros.sh
bash ./install-ros.sh

### 5. INSTALL DOCKER
wget https://raw.githubusercontent.com/aws-samples/robotics-boilerplate/main/install-docker.sh
bash ./install-docker.sh
