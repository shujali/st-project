terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.69.0"
    }
  }
}

provider "aws" {
  access_key = var.ali1_akey
  secret_key = var.ali1_skey
  region     = var.ali1_location
}


# terraform {
#   cloud {

#     organization = "ali-networks"

#     workspaces {
#       name = "dev"
#     }
#   }
# }

terraform {
  cloud {

    organization = "ali-networks"

    workspaces {
      name = "prod"
    }
  }
}

# terraform {
#   cloud {
#     organization = "ali-networks"
#     hostname     = "app.terraform.io"
#     workspaces {
#       tags = ["tf-aws-git"]
#     }
#   }
# }