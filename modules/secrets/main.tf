

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
      value=try(
        data.google_secret_manager_secret_version.secrets[secret.name].secret_data,
        secret.value
      )
    })
  }
}


data "google_secret_manager_secret_version" "secrets" {
  for_each = {
    for secret in var.gitlab_project.secrets:
    secret.name => secret if secret.kind == "google"
  }

  project = each.value.storage.project
  secret  = each.value.storage.name
}


resource "gitlab_project_variable" "plain" {
  for_each = local.secrets

  project           = each.value.project
  key               = each.value.name
  value             = each.value.value
  protected         = true
  masked            = try(each.value.masked, false)
  environment_scope = each.value.environment_scope
}
