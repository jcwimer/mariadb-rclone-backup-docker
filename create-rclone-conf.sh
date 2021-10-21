#!/bin/bash

check_vars()
{
    var_names=("$@")
    local var_unset="false"
    for var_name in "${var_names[@]}"; do
        if [ -z "${!var_name}" ]; then
          echo "$var_name is unset." 
          var_unset="true"
        fi
    done
    if [ "$var_unset" == "true" ]; then
      exit 1
    fi
    return 0
}

if [ "$RCLONE_TYPE" == "s3" ]; then
echo Checking environment for needed rclone variables...
check_vars S3_ACCESS_ID S3_ACCESS_KEY S3_REGION S3_ENDPOINT RCLONE_PATH
cat > /rclone.conf << EOF
[backup]
type = s3
env_auth = false
access_key_id = ${S3_ACCESS_ID}
secret_access_key = ${S3_ACCESS_KEY}
region = ${S3_REGION}
endpoint = ${S3_ENDPOINT}
location_constraint =
server_side_encryption =
EOF
fi
