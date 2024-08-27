terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"  # Replace with your desired region
}

variable "users" {
  description = "Map of user names to their configurations"
  type = map(object({
    policy_arns = list(string)
    tags        = map(string)
  }))
  default = {
    "user1" = {
      policy_arns = [
        "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess",
        "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
      ]
      tags = {
        Department = "DevOps"
        Project    = "Infrastructure"
      }
    },
    "user2" = {
      policy_arns = [
        "arn:aws:iam::aws:policy/AmazonS3FullAccess"
      ]
      tags = {
        Department = "Development"
        Project    = "WebApp"
      }
    }
  }
}

resource "aws_iam_user" "users" {
  for_each = var.users
  name     = each.key
  path     = "/"

  tags = each.value.tags
}

resource "aws_iam_access_key" "user_keys" {
  for_each = aws_iam_user.users
  user     = each.value.name
}

resource "aws_iam_user_policy_attachment" "user_policies" {
  for_each = {
    for pair in flatten([
      for user, config in var.users : [
        for policy in config.policy_arns : {
          user   = user
          policy = policy
        }
      ]
    ]) : "${pair.user}-${pair.policy}" => pair
  }

  user       = aws_iam_user.users[each.value.user].name
  policy_arn = each.value.policy
}

output "user_names" {
  description = "The names of the IAM users"
  value       = { for k, v in aws_iam_user.users : k => v.name }
}

output "user_arns" {
  description = "The ARNs of the IAM users"
  value       = { for k, v in aws_iam_user.users : k => v.arn }
}

output "access_key_ids" {
  description = "The access key IDs"
  value       = { for k, v in aws_iam_access_key.user_keys : k => v.id }
}

output "secret_access_keys" {
  description = "The secret access keys. This will be written to the state file in plain-text."
  value       = { for k, v in aws_iam_access_key.user_keys : k => v.secret }
  sensitive   = true
}