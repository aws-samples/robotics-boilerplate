#!/bin/bash -v

cd /home/ubuntu

# runUpdateCommand
apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::=''--force-confdef'' -o Dpkg::Options::=''--force-confold'' dist-upgrade -y

# installAWSCLI
apt-get install -y python3 python3-dev python3-pip
pip3 install --upgrade awscli
# update_pip_and_boto
pip3 install --upgrade pip boto3 requests

# install_https_support
apt-get install -y apt-transport-https ca-certificates curl software-properties-common

# install_build_essentials
apt-get install -y build-essential

# configure_swap_file
fallocate -l 512MB /var/swapfile && sudo chmod 600 /var/swapfile && sudo mkswap /var/swapfile && echo '/var/swapfile swap swap defaults 0 0' >> /etc/fstab

# configure_unattended_upgrades
sed -i 's|//Unattended-Upgrade::InstallOnShutdown "true";|Unattended-Upgrade::InstallOnShutdown "true";|' /etc/apt/apt.conf.d/50unattended-upgrades

# install_ubuntu_desktop_and_desktop_manager
if [ ${ROSVERSION} == "ROS1Melodic" ] || [ ${ROSVERSION} == "NoROSUbuntu1804" ]; then
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ubuntu-desktop lightdm
else
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ubuntu-desktop gdm3
sed -i "s/^#WaylandEnable=false/WaylandEnable=false/g" /etc/gdm3/custom.conf
fi

# install_desktop_utilities
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends firefox xterm

# enable_automatic_login_and_disable_lock_screen
sed -i 's/^#  AutomaticLogin/AutomaticLogin/' /etc/gdm3/custom.conf
sed -i 's/user1/ubuntu/' /etc/gdm3/custom.conf
sudo su -l ubuntu -c "dbus-launch gsettings set org.gnome.desktop.screensaver idle-activation-enabled 'false'"
sudo su -l ubuntu -c "dbus-launch gsettings set org.gnome.desktop.screensaver lock-enabled 'false'"
sudo su -l ubuntu -c "dbus-launch gsettings set org.gnome.desktop.lockdown disable-lock-screen 'true'"
sudo su -l ubuntu -c "dbus-launch gsettings set org.gnome.desktop.session idle-delay 0"

# install_python_2.7_for_cloud9
apt-get install -y python python-dev

# fix permissions
chown -R ubuntu:ubuntu /home/ubuntu/.local

# Remove the updates notifier
rm /var/lib/update-notifier/updates-available
