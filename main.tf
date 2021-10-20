#-------------------------------------------------------------------------------
#
#   GITLAB PROJECT (GOOGLE)
#
#   Configures a Gitlab project using Google Cloud Platform as the supporting
#   infrastructure.
#
#   This Terraform plan parses a list of Gitlab group specifications from a YAML
#   encoded file. For each project, it configures the appropriate Google Cloud
#   Resources, such as storage buckets and secrets. It also configures project
#   secrets and service accounts, if specified.
#
#-------------------------------------------------------------------------------


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
  # Get a unique list of groups to fetch with the Gitlab provider.
  gitlab_groups   = toset([for x in var.gitlab_projects: x.group])

  gitlab_projects = {for x in var.gitlab_projects: "${x.group}/${x.path}" => x}

  terraform_projects = {
    for k, v in local.gitlab_projects:
    k => v if try(v.kind, "") == "terraform"
  }
}


# Create a set of group paths so we can reference additional information from
# the groups.
data "gitlab_group" "groups" {
  for_each  = local.gitlab_groups
  full_path = each.value
}


# Create Gitlab projects in their respective groups. It is assumed that the
# groups already exist.
resource "gitlab_project" "projects" {
  for_each                    = local.gitlab_projects
  namespace_id                = data.gitlab_group.groups[each.value.group].id
  path                        = each.value.path
  name                        = each.value.name
  description                 = try(each.value.description, null)
  tags                        = try(each.value.tags, [])
  default_branch              = try(each.value.default_branch, null)
  request_access_enabled      = try(each.value.request_access_enabled, false)
  issues_enabled              = try(each.value.issues_enabled, false)
  merge_requests_enabled      = try(each.value.merge_requests_enabled, false)
  pipelines_enabled           = try(each.value.pipelines_enabled, false)
  wiki_enabled                = try(each.value.wiki_enabled, false)
  container_registry_enabled  = try(each.value.container_registry_enabled, false)
  visibility_level            = try(each.value.visibility_level, "private")
  merge_method                = try(each.value.merge_method, "merge")
  shared_runners_enabled      = try(each.value.shared_runners_enabled, false)
  packages_enabled            = try(each.value.packages_enabled, false)
  pages_access_level          = try(each.value.pages_access_level, "private")

  only_allow_merge_if_pipeline_succeeds             = true
  only_allow_merge_if_all_discussions_are_resolved  = true
  initialize_with_readme                            = false
}


# Terraform projects
#
# - Create a bucket to store the Terraform state.
# - Assign the proper access policies to the Terraform bucket.
#
data "google_iam_policy" "terraform" {
  for_each = local.terraform_projects

  binding {
    role    = "roles/storage.admin"
    members = toset(concat(
      var.storage_admins,
      ["serviceAccount:${each.value.service_account}"]
    ))
  }
}


resource "google_storage_bucket" "terraform" {
  depends_on  = [gitlab_project.projects]
  for_each    = local.terraform_projects
  name        = "gitlab-project-${gitlab_project.projects[each.key].id}"
  location    = coalesce(try(each.value.storage_region, var.storage_region), "europe-west4")
  project     = var.project
  labels      = {purpose="terraform-state"}

  storage_class               = "REGIONAL"
  uniform_bucket_level_access = true
}


resource "google_storage_bucket_iam_policy" "terraform" {
  depends_on  = [google_storage_bucket.terraform]
  for_each    = google_storage_bucket.terraform
  bucket      = google_storage_bucket.terraform[each.key].name
  policy_data = data.google_iam_policy.terraform[each.key].policy_data
}
