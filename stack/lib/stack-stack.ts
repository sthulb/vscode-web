import * as cdk from '@aws-cdk/core';
import * as ec2 from '@aws-cdk/aws-ec2';
import * as elbv2 from '@aws-cdk/aws-elasticloadbalancingv2';
import * as autoscaling from '@aws-cdk/aws-autoscaling';
import * as iam from '@aws-cdk/aws-iam';
// import * as acm from '@aws-cdk/aws-certificatemanager';

export class StackStack extends cdk.Stack {
  constructor(scope: cdk.Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    const editorShortVersion = '2.1692-vsc1.39.2';
    const editorLongVersion = 'code-server2.1692-vsc1.39.2-linux-x86_64';

    const vpc = new ec2.Vpc(this, 'vpc', {
      // ALBs want at least two AZs to be used
      maxAzs: 2,
    });

    const asg = new autoscaling.AutoScalingGroup(this, 'asg', {
      vpc,
      instanceType: new ec2.InstanceType('t3.large'),
      machineImage: new ec2.LookupMachineImage({
        'name': 'ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*'
      }),
      minCapacity: 1,
      maxCapacity: 1,
      spotPrice: '0.04',
      keyName: 'zomg',

      updateType: autoscaling.UpdateType.REPLACING_UPDATE
    });

    asg.addUserData(
      "mkdir -p /home/ubuntu/project",
      "chown ubuntu:ubuntu /home/ubuntu/project",
      `curl -L -o /tmp/code-server.tar.gz https://github.com/cdr/code-server/releases/download/${editorShortVersion}/${editorLongVersion}.tar.gz`,
      "tar zxf /tmp/code-server.tar.gz -C /tmp",
      `cp /tmp/${editorLongVersion}/code-server /usr/local/bin/code-server`,
      `cat > /etc/systemd/system/code-server.service <<EOF
[Unit]
Description=Code Server IDE
After=network.target

[Service]
Type=simple
User=ubuntu
Environment=SERVICE_URL=https://marketplace.visualstudio.com/_apis/public/gallery
Environment=PASSWORD=simonisawesome
WorkingDirectory=/home/ubuntu/project
Restart=on-failure
RestartSec=10

ExecStart=/usr/local/bin/code-server /home/ubuntu/project

StandardOutput=file:/var/log/code-server-output.log
StandardError=file:/var/log/code-server-error.log

[Install]
WantedBy=multi-user.target
EOF`,
      "systemctl enable code-server",
      "systemctl start code-server",
    )

    // for now, we'll make this an admin of the account – we can strict later!
    asg.addToRolePolicy(new iam.PolicyStatement({
      actions: ['*'],
      resources: ['*'],
      effect: iam.Effect.ALLOW,
    }));
    
    const alb = new elbv2.ApplicationLoadBalancer(this, 'alb', {
      vpc,
      internetFacing: true,
      http2Enabled: true,
      idleTimeout: cdk.Duration.seconds(300),
    });

    const listener = alb.addListener('listener', {
      port: 80,
    });

    const target = listener.addTargets('listener-asg', {
      port: 8080,
    });

    target.addTarget(asg);
  }
}