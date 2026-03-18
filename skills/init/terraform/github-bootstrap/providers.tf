terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

provider "github" {
  owner = var.github_owner

  dynamic "app_auth" {
    for_each = var.github_auth_mode == "app" ? [1] : []
    content {}
  }
}
