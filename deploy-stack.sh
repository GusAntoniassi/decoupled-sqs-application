#!/bin/bash

set -e

update_stack_ignore_noop() {
    local STACK_NAME=$1
    local STACK_TEMPLATE=$2
    # CloudFormation has a "No updates are to be performed" error that we can't suppress
    set +e
    local UPDATE_BUCKET_OUTPUT=$( (./update-stack.sh $STACK_NAME $STACK_TEMPLATE) 2>&1)
    local UPDATE_BUCKET_STATUS="$?"
    set -e

    if echo "$UPDATE_BUCKET_OUTPUT" | grep -q "No updates are to be performed"; then
        echo "No changes in the $STACK_NAME template"
    else
        echo "$UPDATE_BUCKET_OUTPUT"

        if [ $UPDATE_BUCKET_STATUS -ne 0 ]; then
            exit
        fi

        ./wait-stack-deploy.sh $STACK_NAME
    fi
}

get_value_from_stack_outputs() {
    local STACK_OUTPUTS=$1
    local KEY_VALUE=$2

    echo "$STACK_OUTPUTS" \
        | jq --raw-output -c \
        ".[] | select( .OutputKey | contains(\"$KEY_VALUE\")) | .OutputValue"
}

AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-"us-east-2"}

chmod +x ./*.sh

if ! aws s3 ls >/dev/null; then
    echo "There is a problem with your AWS credentials"
    exit 1
fi

update_stack_ignore_noop "templates-bucket" "s3/templates-bucket.yml"

# Clone AWS Lambda code to upload it to bucket
rm -rf lambda/{source-code,source-code.zip}
git clone https://github.com/GusAntoniassi/decoupled-sqs-application-voting-api-lambda.git lambda/source-code
zip -j lambda/source-code.zip lambda/source-code/*

TEMPLATES_BUCKET_NAME=$(aws cloudformation describe-stacks \
    --region="$AWS_DEFAULT_REGION" \
    --stack-name="templates-bucket" \
    --output=text \
    --query='Stacks[0].Outputs[?OutputKey==`BucketName`].OutputValue'
)

FILES_TO_UPLOAD=(
    api-gateway/voting-api-gateway.yml
    dynamodb/voting-database.yml
    ec2/processing-spot-instances.yml
    lambda/voting-lambda.yml
    lambda/source-code.zip
    s3/static-website.yml
    sqs/voting-queue.yml
    vpc/vpc.yml)

for file in "${FILES_TO_UPLOAD[@]}"; do 
    aws s3 cp "$file" "s3://$TEMPLATES_BUCKET_NAME/$file"
done

update_stack_ignore_noop "decoupled-sqs-application" "main.yml"

# Upload static website to S3
STACK_OUTPUTS=$(aws cloudformation describe-stacks \
    --region="$AWS_DEFAULT_REGION" \
    --stack-name="decoupled-sqs-application" \
    --output=json \
    --query='Stacks[0].Outputs'
)

STATIC_WEBSITE_BUCKET_NAME="$(get_value_from_stack_outputs "$STACK_OUTPUTS" "StaticWebsiteBucketName")"
STATIC_WEBSITE_URL="$(get_value_from_stack_outputs "$STACK_OUTPUTS" "StaticWebsiteBucketUrl")"
API_URL="$(get_value_from_stack_outputs "$STACK_OUTPUTS" "ApiGatewayUrl")"
TABLE_NAME="$(get_value_from_stack_outputs "$STACK_OUTPUTS" "TableName")"

# Fill DynamoDB table with records
./dynamodb/populate-database.sh $TABLE_NAME

if [ -z $STATIC_WEBSITE_BUCKET_NAME ]; then
    echo "Could not get static website bucket name in the stack outputs: $STACK_OUTPUTS"
    exit 1
fi

echo $STATIC_WEBSITE_BUCKET_NAME
echo $API_URL

rm -rf ./static-website-code
git clone https://github.com/GusAntoniassi/decoupled-sqs-application-static-website.git static-website-code
sed -i "s~{{API_GATEWAY_URL}}~$API_URL~g" static-website-code/assets/js/main.js

aws s3 cp static-website-code s3://"$STATIC_WEBSITE_BUCKET_NAME"/ --recursive --exclude=".git/*"

echo "Website URL: http://$STATIC_WEBSITE_URL"