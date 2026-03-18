variable "github_owner" {
  description = "GitHub organization or personal account name."
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name."
  type        = string
}

variable "github_visibility" {
  description = "GitHub repository visibility."
  type        = string
  default     = "private"
}

variable "repo_description" {
  description = "Repository description."
  type        = string
  default     = "Bootstrapped by c4flow:init"
}

variable "delete_branch_on_merge" {
  description = "Automatically delete branches after merge."
  type        = bool
  default     = true
}

variable "coderabbit_installation_id" {
  description = "GitHub App installation id for CodeRabbit."
  type        = string
  default     = ""
}

variable "enable_coderabbit_installation" {
  description = "Attach an existing CodeRabbit installation to the repository."
  type        = bool
  default     = false
}

variable "default_branch" {
  description = "Default branch name for output and downstream flow."
  type        = string
  default     = "main"
}

variable "github_auth_mode" {
  description = "Authentication mode used by the GitHub provider."
  type        = string
  default     = "token"
}
