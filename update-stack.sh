STACK_NAME="$1"
TEMPLATE_FILE=${2:-main.yml}
PARAMETER_FILE=${3:-parameters.json}
AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-us-east-2}
STACK_COMMAND="create-stack"

if aws cloudformation describe-stacks --region=$AWS_DEFAULT_REGION --stack-name=$STACK_NAME >/dev/null 2>&1; then
    STACK_COMMAND="update-stack"
fi

aws cloudformation $STACK_COMMAND \
--stack-name $STACK_NAME \
--template-body file://$TEMPLATE_FILE \
--parameters file://$PARAMETER_FILE \
--capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
--region=$AWS_DEFAULT_REGION