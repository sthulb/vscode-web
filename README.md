# VSCode Web

The main of this project is create a singular EC2 instance to host `code-server` by [coder.com](https:/coder.com) https://github.com/cdr/code-server

This project uses [AWS CDK](https://github.com/aws/aws-cdk) to create the infrastructure:
  - VPC
  - AutoScalingGroup
  - Application Load Balancer

## Getting started
### AMI
Unfortunately, EC2 ImageBuilder doesn't have CFN support, we need to do a lot by hand here 😭
There's a bunch of components that will install everything needed for my install of code-server.

1. Set `AWS_REGION` to whatever region you want to use
1. export `AWS_*` environment variables or configure the AWS CLI
1. run `./build.sh`

### Infrastructure
1. Install the AWS CDK (https://docs.aws.amazon.com/cdk/latest/guide/getting_started.html) as specified.
1. Set `CDK_DEFAULT_REGION`, `CDK_DEFAULT_ACCOUNT` environment variables with their obvious values
1. Set `INST_COUNT` environment variable with how many standalone editors you want
1. From the `stack` directory, run `cdk deploy`

## Support
This project exists as an education project and isn't setup to be deployed to production.

Please submit your questions, feature requests, and bug reports on [GitHub issues](https://github.com/sthulb/appconfig-demo/issues) page.


## How to Contribute
We welcome community contributions to ML-IO. Please read our [Contributing Guidelines](CONTRIBUTING.md) to learn more.


## License
This project is licensed under the Apache-2.0 License.