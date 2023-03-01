#!/bin/bash

apt-get install -y gcc make linux-headers-$(uname -r)
cat << EOF | tee --append /etc/modprobe.d/blacklist.conf
blacklist vga16fb
blacklist nouveau
blacklist rivafb
blacklist nvidiafb
blacklist rivatv
EOF
echo 'GRUB_CMDLINE_LINUX="rdblacklist=nouveau"' | tee -a /etc/default/grub
update-grub
aws s3 cp --recursive s3://nvidia-gaming/linux/latest/ .
export DRIVERZIP=`ls -1 *Linux-Guest-Drivers.zip | tail -1`
unzip $DRIVERZIP
chmod +x NVIDIA-Linux-x86_64*.run
./NVIDIA-Linux-x86_64*.run --silent
cat << EOF | tee -a /etc/nvidia/gridd.conf
vGamingMarketplace=2
EOF
curl -o /etc/nvidia/GridSwCert.txt "https://nvidia-gaming.s3.amazonaws.com/GridSwCert-Archive/GridSwCertLinux_2021_10_2.cert"
line='WaylandEnable=false'; sed -i "/^#$line/ c$line" /etc/gdm3/custom.conf
systemctl restart gdm3
apt install mesa-utils -y
nvidia-xconfig --preserve-busid --enable-all-gpus --connected-monitor=DFP-0,DFP-1,DFP-2,DFP-3
