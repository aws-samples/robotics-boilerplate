#!/bin/bash -v

cd /home/ubuntu

# install_python_and_pip
apt-get install -y python python-dev python-pip python3 python3-dev python3-pip python2.7

# update_pip_and_boto
pip3 install --upgrade pip boto3 botocore requests

cat -  << 'EOFPY' > registercloud9.py
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

def sigv4_request(amz_target, req_param, region, creds):
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
    canon_uri = '/'
    canon_querystring = ''
    canon_hdrs = 'content-type:' + content_type + '\n' + 'host:' + host + '\n' + 'x-amz-date:' + amz_date + '\n' + 'x-amz-target:' + amz_target + '\n'
    signed_hdrs = 'content-type;host;x-amz-date;x-amz-target'
    payload_hash = hashlib.sha256(req_param.encode('utf-8')).hexdigest()
    canon_request = method + '\n' + canon_uri + '\n' + canon_querystring + '\n' + canon_hdrs + '\n' + signed_hdrs + '\n' + payload_hash
    algorithm = 'AWS4-HMAC-SHA256'
    credential_scope = date_stamp + '/' + region + '/' + service + '/' + 'aws4_request'
    string_to_sign = algorithm + '\n' +  amz_date + '\n' +  credential_scope + '\n' +  hashlib.sha256(canon_request.encode('utf-8')).hexdigest()
    signing_key = getSignatureKey(creds.secret_key, date_stamp, region, service)
    signature = hmac.new(signing_key, (string_to_sign).encode('utf-8'), hashlib.sha256).hexdigest()

    authorization_hdr = algorithm + ' ' + 'Credential=' + creds.access_key + '/' + credential_scope + ', ' +  'SignedHeaders=' + signed_hdrs + ', ' + 'Signature=' + signature
    hdrs = {
                'Content-Type':content_type,
                'X-Amz-Date':amz_date,
                'X-Amz-Target':amz_target,
                'Content-Length': '2',
                'Accept-Encoding': 'identity',
                'User-Agent': 'custom',
                'Authorization':authorization_hdr
              }

    if (creds.token) is not None:
        hdrs['x-amz-security-token'] = creds.token

    return requests.post(endpoint, data=req_param, headers=hdrs)

def write_c9_pub_key(pub_key):
    file1 = open("/home/ubuntu/.ssh/authorized_keys", "a") # append
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

    opsArn = ""
    if("default" == os.getenv('ROLE_ARN', 'default')):
      userArn = 'arn:aws:sts::'+account_id+':assumed-role/TeamRole/MasterKey'
      opsArn = 'arn:aws:sts::'+account_id+':assumed-role/OpsRole/MasterKey'
    elif os.getenv('ROLE_ARN', 'default').find(":") == -1:
      userArn = 'arn:aws:sts::'+account_id+':assumed-role/'+os.getenv('ROLE_ARN')+'/Participant'
    else:
      userArn = os.getenv('ROLE_ARN')

    amz_target = 'AWSCloud9WorkspaceManagementService.GetUserPublicKey'
    req_param = '{"userArn": "'+userArn+'"}'

    r = sigv4_request(amz_target, req_param, region, credentials)
    print(r.text)
    response = json.loads(r.text)
    write_c9_pub_key(response['publicKey'])
    print("Public key written.")

    time.sleep(5)

    amz_target = 'AWSCloud9WorkspaceManagementService.CreateEnvironmentSSH'
    req_param =  '{'
    req_param +=  '"name":"'+os.getenv('ENVIRONMENT_NAME', default = 'cloud-dev-'+uuid.uuid4().hex)+'",'
    req_param +=  '"host":"'+hostname+'",'
    req_param +=  '"ownerArn":"'+userArn+'",'
    req_param +=  '"port":22,'
    req_param +=  '"loginName":"'+os.getenv('LOGIN_NAME', default = 'ubuntu')+'",'
    req_param +=  '"environmentPath":"'+os.getenv('ENVIRONMENT_PATH', default = '~/environment')+'"'
    req_param +=  '}'
    print (req_param)

    r = sigv4_request(amz_target, req_param, region, credentials)
    print(r.text)
    environment = json.loads(r.text)["environmentId"]

    amz_target = 'AWSCloud9WorkspaceManagementService.CreateEnvironmentMembership'
    req_param = '{'
    req_param +=  '"environmentId":"'+environment+'",'
    req_param +=  '"userArn":"'+userArn+'",'
    req_param +=  '"permissions":"read-write"'
    req_param += '}'
    print (req_param)

    r = sigv4_request(amz_target, req_param, region, credentials)
    print(r.text)

    if("" != opsArn):
        amz_target = 'AWSCloud9WorkspaceManagementService.CreateEnvironmentMembership'
        req_param = '{'
        req_param +=  '"environmentId":"'+environment+'",'
        req_param +=  '"userArn":"'+opsArn+'",'
        req_param +=  '"permissions":"read-write"'
        req_param += '}'
        print (req_param)
        r = sigv4_request(amz_target, req_param, region, credentials)
        print(r.text)

    desktop_url = "http://"+environment+".vfs.cloud9."+region+".amazonaws.com/"
    print(desktop_url)

    write_c9_settings({
        "@url": desktop_url
    })

    write_instructions_file(desktop_url)

EOFPY

cd /home/ubuntu

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
{ "configurations": [] }
EOF
sudo -u ubuntu cat << EOF > ./environment/.c9/project.settings
{
    "language": { "tern_defs": { "json()": { "browser": { "enabled": true }, "ecma5": { "enabled": true }, "jQuery": { "enabled": true } } } }, "launchconfigurations": { "@currentconfig": "" }, "python": { "@path": "/usr/local/lib/python3.4/dist-packages:/usr/local/lib/python3.5/dist-packages" }, "run": { "configs": { "@inited": "true", "json()": {} } }, "welcome": { "@first": true } }
EOF
echo '{"@syncProjectSettings": false}' > '/home/ubuntu/.c9/user.settings'  || true
chown ubuntu:ubuntu -R ./environment/.c9

# Register to Cloud9
sudo su -l ubuntu -c 'echo "{}" > /home/ubuntu/environment/.c9/project.settings'
sudo su -l ubuntu -c "ROLE_ARN=${ROLENAME} ENVIRONMENT_NAME=RobotWorkshop-${STACKNAME} python3 registercloud9.py"
