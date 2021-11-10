

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


variable "variables" {
  description="The environment variables defined for a project."
  type=list(
    object({
      project_id=number
      key=string
      value=string
      protected=bool
      masked=bool
      environment_scope=string
    })
  )
}


locals {
  variables = {
    for v in var.variables:
    "${v.key}/${v.environment_scope}" => v
  }
}


resource "gitlab_project_variable" "env" {
  for_each          = local.variables
  project           = each.value.project_id
  key               = each.value.key
  value             = each.value.value
  protected         = each.value.protected
  masked            = each.value.masked
  environment_scope = each.value.environment_scope
}
