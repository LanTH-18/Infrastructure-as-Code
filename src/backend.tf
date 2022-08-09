terraform {
  backend "s3" {
    bucket         = "terraform-project-state-bucket"
    key            = "eks-cluster.tfstate"
    region         = "us-west-1"
    encrypt        = true
    access_key     = "AKIATQGIIIVVOK2ZTTN2"
    secret_key     = "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"
  }
}
