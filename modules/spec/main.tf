

variable "projects" {}


output "projects" {
  description="The Gitlab projects managed by this Terraform plan."
  value={
    for project in var.projects:
    "${project.group}/${project.path}" => merge(project, {
      qualname="${project.group}/${project.path}"
      variables=[
        for x in try(project.variables, []):
        merge({
          protected=false
          masked=false
          environment_scope="*"
        }, x)
      ]
    })
  }
}
