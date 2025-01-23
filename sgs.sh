#!/bin/bash

remove_sg_rules() {
  if [[ -z "$1" || -z "$2" ]]; then
    echo "Usage: remove_sg_rules <aws_profile> <security_group_id>"
    return 1
  fi

  local aws_profile="$1"
  local sg_id="$2"

  # Fetch and display security group tags
  echo "Fetching tags for Security Group: $sg_id..."
  local tags
  tags=$(aws ec2 describe-security-groups \
    --profile "$aws_profile" \
    --group-ids "$sg_id" \
    --query "SecurityGroups[0].Tags" \
    --output table)

  if [[ -z "$tags" || "$tags" == "None" ]]; then
    echo "No tags found for Security Group: $sg_id."
  else
    echo "Tags for Security Group $sg_id:"
    echo "$tags"
  fi

  # Check for EC2 instances using the security group
  echo "Checking for EC2 instances using Security Group: $sg_id..."
  local instance_ids
  instance_ids=$(aws ec2 describe-instances \
    --profile "$aws_profile" \
    --filters "Name=instance.group-id,Values=$sg_id" \
    --query "Reservations[].Instances[].InstanceId" \
    --output text)

  if [[ -z "$instance_ids" ]]; then
    echo "No EC2 instances are using Security Group: $sg_id."
  else
    echo "EC2 Instances using Security Group $sg_id:"
    echo "$instance_ids"
  fi

  # Detect load balancers using the security group
  echo "Checking for load balancers using Security Group: $sg_id..."
  local lb_arns
  lb_arns=$(aws elbv2 describe-load-balancers \
    --profile "$aws_profile" \
    --query "LoadBalancers[?SecurityGroups!=null && contains(SecurityGroups, \`$sg_id\`)].LoadBalancerArn" \
    --output text)

  if [[ -z "$lb_arns" ]]; then
    echo "No load balancers are using Security Group: $sg_id."
  else
    echo "Load Balancers using Security Group $sg_id:"
    echo "$lb_arns"
    echo -n "Do you want to continue disassociating rules even if a load balancer is using this security group? (yes/no): "
    read confirm_lb
    if [[ "$confirm_lb" != "yes" ]]; then
      echo "Operation cancelled."
      return 0
    fi
  fi

  # Fetch and display inbound (ingress) rules
  echo "Fetching inbound rules for Security Group: $sg_id..."
  local ingress_rules
  ingress_rules=$(aws ec2 describe-security-groups \
    --profile "$aws_profile" \
    --group-ids "$sg_id" \
    --query "SecurityGroups[0].IpPermissions" \
    --output json)

  if [[ "$ingress_rules" == "[]" ]]; then
    echo "No inbound rules found."
  else
    echo "Inbound Rules:"
    aws ec2 describe-security-groups \
      --profile "$aws_profile" \
      --group-ids "$sg_id" \
      --query "SecurityGroups[0].IpPermissions" \
      --output table
  fi

  # Fetch and display outbound (egress) rules
  echo "Fetching outbound rules for Security Group: $sg_id..."
  local egress_rules
  egress_rules=$(aws ec2 describe-security-groups \
    --profile "$aws_profile" \
    --group-ids "$sg_id" \
    --query "SecurityGroups[0].IpPermissionsEgress" \
    --output json)

  if [[ "$egress_rules" == "[]" ]]; then
    echo "No outbound rules found."
  else
    echo "Outbound Rules:"
    aws ec2 describe-security-groups \
      --profile "$aws_profile" \
      --group-ids "$sg_id" \
      --query "SecurityGroups[0].IpPermissionsEgress" \
      --output table
  fi

  # Prompt user for confirmation
  echo -n "Do you want to disassociate all rules from Security Group $sg_id? (yes/no): "
  read confirm
  if [[ "$confirm" != "yes" ]]; then
    echo "Operation cancelled."
    return 0
  fi

  # Remove inbound (ingress) rules
  if [[ "$ingress_rules" != "[]" ]]; then
    echo "Removing all inbound rules..."
    aws ec2 revoke-security-group-ingress --profile "$aws_profile" --group-id "$sg_id" --ip-permissions "$ingress_rules"
    if [[ $? -eq 0 ]]; then
      echo "Inbound rules removed successfully."
    else
      echo "Failed to remove inbound rules."
    fi
  fi

  # Remove outbound (egress) rules
  if [[ "$egress_rules" != "[]" ]]; then
    echo "Removing all outbound rules..."
    aws ec2 revoke-security-group-egress --profile "$aws_profile" --group-id "$sg_id" --ip-permissions "$egress_rules"
    if [[ $? -eq 0 ]]; then
      echo "Outbound rules removed successfully."
    else
      echo "Failed to remove outbound rules."
    fi
  fi

  echo "All rules disassociated from Security Group $sg_id."
}

