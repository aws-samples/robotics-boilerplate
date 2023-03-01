#!/bin/bash -v

# Installs NICE DCV, ROS Melodic, Gazebo and registers to Cloud9

exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
sleep 10
apt-get update && apt-get upgrade -y linux-aws && apt upgrade -y
if [ -f /var/run/reboot-required ]; then
  rm -f /var/lib/cloud/instances/*/sem/config_scripts_user
  echo rebooting ... $(date)
  reboot
  exit
fi
cd /home/ubuntu
cat -  << 'EOFPY' > registercloud9.py
'''
This script self-registers an EC2 instance on boot with Cloud9 as an SSH-based host. 
'''

import sys, os, base64, datetime, hashlib, hmac, json, boto3, uuid, time
import requests # pip install requests
from botocore.utils import InstanceMetadataFetcher
from botocore.credentials import InstanceMetadataProvider

def sign(key, msg):
    return hmac.new(key, msg.encode("utf-8"), hashlib.sha256).digest()

def getSignatureKey(key, date_stamp, regionName, serviceName):
    kDate = sign(('AWS4' + key).encode('utf-8'), date_stamp)
    kRegion = sign(kDate, regionName)
    kService = sign(kRegion, serviceName)
    kSigning = sign(kService, 'aws4_request')
    return kSigning

def sigv4_request(amz_target, request_parameters, region, creds):
    method = 'POST'
    service = 'cloud9'
    host = service+'.'+region+'.amazonaws.com'
    endpoint = 'https://'+host
    content_type = 'application/x-amz-json-1.1'

    if creds.access_key is None or creds.secret_key is None:
        print('No access key is available.')
        sys.exit()

    t = datetime.datetime.utcnow()
    amz_date = t.strftime('%Y%m%dT%H%M%SZ')
    date_stamp = t.strftime('%Y%m%d')
    canonical_uri = '/'
    canonical_querystring = ''
    canonical_headers = 'content-type:' + content_type + '\n' + 'host:' + host + '\n' + 'x-amz-date:' + amz_date + '\n' + 'x-amz-target:' + amz_target + '\n'
    signed_headers = 'content-type;host;x-amz-date;x-amz-target'
    payload_hash = hashlib.sha256(request_parameters.encode('utf-8')).hexdigest()
    canonical_request = method + '\n' + canonical_uri + '\n' + canonical_querystring + '\n' + canonical_headers + '\n' + signed_headers + '\n' + payload_hash
    algorithm = 'AWS4-HMAC-SHA256'
    credential_scope = date_stamp + '/' + region + '/' + service + '/' + 'aws4_request'
    string_to_sign = algorithm + '\n' +  amz_date + '\n' +  credential_scope + '\n' +  hashlib.sha256(canonical_request.encode('utf-8')).hexdigest()
    signing_key = getSignatureKey(creds.secret_key, date_stamp, region, service)
    signature = hmac.new(signing_key, (string_to_sign).encode('utf-8'), hashlib.sha256).hexdigest()
    
    authorization_header = algorithm + ' ' + 'Credential=' + creds.access_key + '/' + credential_scope + ', ' +  'SignedHeaders=' + signed_headers + ', ' + 'Signature=' + signature
    headers = {
                'Content-Type':content_type,
                'X-Amz-Date':amz_date,
                'X-Amz-Target':amz_target,
                'Content-Length': '2',
                'Accept-Encoding': 'identity',
                'User-Agent': 'custom',
                'Authorization':authorization_header
              }
            
    if (creds.token) is not None:
        headers['x-amz-security-token'] = creds.token
    
    return requests.post(endpoint, data=request_parameters, headers=headers)

def get_c9_pub_key(pub_key):
    file1 = open("/home/ubuntu/.ssh/authorized_keys", "a")  # append mode
    file1.write(pub_key)
    file1.close()

def write_c9_settings(new_data, filename='/home/ubuntu/environment/.c9/project.settings'):
    with open(filename,'r+') as file:
        file_data = json.load(file)
        file_data["preview"] = new_data
        file.seek(0)
        json.dump(file_data, file, indent = 4)

def write_instructions_file(URL):
    f = open("/home/ubuntu/environment/instructions-to-open-virtual-desktop.txt", "w")
    f.write("Opening the Ubuntu Virtual Desktop.  \n \n"+
            "Open a **new** browser tab or window and paste the following URL into the address bar: \n \n"+URL+"\n")
    f.close()   


if __name__ == "__main__":

    r = requests.get('http://169.254.169.254/latest/dynamic/instance-identity/document')
    instance_details = json.loads(r.text)
    region = instance_details['region']
    account_id = instance_details['accountId']

    r = requests.get('http://169.254.169.254/latest/meta-data/public-hostname')
    hostname = r.text
    print("Hostname: "+hostname)

    session = boto3.Session()
    credentials = session.get_credentials()

    amz_target = 'AWSCloud9WorkspaceManagementService.GetUserPublicKey'
    request_parameters =  '{}'
    if("default" != os.getenv('ROLE_ARN', 'default')):
        request_parameters = '{"userArn": "'+os.getenv('ROLE_ARN')+'"}'
    
    r = sigv4_request(amz_target, request_parameters, region, credentials)
    response = json.loads(r.text)
    get_c9_pub_key(response['publicKey'])
    print("Public key written.")

    time.sleep(5)
    
    amz_target = 'AWSCloud9WorkspaceManagementService.CreateEnvironmentSSH'
    request_parameters =  '{'
    request_parameters +=  '"name":"'+os.getenv('ENVIRONMENT_NAME', default = 'cloud-dev-'+uuid.uuid4().hex)+'",'
    request_parameters +=  '"host":"'+hostname+'",'
    request_parameters +=  '"ownerArn":"'+os.getenv('ROLE_ARN', default = 'arn:aws:sts::'+account_id+':assumed-role/TeamRole/MasterKey')+'",'
    request_parameters +=  '"port":22,'
    request_parameters +=  '"loginName":"'+os.getenv('LOGIN_NAME', default = 'ubuntu')+'",'
    request_parameters +=  '"environmentPath":"'+os.getenv('ENVIRONMENT_PATH', default = '~/environment')+'"'
    request_parameters +=  '}'
    print (request_parameters)
    
    r = sigv4_request(amz_target, request_parameters, region, credentials)
    print(r.text)
    environment = json.loads(r.text)["environmentId"]

    amz_target = 'AWSCloud9WorkspaceManagementService.CreateEnvironmentMembership'
    request_parameters = '{'
    request_parameters +=  '"environmentId":"'+environment+'",'
    request_parameters +=  '"userArn":"'+os.getenv('ROLE_ARN', default = 'arn:aws:sts::'+account_id+':assumed-role/TeamRole/MasterKey')+'",'
    request_parameters +=  '"permissions":"read-write"'
    request_parameters += '}'
    print (request_parameters)

    r = sigv4_request(amz_target, request_parameters, region, credentials)
    print(r.text)

    if("default" == os.getenv('ROLE_ARN', 'default')):
        amz_target = 'AWSCloud9WorkspaceManagementService.CreateEnvironmentMembership'
        request_parameters = '{'
        request_parameters +=  '"environmentId":"'+environment+'",'
        request_parameters +=  '"userArn":"'+os.getenv('ROLE_ARN', default = 'arn:aws:sts::'+account_id+':assumed-role/OpsRole/MasterKey')+'",'
        request_parameters +=  '"permissions":"read-write"'
        request_parameters += '}'
        print (request_parameters)

    r = sigv4_request(amz_target, request_parameters, region, credentials)
    print(r.text)

    desktop_url = "http://"+environment+".vfs.cloud9."+region+".amazonaws.com/"
    print(desktop_url)

    write_c9_settings({
        "@url": desktop_url
    })

    write_instructions_file(desktop_url)

EOFPY

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
fallocate -l 512MB /var/swapfile && sudo chmod 600 /var/swapfile && sudo mkswap /var/swapfile && echo '/var/swapfile swap swap defaults 0 0' >> /etc/fstab

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

#wget https://d1uj6qtbmh3dt5.cloudfront.net/nice-dcv-ubuntu1804-x86_64.tgz && \
#tar -xvzf nice-dcv-ubuntu1804-x86_64.tgz && \
#rm nice-dcv-ubuntu1804-x86_64.tgz

# install_dcv
cd nice-dcv-2020.1-9012-ubuntu1804-x86_64 && \
DEBIAN_FRONTEND=noninteractive apt-get install -y \
./nice-dcv-server_2020.1.9012-1_amd64.ubuntu1804.deb \
./nice-xdcv_2020.1.338-1_amd64.ubuntu1804.deb

#cd nice-dcv*ubuntu1804-x86_64 && \
#DEBIAN_FRONTEND=noninteractive apt-get install -y \
#./nice-dcv-server_*.ubuntu1804.deb \
#./nice-xdcv_*.ubuntu1804.deb \
#./nice-dcv-web-viewer_*.deb \
#./nice-dcv-gl_*amd64.ubuntu1804.deb

usermod -aG video dcv

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
apt-get install -y python python-dev python-pip python3 python3-dev python3-pip

# update_pip_and_boto
pip3 install --upgrade pip boto3

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
usermod -aG docker ubuntu


# Register to Cloud9
sudo su -l ubuntu -c 'echo "{}" > /home/ubuntu/environment/.c9/project.settings'
sudo su -l ubuntu -c "ROLE_ARN=${Cloud9AccessRoleName} ENVIRONMENT_NAME=RobotWorkshop-${AWS::StackName} python3 registercloud9.py"
rm /home/ubuntu/registercloud9.py

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

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable dcvsession
sudo systemctl start dcvsession

# Remove the updates notifier
rm /var/lib/update-notifier/updates-available

# Reboot for all changes to take effect
reboot
