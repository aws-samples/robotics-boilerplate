# Robotics Boilerplate

This project provides an AWS CloudFormation teomplate to sping up a preconfigured cloud-based desktop environment for Robotics development. It creates an EC2 instance using Ubuntu, with common robotics software such as ROS and Gazebo installed, and NICE DCV, so the Ubuntu Desktop can be accessed and the graphical interface to the simulations can be accessed.

## Installation

To create an environment, use Cloudformation.

1. In the AWS Console for Cloudformation:
1.1 Click Create Stack
1.2 Select "Upload a Template file"
1.3 Click "Choose File" and upload c9-ros-nice-cfn.yaml
1.4 Click Next

2. Create a CloudFormation stack
2.1Enter a stack name
2.2 Choose an instance type
2.3 Enter your Cloud9 Access Role ARN
2.4 Select a ROS Version to install
2.5 Click Next, then Next again
2.6 Check the box for "I acknowledge that AWS CloudFormation might create IAM resources with custom names."
2.7 Click Create Stack

Instance creation can take up to 30 minutes to complete.

3. Open Cloud9 environment
3.1 Once instance is created, go to Cloud9
3.2 you should see an environment named "RobotWorkshop-{stack name}"
3.3 Click "Open IDE"

4. Open Desktop GUI
4.1 Go to the Preview menu and select "Preview Running Application". This will open a new tab in Cloud9, which will be blank.
4.2 Click the link on the right hand side of the URL field next to the word "Browser", then "Pop Out Into New Window". The GUI will be visible in the new browser tab.

## Support
* Nigel Gardiner: ngl@amazon.com
* Adi Singh: adsnghw@amazon.com

## Roadmap
Currently only **us-east-1** and **us-west-2** are supported regions. Contact the authors to get more regions added.

## Security
See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License
This library is licensed under the MIT-0 License. See the [LICENSE](LICENSE) file.
