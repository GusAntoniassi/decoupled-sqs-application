#!/bin/bash

set -e

AWS_REGION=${AWS_REGION:-"us-east-2"}
STACK_NAME="voting-database"

# Get the DynamoDB table name
TABLE_NAME=$(aws cloudformation describe-stacks \
    --region="$AWS_REGION" \
    --stack-name="$STACK_NAME" \
    --output=text \
    --query='Stacks[0].Outputs[?OutputKey==`TableName`].OutputValue'
)

if [[ $(aws dynamodb scan \
    --region="$AWS_REGION" \
    --table-name="$TABLE_NAME" \
    --select='COUNT' \
    --query='Count' \
    --output=text) -ne 0 
]]; then
    echo 'Table already contains data, aborting script'
    exit
fi

echo "Inserting initial data into table $TABLE_NAME"

IDES_TO_INSERT=(vscode vim intellij eclipse atom sublime netbeans visualstudio other)

for i in "${!IDES_TO_INSERT[@]}"; do 
    id=$(echo -n "$i" | md5sum | awk '{ print $1 }')
    ide_key="${IDES_TO_INSERT[$i]}";
    votes=0
    item_json=$(cat <<EOF
{
    "_id": {"S": "$id"},
    "ide_key": {"S": "$ide_key"},
    "votes": {"N": "$votes"}
}
EOF
)
    aws dynamodb put-item \
        --region="$AWS_REGION" \
        --table-name "$TABLE_NAME" \
        --item "$item_json"

    echo "Inserted $ide_key"

    sleep 1 # Give AWS API a time to breathe
done