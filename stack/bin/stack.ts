#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from '@aws-cdk/core';
import { StackStack } from '../lib/stack-stack';

import * as process from 'process';

const app = new cdk.App();
new StackStack(app, 'StackStack', {env: {
  region: process.env.CDK_DEFAULT_REGION,
  account: process.env.CDK_DEFAULT_ACCOUNT,
}});
