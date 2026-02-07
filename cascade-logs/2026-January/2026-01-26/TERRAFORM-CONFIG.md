# Terraform Configuration Notes

## Project Configuration

### terraform.tfvars
- **Project ID:** `usfs-gcp-arch-testing`
- **Project Name:** `usfs-gcp-arch-testing`
- **Project Folder:** `folders/132735246914` (NRE\USFS\CIO\POC)
- **Region:** `us-west1`

### Current State
- The `terraform.tfvars` file is configured for the USFS organization structure
- Backend is configured to use GCS bucket: `tfstate-dev-usfs-tf-admin`
- Billing account is read from Secret Manager: `projects/604060129428/secrets/Billing-Code-CLIN1-USFS-Stratus`

### Issues for hector@develom.com Account
1. **Backend bucket access:** `403 storage.objects.list` error - `hector@develom.com` does not have access to the USFS tfstate bucket
2. **Billing account:** Secret Manager reference points to USFS project/secret
3. **Provider project:** Uses `usfs-tf-admin` as admin project (may not exist in target account)
4. **Folder/Org:** References USFS organizational folders

### Required Changes for Bootstrap in hector@develom.com
- Update or remove `backend.tf` (GCS bucket reference)
- Update `usfs_info` module defaults or override:
  - `admin_project_id`
  - `billing_account_id_secret` (or replace with variable)
  - `project_folder` (if using org/folder structure)
- Update `terraform.tfvars` with target account values

## Summary of Required Changes

### Must change:
- ✅ `project_id` in terraform.tfvars
- ✅ `project_name` in terraform.tfvars
- ✅ `project_folder` in terraform.tfvars
- ✅ `bucket` in backend.tf
- ✅ Add `billing_account_id` to terraform.tfvars

### Should verify/change:
- `project_region` (if different from us-west1)
- `prefix` in backend.tf
- Firewall/VPC settings (or remove compute module)
