# Provider
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}
# Authentication
provider "aws" {
  region = "us-west-1"
  access_key = "AKIATQGIIIVVOK2ZTTN2"
  secret_key = "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"
}
