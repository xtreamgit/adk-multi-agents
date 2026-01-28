# Project Name: department-project-name-env

## Overview

Describe the purpose of this project, its business context, and what infrastructure it manages.

## Project Naming

- **Format:** `{department}-{project-name}-{env}` (env is optional; use only for prod-bound apps, e.g. `dev`, `stage`)
- **Examples:** `cio-identity-mgmt-dev`, `gtac-rati-techeval-stage`, `research-larse` (default nonprod)
- **Rules:**
  - Use lowercase letters and numbers only
  - Use hyphens (`-`) as separators (never underscores)
  - No spaces or special characters
  - Keep names concise (aim for < 30 characters where possible)
  - The `env` segment (`dev`, `stage`) is optional and should only be included if your project requires multiple non-prod environments. Most projects will have a single environment and can omit this segment.

## Layout

```sh
<department>-<project-name>[-<env>]/
├── README.md
├── .gitignore
├── versions.tf
├── backend.tf
├── providers.tf
├── main.tf
├── locals.tf
├── variables.tf
├── outputs.tf
├── terraform.tfvars         # Variable values for this environment
├── modules/
│   ├── buckets/
│   ├── compute/
│   ├── iam/
│   ├── roles/
│   ├── service_account/
│   └── example/
```

## Quick Start

Prerequisites: `terraform` CLI >= 1.0.0 and access to the remote state bucket.

```powershell
terraform init -backend-config="bucket=<your-tfstate-bucket>" -backend-config="prefix=terraform/state/<department>-<project-name>[-<env>]"
terraform fmt
terraform validate
terraform plan
```

## Variables

Document required input variables here. Example:

| Name       | Description      | Type   | Default     |
|------------|------------------|--------|-------------|
| project_id | GCP project ID   | string | n/a         |
| region     | GCP region       | string | us-central1 |

## Outputs

Document outputs here. Example:

| Name         | Description                 |
|--------------|-----------------------------|
| project_id   | The created GCP project ID  |
| bucket_names | List of GCS buckets created |

## Modules

List and describe any modules used or created in this project.

## Customization & Notes

- Add any project-specific instructions, caveats, or custom logic here.
- Reference [Project Naming Constraints](../../projects/Project%20Naming%20Constraints.md) for naming rules.

## Best Practices

- **Naming:** Follow the project naming rules exactly to keep state and IAM predictable.
- **State:** Use remote state with locking (GCS + Cloud KMS + state locking) for multi-person workflows.
- **Secrets:** Never commit secrets; inject them via CI secret store or use a secrets manager.
- **CI/CD:** Have an automated pipeline that formats (`terraform fmt`), validates (`terraform validate`), and plans/applies with approval gates.
- **Modules:** Prefer small, reusable modules. Version modules when sharing across teams.
- **Documentation:** Document required variables, outputs, and any manual steps in the project's `README.md`.

## Support

For questions or improvements, contact the GCP team or submit a pull request.
