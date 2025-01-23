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
