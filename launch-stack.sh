#!/bin/bash
# sudo chmod +x *.sh
# ./launch-stack.sh

aws cloudformation create-stack --stack-name ccoa-taskcat --capabilities CAPABILITY_NAMED_IAM --disable-rollback --template-body file://pipeline-taskcat.yml
