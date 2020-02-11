aws cloudformation delete-stack \
--stack-name $1 \
--region=${AWS_REGION:-us-east-2}