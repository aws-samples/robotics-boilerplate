# Robotics Boilerplate

This project provides an AWS CloudFormation template to spin up a preconfigured cloud-based desktop environment for Robotics development. It creates an EC2 instance using Ubuntu, with common robotics software such as ROS and Gazebo installed, and NICE DCV, so the Ubuntu Desktop can be accessed and the graphical interface to the simulations can be accessed. The Cloud9 will be available via the Shared with me enviroments.

## Installation

**STEP 1**: In the AWS Console for CloudFormation:
1. Click Create Stack
2. Select "Upload a Template file"
3. Click "Choose File" and upload c9-ros-nice-cfn.yaml
4. Click Next

**STEP 2**: Create a CloudFormation stack
1. Enter a stack name
2. Choose an instance type
3. Enter your Cloud9 User ARN\  
    This user will get access to the Cloud9 enviroment. For example:\  
    Federated user: arn:aws:sts::123456789012:assumed-role/RoleToBeAssumed/b@example.com\
    IAM user:       arn:aws:iam::123456789012:user/JohnDoe
4. Select a ROS Version to install
5. Click Next, then Next again
6. Check the box for "I acknowledge that AWS CloudFormation might create IAM resources with custom names."
7. Click Create Stack

Instance creation can take up to 30 minutes to complete.

**STEP 3**: Open Cloud9 environment
1. Once instance is created, go to Cloud9
2. you should see an environment named "RobotWorkshop-{stack name}"
3. Click "Open IDE"

**STEP 4**: Open Desktop GUI
1. Go to the Preview menu and select "Preview Running Application". This will open a new tab in Cloud9, which will be blank.
2. Click the link on the right hand side of the URL field next to the word "Browser", then "Pop Out Into New Window".

The GUI will be visible in the new browser tab.

## Support
* Nigel Gardiner: ngl@amazon.com
* Adi Singh: adsnghw@amazon.com

## Roadmap
Currently only **us-east-1** and **us-west-2** are supported regions. Contact the authors to get more regions added.

## Security
See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License
This library is licensed under the MIT-0 License. See the [LICENSE](LICENSE) file.
