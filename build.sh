#!/bin/bash

create_components() {
  for f in src/ImageBuilder/*; do
    printf "\nProcessing $f\n"

    name=$(basename ${f%.yaml})
    version="1.0.0"

    arn=$(aws imagebuilder list-components --filters name=name,values=${name} name=version,values=${version} | jq -r '.componentVersionList[0].arn')
    if [ "x${arn}" == "xnull" ]; then
      printf " – Creating component: ${name} (${version})\n"
      aws imagebuilder create-component --name $name --semantic-version 1.0.0 --platform Linux --data file://$f --query 'componentBuildVersionArn'
    else
      printf " – Skipping component: ${name} (${version}) –– Already exists as ${arn}\n"
    fi
  done;
}

create_recipe() {
  arns=$(aws imagebuilder list-components | \
    jq  '[ .componentVersionList[].arn ]' | \
    jq --argjson builtin "[\"arn:aws:imagebuilder:${AWS_REGION}:aws:component/amazon-corretto-11/1.0.0/1\", \"arn:aws:imagebuilder:${AWS_REGION}:aws:component/docker-ce-linux/1.0.0/1\", \"arn:aws:imagebuilder:${AWS_REGION}:aws:component/dotnet-core-sdk-linux/3.1.0/1\"]" -s '$builtin + .[]' | \
    jq '[{"componentArn": .[]}]' | \
    jq -s 'add')

  arn=$(aws imagebuilder list-image-recipes --filters name=name,values=code-server | jq -r '.imageRecipeSummaryList[0].arn')
  if [ "x${arn}" == "xnull" ]; then
    printf "\nCreating Image Recipe"
    aws imagebuilder create-image-recipe --name code-server --semantic-version 1.0.0 --parent-image arn:aws:imagebuilder:$AWS_REGION:aws:image/amazon-linux-2-x86/x.x.x --components "${arns}" --query 'imageRecipeArn'
  else
    printf "\nSkipping image recipe –– Already exists\n"
  fi
}

create_infra_config() {
  accountId=$(aws sts get-caller-identity | jq -r '.Account')
  vpcId=$(aws ec2 describe-vpcs --filters Name=isDefault,Values=true | jq -r '.Vpcs[0].VpcId')
  subnetId=$(aws ec2 describe-subnets --filters Name=vpc-id,Values=${vpcId} | jq -r '.Subnets[0].SubnetId')

  groupId=$(aws ec2 describe-security-groups --filters Name=group-name,Values=code-server-image | jq -r '.SecurityGroups[0].GroupId')
  if [ "x${groupId}" == "xnull" ]; then
    printf "\nCreating security group\n"
    groupId=$(aws ec2 create-security-group --group-name 'code-server-image' --description 'code-server-image' --vpc-id $vpcId | jq -r '.GroupId')
  else
    printf "\nSkipping security group –– Already exists\n"
  fi

  aws iam get-role --role-name code-server > /dev/null 2>&1
  RES=$?
  if [ $RES -eq 254 ]; then
    printf "\nCreating IAM role\n"
    aws iam create-role --role-name code-server --assume-role-policy-document '{"Version": "2012-10-17","Statement": [{"Effect": "Allow","Principal": {"Service": ["ec2.amazonaws.com"]},"Action": ["sts:AssumeRole"]}]}'  > /dev/null 2>&1
    aws iam attach-role-policy --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess --role-name code-server
    aws iam attach-role-policy --policy-arn arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilder --role-name code-server
    aws iam attach-role-policy --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore --role-name code-server
    aws iam create-instance-profile --instance-profile-name code-server
    aws iam add-role-to-instance-profile --role-name code-server --instance-profile-name code-server
  else
    printf "\nSkipping IAM role –– Already exists\n"
  fi

  bucketName=$(aws s3api list-buckets | jq -r '.Buckets[] | select(.Name=="446539624890-code-server") | .Name')
  if [ "x${bucketName}" == "xnull" ]; then
    printf "\nCreating bucket\n"
    aws s3api create-bucket --bucket "${accountId}-code-server" --create-bucket-configuration "{\"LocationConstraint\":\"${AWS_REGION}\"}"
  else
    printf "\nSkipping bucket –– Already exists\n"
  fi

  infraConfigArn=$(aws imagebuilder list-infrastructure-configurations --filters name=name,values=code-server | jq -r '.infrastructureConfigurationSummaryList[0].arn') 
  if [ "x${infraConfigArn}" == "xnull" ]; then
    printf "\nCreating Infrastructure Config\n"
    aws imagebuilder create-infrastructure-configuration \
      --name code-server \
      --instance-profile-name 'code-server' \
      --instance-types t3.xlarge \
      --no-terminate-instance-on-failure \
      --security-group-ids $groupId \
      --subnet-id $subnetId \
      --logging "{\"s3Logs\":{\"s3BucketName\":\"${accountId}-code-server\",\"s3KeyPrefix\":\"code-server\"}}"
  else
    printf "\nSkipping Infrastructure Config –– Already exists\n"
  fi
}

create_pipeline() {
  recipeArn=$(aws imagebuilder list-image-recipes --filters name=name,values=code-server | jq -r '.imageRecipeSummaryList[0].arn')
  infraConfigArn=$(aws imagebuilder list-infrastructure-configurations --filters name=name,values=code-server | jq -r '.infrastructureConfigurationSummaryList[0].arn')

  arn=$(aws imagebuilder list-image-pipelines --filters name=name,values=code-server | jq -r '.imagePipelineList[0].arn')

  if [ "x${arn}" == "xnull" ]; then
    printf "\nCreating image pipeline\n"
    aws imagebuilder create-image-pipeline \
      --name code-server \
      --image-recipe-arn $recipeArn \
      --infrastructure-configuration-arn $infraConfigArn
  else
    printf "\nSkipping image pipeline –– Already exists\n"
  fi
}

create_components
create_recipe
create_infra_config
create_pipeline