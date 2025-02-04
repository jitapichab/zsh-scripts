get_instance_id() {
  if [[ -z "$1" || -z "$2" ]]; then
    echo "Usage: get_instance_id <aws_profile> <private-dns-name>"
    return 1
  fi

  local aws_profile=$1
  local dns_name=$2

  aws ec2 describe-instances \
    --profile "$aws_profile" \
    --filters "Name=private-dns-name,Values=$dns_name" \
    --query "Reservations[].Instances[].InstanceId" \
    --output text
}

connect_k8s_node() {
  if [[ -z "$1" || -z "$2" ]]; then
    echo "Usage: connect_k8s_node <aws_profile> <private-dns-name>"
    return 1
  fi

  local instance_id
  instance_id=$(get_instance_id "$1" "$2")

  if [[ "$instance_id" == "None" || -z "$instance_id" ]]; then
    echo "Error: No instance found with DNS $2 in profile $1."
    return 1
  fi

  echo "Connecting to instance $instance_id..."
  aws ssm start-session --profile "$1" --target "$instance_id"
}

get_instance_tags_and_kill() {
  if [[ -z "$1" || -z "$2" ]]; then
    echo "Usage: get_instance_tags_and_kill <aws_profile> <instance_id>"
    return 1
  fi

  local aws_profile="$1"
  local instance_id="$2"

  echo "Fetching tags for instance $instance_id in profile $aws_profile..."
  local tags
  tags=$(aws ec2 describe-instances \
    --profile "$aws_profile" \
    --instance-ids "$instance_id" \
    --query "Reservations[].Instances[].Tags" \
    --output table)

  if [[ -z "$tags" ]]; then
    echo "No tags found or invalid instance ID."
    return 1
  fi

  echo "Tags for instance $instance_id:"
  echo "$tags"

  # Prompt user for termination
  read  "confirm?Do you want to terminate this instance? (yes/no): "
  if [[ "$confirm" == "yes" ]]; then
    echo "Terminating instance $instance_id..."
    aws ec2 terminate-instances --profile "$aws_profile" --instance-ids "$instance_id"
    echo "Instance $instance_id termination initiated."
  else
    echo "Termination cancelled."
  fi
}

get_instance_info() {
  if [[ -z "$1" || -z "$2" ]]; then
    echo "Usage: get_instance_info <aws_profile> <instance_id>"
    echo "  aws_profile - AWS CLI profile to use."
    echo "  instance_id - The ID of the EC2 instance."
    return 1
  fi

  local aws_profile="$1"
  local instance_id="$2"

  echo "Fetching details for instance: $instance_id using profile: $aws_profile..."

  # Fetch the instance details
  local instance_details
  instance_details=$(aws ec2 describe-instances \
    --profile "$aws_profile" \
    --instance-ids "$instance_id" \
    --query "Reservations[].Instances[]" \
    --output json)

  # Check if instance details are retrieved
  if [[ -z "$instance_details" || "$instance_details" == "null" ]]; then
    echo "Error: No details found for instance ID $instance_id."
    return 1
  fi

  # Extract details
  local subnet_id
  subnet_id=$(echo "$instance_details" | jq -r '.[].SubnetId')

  local private_dns
  private_dns=$(echo "$instance_details" | jq -r '.[].PrivateDnsName')

  local security_groups
  security_groups=$(echo "$instance_details" | jq -r '.[].SecurityGroups[].GroupName' | tr '\n' ', ' | sed 's/, $//')

  local iam_role
  iam_role=$(echo "$instance_details" | jq -r '.[].IamInstanceProfile.Arn' | awk -F/ '{print $NF}')

  local ami_id
  ami_id=$(echo "$instance_details" | jq -r '.[].ImageId')

  local tags
  tags=$(echo "$instance_details" | jq -r '.[].Tags[] | "\(.Key): \(.Value)"' | sed 's/^/  /')

  local volume_ids
  volume_ids=$(echo "$instance_details" | jq -r '.[].BlockDeviceMappings[].Ebs.VolumeId')

  # Output the details
  echo "Instance Details:"
  echo "  Subnet ID       : $subnet_id"
  echo "  Private DNS     : $private_dns"
  echo "  Security Groups : $security_groups"
  echo "  IAM Role        : $iam_role"
  echo "  AMI ID          : $ami_id"
  echo "  Tags:"
  echo "$tags"
  echo "  Attached Volumes:"
  
  if [[ -n "$volume_ids" ]]; then
    for volume_id in $volume_ids; do
      echo "    Volume ID: $volume_id"
      # Fetch and print the volume's tags
      volume_tags=$(aws ec2 describe-tags \
        --profile "$aws_profile" \
        --filters "Name=resource-id,Values=$volume_id" \
        --query "Tags[]" \
        --output json | jq -r '.[] | "      \(.Key): \(.Value)"')

      if [[ -z "$volume_tags" ]]; then
        echo "      No tags found for volume $volume_id."
      else
        echo "$volume_tags"
      fi
    done
  else
    echo "    No volumes attached."
  fi
}

terminate_ec2_instances() {
  if [[ -z "$1" || -z "$2" ]]; then
    echo "Usage: terminate_ec2_instances <aws_profile> <instance_ids_comma_separated>"
    echo "  aws_profile               - AWS CLI profile to use."
    echo "  instance_ids_comma_separated - Comma-separated list of EC2 instance IDs."
    return 1
  fi

  local aws_profile="$1"
  local instance_ids_csv="$2"

  # Convert the comma-separated list into an array for Zsh
  local instance_ids=("${(@s/,/)instance_ids_csv}")

  echo "Using AWS profile: $aws_profile"
  echo "Terminating the following instances: ${instance_ids[*]}"

  # Pass instance IDs as separate arguments
  aws ec2 terminate-instances --profile "$aws_profile" --instance-ids "${instance_ids[@]}"

  if [[ $? -eq 0 ]]; then
    echo "Instances terminated successfully."
  else
    echo "Failed to terminate one or more instances. Check the AWS CLI output for details."
  fi
}
