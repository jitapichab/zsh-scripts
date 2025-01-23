#!/bin/bash
delete_load_balancer() {
  if [[ -z "$1" || -z "$2" ]]; then
    echo "Usage: delete_load_balancer <aws_profile> <load_balancer_name>"
    return 1
  fi

  local aws_profile="$1"
  local lb_name="$2"

  # Check if the load balancer exists
  echo "Checking if the load balancer $lb_name exists..."
  local lb_arn
  lb_arn=$(aws elbv2 describe-load-balancers \
    --profile "$aws_profile" \
    --query "LoadBalancers[?LoadBalancerName=='$lb_name'].LoadBalancerArn" \
    --output text)

  if [[ -z "$lb_arn" ]]; then
    echo "No load balancer found with the name $lb_name."
    return 1
  fi

  echo "Load Balancer ARN: $lb_arn"

  # Confirm deletion
  echo -n "Are you sure you want to delete the load balancer $lb_name? (yes/no): "
  read confirm
  if [[ "$confirm" != "yes" ]]; then
    echo "Operation cancelled."
    return 0
  fi

  # Delete the load balancer
  echo "Deleting load balancer $lb_name..."
  aws elbv2 delete-load-balancer --profile "$aws_profile" --load-balancer-arn "$lb_arn"

  if [[ $? -eq 0 ]]; then
    echo "Load balancer $lb_name deleted successfully."
  else
    echo "Failed to delete load balancer $lb_name."
  fi
}
