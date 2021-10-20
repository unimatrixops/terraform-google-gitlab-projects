


terraform {
  required_providers {
    gitlab = {
      source = "gitlabhq/gitlab"
      version = "3.7.0"
    }
    google = {
      version = "3.88.0"
    }
  }
}


locals {
  secrets = {
    for secret in var.gitlab_project.secrets:
    secret.name => merge(secret, {
      project=var.gitlab_project.qualname
      environment_scope=try(secret.environment_scope, "*")
    })
  }
}


resource "gitlab_project_variable" "plain" {
  for_each = {
    for key, secret in local.secrets:
    key => secret if secret.kind == "plain"
  }

  project           = each.value.project
  key               = each.value.name
  value             = each.value.value
  protected         = true
  masked            = try(each.value.masked, false)
  environment_scope = each.value.environment_scope
}
