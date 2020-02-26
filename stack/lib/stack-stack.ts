import * as cdk from '@aws-cdk/core';
import * as ec2 from '@aws-cdk/aws-ec2';
import * as elbv2 from '@aws-cdk/aws-elasticloadbalancingv2';
import * as autoscaling from '@aws-cdk/aws-autoscaling';
import * as iam from '@aws-cdk/aws-iam';
// import * as acm from '@aws-cdk/aws-certificatemanager';

import * as process from 'process';

export class StackStack extends cdk.Stack {
  constructor(scope: cdk.Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    const vpc = new ec2.Vpc(this, 'vpc', {
      // ALBs want at least two AZs to be used
      maxAzs: 2,
    });

    const account = process.env.CDK_DEFAULT_ACCOUNT || "zomg";
    const count = process.env.INST_COUNT || 1;

    for (let i=0; i < count; i++) {
      const asg = new autoscaling.AutoScalingGroup(this, `asg-${i}`, {
        vpc,
        instanceType: new ec2.InstanceType('t3.xlarge'),
        machineImage: new ec2.LookupMachineImage({
          name: 'code-server *',
          owners: [ account ],
        }),
        minCapacity: 1,
        maxCapacity: 1,
        // keyName: 'zomg',

        updateType: autoscaling.UpdateType.REPLACING_UPDATE
      });

      // for now, we'll make this an admin of the account – we can strict later!
      asg.addToRolePolicy(new iam.PolicyStatement({
        actions: ['*'],
        resources: ['*'],
        effect: iam.Effect.ALLOW,
      }));
      
      const alb = new elbv2.ApplicationLoadBalancer(this, `alb-${i}`, {
        vpc,
        internetFacing: true,
        http2Enabled: true,
        idleTimeout: cdk.Duration.seconds(300),
      });

      const listener = alb.addListener(`listener-${i}`, {
        port: 80,
      });

      const target = listener.addTargets(`listener-asg-${i}`, {
        port: 8080,
      });

      target.addTarget(asg);
    }
  }
}