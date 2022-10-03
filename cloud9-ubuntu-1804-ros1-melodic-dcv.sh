#!/bin/bash -v

# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

# Intended for running in a Cloud9 environment, to install ROS1 Melodic and NICE DCV.

# log_to_/var/log/user-data.log
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
sleep 10
apt-get update && apt-get upgrade -y linux-aws && apt upgrade -y

# Resize Cloud9 Volume

SIZE=20 # Change from the default 8GB to 20GB

# Get the ID of the environment host Amazon EC2 instance.
INSTANCEID=$(curl http://169.254.169.254/latest/meta-data/instance-id)
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/\(.*\)[a-z]/\1/')

# Get the ID of the Amazon EBS volume associated with the instance.
VOLUMEID=$(aws ec2 describe-instances \
  --instance-id $INSTANCEID \
  --query "Reservations[0].Instances[0].BlockDeviceMappings[0].Ebs.VolumeId" \
  --output text \
  --region $REGION)

# Resize the EBS volume.
aws ec2 modify-volume --volume-id $VOLUMEID --size $SIZE

# Wait for the resize to finish.
while [ \
  "$(aws ec2 describe-volumes-modifications \
    --volume-id $VOLUMEID \
    --filters Name=modification-state,Values="optimizing","completed" \
    --query "length(VolumesModifications)"\
    --output text)" != "1" ]; do
sleep 1
done

#Check if we're on an NVMe filesystem
if [[ -e "/dev/xvda" && $(readlink -f /dev/xvda) = "/dev/xvda" ]]
then
  # Rewrite the partition table so that the partition takes up all the space that it can.
  sudo growpart /dev/xvda 1

  # Expand the size of the file system.
  # Check if we're on AL2
  STR=$(cat /etc/os-release)
  SUB="VERSION_ID=\"2\""
  if [[ "$STR" == *"$SUB"* ]]
  then
    sudo xfs_growfs -d /
  else
    sudo resize2fs /dev/xvda1
  fi

else
  # Rewrite the partition table so that the partition takes up all the space that it can.
  sudo growpart /dev/nvme0n1 1

  # Expand the size of the file system.
  # Check if we're on AL2
  STR=$(cat /etc/os-release)
  SUB="VERSION_ID=\"2\""
  if [[ "$STR" == *"$SUB"* ]]
  then
    sudo xfs_growfs -d /
  else
    sudo resize2fs /dev/nvme0n1p1
  fi
fi

cd /home/ubuntu

# runUpdateCommand
apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::=''--force-confdef'' -o Dpkg::Options::=''--force-confold'' dist-upgrade -y

# installAWSCLI
apt-get install -y python3 python3-dev python3-pip && pip3 install --upgrade awscli

# install_https_support
apt-get install -y apt-transport-https ca-certificates curl software-properties-common

# install_build_essentials
apt-get install -y build-essential

# configure_swap_file
#fallocate -l 512MB /var/swapfile && sudo chmod 600 /var/swapfile && sudo mkswap /var/swapfile && echo '/var/swapfile swap swap defaults 0 0' >> /etc/fstab

# configure_unattended_upgrades
sed -i 's|//Unattended-Upgrade::InstallOnShutdown "true";|Unattended-Upgrade::InstallOnShutdown "true";|' /etc/apt/apt.conf.d/50unattended-upgrades

# install_ubuntu_desktop_and_lightdm
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ubuntu-desktop lightdm

# install_desktop_utilities
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends firefox xterm

# enable_automatic_login_and_disable_lock_screen
sed -i 's/^#  AutomaticLogin/AutomaticLogin/' /etc/gdm3/custom.conf
sed -i 's/user1/ubuntu/' /etc/gdm3/custom.conf
sudo su -l ubuntu -c "dbus-launch gsettings set org.gnome.desktop.screensaver idle-activation-enabled 'false'"
sudo su -l ubuntu -c "dbus-launch gsettings set org.gnome.desktop.screensaver lock-enabled 'false'"
sudo su -l ubuntu -c "dbus-launch gsettings set org.gnome.desktop.lockdown disable-lock-screen 'true'"
sudo su -l ubuntu -c "dbus-launch gsettings set org.gnome.desktop.session idle-delay 0"

# get_dcv_pkg
wget https://d1uj6qtbmh3dt5.cloudfront.net/2020.1/Servers/nice-dcv-2020.1-9012-ubuntu1804-x86_64.tgz && echo "7569c95465743b512f1ab191e58ea09777353b401c1ec130ee8ea344e00f8900 nice-dcv-2020.1-9012-ubuntu1804-x86_64.tgz" | sha256sum -c && tar -xvzf nice-dcv-2020.1-9012-ubuntu1804-x86_64.tgz && rm nice-dcv-2020.1-9012-ubuntu1804-x86_64.tgz

# install_dcv
cd nice-dcv-2020.1-9012-ubuntu1804-x86_64 && DEBIAN_FRONTEND=noninteractive apt-get install -y ./nice-dcv-server_2020.1.9012-1_amd64.ubuntu1804.deb ./nice-xdcv_2020.1.338-1_amd64.ubuntu1804.deb
cd /home/ubuntu

# create_dcv_conf
cat << 'EOF' > ./dcv.conf 
[license] 
[log] 
[display] 
[connectivity] 
web-port=8080 
web-use-https=false 
[security] 
authentication="none" 
EOF

# mv_dcv_conf
mv ./dcv.conf /etc/dcv/dcv.conf

# install_python_and_pip
apt-get install -y python python-dev python-pip python3 python3-dev python3-pip python2.7

# update_pip_and_boto
pip3 install --upgrade pip boto3 botocore requests

# enable usb
/usr/bin/dcvusbdriverinstaller --quiet

# setup_cloud9
chmod u=rwx,g=rx,o=rx /home/ubuntu
curl -sL https://deb.nodesource.com/setup_14.x | sudo -E bash -
sudo apt update
sudo apt install -y nodejs
sudo su -l ubuntu -c 'mkdir -p /home/ubuntu/environment/.c9/'
runuser -l ubuntu -c 'curl -L https://raw.githubusercontent.com/c9/install/master/install.sh | bash'
sudo -u ubuntu cat << EOF > ./environment/.c9/.nakignore
*~backup-*
.c9revisions
.c9
.git
.svn
.DS_Store
.bzr
.cdv
~.dep
~.dot
~.nib
~.plst
.hg
.pc
*.min.js
.nakignore
/dev
EOF
sudo -u ubuntu cat << EOF > ./environment/.c9/launch.json
{
    "configurations": []
}
EOF
sudo -u ubuntu cat << EOF > ./environment/.c9/project.settings
{
    "language": {
        "tern_defs": {
            "json()": {
                "browser": {
                    "enabled": true
                },
                "ecma5": {
                    "enabled": true
                },
                "jQuery": {
                    "enabled": true
                }
            }
        }
    },
    "launchconfigurations": {
        "@currentconfig": ""
    },
    "python": {
        "@path": "/usr/local/lib/python3.4/dist-packages:/usr/local/lib/python3.5/dist-packages"
    },
    "run": {
        "configs": {
            "@inited": "true",
            "json()": {}
        }
    },
    "welcome": {
        "@first": true
    }
}
EOF
echo '{"@syncProjectSettings": false}' > '/home/ubuntu/.c9/user.settings'  || true
chown ubuntu:ubuntu -R ./environment/.c9

# install_ros_melodic
cd /home/ubuntu
git clone https://github.com/aws-robotics/aws-robomaker-sample-application-helloworld.git -b ros1 && cd aws-robomaker-sample-application-helloworld/ && bash -c scripts/setup.sh --install-ros melodic
cd /home/ubuntu
rm -rf aws-robomaker-sample-application-helloworld/
echo "[[ -e /opt/ros/melodic/setup.sh ]] && source /opt/ros/melodic/setup.sh" >> /home/ubuntu/.bashrc
chown -R ubuntu:ubuntu /home/ubuntu/.ros

# Install Gazebo models
wget https://d3lm3wzny7xda7.cloudfront.net/models.tar
mkdir /home/ubuntu/.gazebo
tar -xvf models.tar -C ~ubuntu/.gazebo/
chown -R ubuntu:ubuntu /home/ubuntu/.gazebo

# install_docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get -y install docker-ce docker-ce-cli containerd.io

# Configure DCV Session
sudo su -l ubuntu -c dbus-launch gsettings set org.gnome.shell enabled-extensions "['ubuntu-dock@ubuntu.com']"
/sbin/iptables -A INPUT -p tcp ! -s localhost --dport 8080 -j DROP
systemctl start dcvserver
systemctl enable dcvserver

# Create service to launch DCV Session on server restart
cat << 'EOF' > /etc/systemd/system/dcvsession.service
[Unit]
Description=NICE DCV Session
After=dcvserver.service

[Service]
User=ubuntu
ExecStart=/usr/bin/dcv create-session cloud9-session --owner ubuntu
#ExecStop=/usr/bin/dcv close-session cloud9-session --owner ubuntu

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable dcvsession
sudo systemctl start dcvsession

