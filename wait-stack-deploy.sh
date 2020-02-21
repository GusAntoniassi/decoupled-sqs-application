#!/bin/bash

AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-"us-east-2"}
STACK_NAME="$1"

echo -n "Waiting until stack \"$STACK_NAME\" finishes deploying..."

until STACK_STATUS=$(
    aws cloudformation describe-stacks \
        --region="$AWS_DEFAULT_REGION" \
        --stack-name="$STACK_NAME" \
        --output=text \
        --query='Stacks[0].StackStatus' \
        2>/dev/null
); [ "$STACK_STATUS" = "CREATE_COMPLETE" ] || [ "$STACK_STATUS" = "UPDATE_COMPLETE" ]
do
  echo -n "."
  sleep 1
done

echo "!"