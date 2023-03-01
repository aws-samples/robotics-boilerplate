#!/bin/bash -v

cd /home/ubuntu
if [ ${ROSVERSION} == "ROS1Melodic" ]; then
echo Installing ROS Melodic
git clone https://github.com/aws-robotics/aws-robomaker-sample-application-helloworld.git -b ros1 && cd aws-robomaker-sample-application-helloworld/ && bash -c scripts/setup.sh --install-ros melodic
cd /home/ubuntu
rm -rf aws-robomaker-sample-application-helloworld/
echo "[[ -e /opt/ros/melodic/setup.sh ]] && source /opt/ros/melodic/setup.sh" >> /home/ubuntu/.bashrc
elif [ ${ROSVERSION} == "ROS1Noetic" ]; then
echo Installing ROS Noetic
sudo sh -c 'echo "deb http://packages.ros.org/ros/ubuntu $(lsb_release -sc) main" > /etc/apt/sources.list.d/ros-latest.list'
curl -s https://raw.githubusercontent.com/ros/rosdistro/master/ros.asc | sudo apt-key add -
sudo apt update
apt install ros-noetic-desktop-full -y
apt install python3-rosdep python3-rosinstall python3-rosinstall-generator python3-wstool build-essential python3-colcon-common-extensions -y
sudo su -l ubuntu -c "sudo rosdep init"
sudo su -l ubuntu -c "rosdep update"
echo "[[ -e /opt/ros/noetic/setup.bash ]] && source /opt/ros/noetic/setup.bash" >> /home/ubuntu/.bashrc
elif [ ${ROSVERSION} == "ROS2Foxy" ]; then
sudo apt update && sudo apt install curl gnupg2 lsb-release
sudo curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key  -o /usr/share/keyrings/ros-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(source /etc/os-release && echo $UBUNTU_CODENAME) main" | sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null
sudo apt update
sudo apt install -y ros-foxy-desktop
echo "[[ -e /opt/ros/foxy/setup.bash ]] && source /opt/ros/foxy/setup.bash" >> /home/ubuntu/.bashrc
else
echo "No ROS"
fi

chown -R ubuntu:ubuntu /home/ubuntu/.ros
