# Consumer Quick Reference

> **Audience**: DevOps Engineers, Platform Engineers | **Type**: Cheat sheet
> **See also**: [00_START_HERE.md](00_START_HERE.md) | [REPLICATION_GUIDE.md](REPLICATION_GUIDE.md) for full walkthrough

Quick-lookup reference for secrets, variables, workflows, and common operations
in this consumer repository template.

---

## GitHub Secrets (Required)

Configure in **Settings -> Secrets and variables -> Actions -> Secrets**.

### Core (all workflows)

| Secret | Value Source | Description |
|--------|-------------|-------------|
| `AZURE_TENANT_ID` | Entra ID -> Overview | Azure AD tenant GUID |
| `AZURE_CLIENT_ID` | Entra ID -> App registrations -> your SP | Service Principal app ID |
| `AZURE_CLIENT_SECRET` | Entra ID -> App registrations -> Certificates & secrets | SP client secret |
| `FABRIC_GITHUB_TOKEN` | GitHub -> Settings -> Developer settings -> Fine-grained tokens | PAT with `repo` scope |
| `SP_OBJECT_ID` | Entra ID -> App registrations -> your SP -> Object ID | Service Principal object ID (for workspace access) |

### Capacity

| Secret | Value Source | Description |
|--------|-------------|-------------|
| `FABRIC_CAPACITY_ID` | Fabric Admin -> Capacity settings | Dev capacity GUID |
| `FABRIC_CAPACITY_ID_TEST` | Fabric Admin -> Capacity settings | Test capacity GUID (can be same as Dev) |
| `FABRIC_CAPACITY_ID_PROD` | Fabric Admin -> Capacity settings | Prod capacity GUID |

### Governance (auto-injected into every workspace)

| Secret | Value Source | Description |
|--------|-------------|-------------|
| `ADDITIONAL_ADMIN_PRINCIPAL_ID` | Entra ID -> Groups -> your admin group -> Object ID | Gets Admin role in all workspaces |
| `ADDITIONAL_CONTRIBUTOR_PRINCIPAL_ID` | Entra ID -> Groups -> your contributor group -> Object ID | Gets Contributor role in all workspaces |

### Project-Specific Principals

| Secret | Used by | Description |
|--------|---------|-------------|
| `DEMO_ADMIN_ID` | Demo project | Admin security group OID |
| `DEMO_MEMBERS_ID` | Demo project | Member OIDs (comma-separated) |
| `SALES_ANALYTICS_ADMIN_ID` | Sales Analytics project | Admin security group OID |
| `SALES_ANALYTICS_MEMBERS_ID` | Sales Analytics project | Member OIDs |

> **Pattern**: For each new project `<slug>`, add `<SLUG_UPPER>_ADMIN_ID` and `<SLUG_UPPER>_MEMBERS_ID`.

---

## GitHub Variables (Optional)

Configure in **Settings -> Secrets and variables -> Actions -> Variables**.

| Variable | Default | Description |
|----------|---------|-------------|
| `PROJECT_PREFIX` | `fabric-cicd-demo` | Workspace name prefix (e.g., `acme-data`) |
| `CLI_REPO_URL` | `github.com/BralaBee-LEIT/usf_fabric_cli_cicd_codebase` | CLI repo URL (no `https://`) |
| `CLI_REPO_REF` | `v1.8.3` | CLI Git tag or branch to install |
| `FABRIC_CLI_VERSION` | `1.3.1` | Microsoft Fabric CLI version |
| `FEATURE_WORKSPACE_CONFIG` | *(auto-discovered)* | Override feature workspace config path |

---

## Workflows Summary

| # | Workflow | Trigger | What It Does | Config File |
|---|---------|---------|-------------|-------------|
| 1 | **CI** | PR/push to `main` | Validates YAML syntax, no hardcoded secrets | -- |
| 2 | **Setup Base Workspaces** | `workflow_dispatch` (manual) | Creates Dev workspace + Deployment Pipeline + Test/Prod | `config/projects/<project>/base_workspace.yaml` |
| 3 | **Feature Workspace Create** | Push to `feature/**` | Auto-provisions isolated workspace with Git connection | `config/projects/<project>/feature_workspace*.yaml` |
| 4 | **Feature Workspace Cleanup** | PR merged to `main` | Auto-destroys feature workspace (safe mode) | Same as #3 |
| 5 | **Deploy Dev** | Push to `main` | Auto-organizes Dev folders after Git Sync | `config/projects/*/base_workspace.yaml` |
| 6 | **Promote Dev to Test** | Push to `main` / manual | Promotes Dev workspace to Test via Deployment Pipeline | `config/projects/<project>/base_workspace.yaml` |
| 7 | **Promote Test to Prod** | `workflow_dispatch` (type "PROMOTE") | Manual promotion with safety gate | `config/projects/<project>/base_workspace.yaml` |

### Workflow Lifecycle Diagram

```
                  feature/<project>/<description>
                        |
                        v
              +---------------------+
         push | Feature Workspace   | creates isolated
              | Create              | workspace in Fabric
              +---------------------+
                        |
                   Open PR -> CI runs
                        |
                   Merge PR to main
                        |
              +---------------------+
       merge  | Feature Workspace   | destroys feature
              | Cleanup             | workspace (safe mode)
              +---------------------+
                        |
              +---------------------+
  push main   | Deploy Dev          | auto-organizes folders
              |                     |
  dispatch    | Promote             | Dev -> Test (auto or manual)
              | Dev -> Test         |
              +---------------------+
                        |
              +---------------------+
     manual   | Promote             | Test -> Prod (manual)
              | Test -> Prod        | type "PROMOTE" to confirm
              +---------------------+
```

---

## Common Operations

### First-Time Setup (Per Project)

1. Configure all secrets in GitHub
2. Go to **Actions** -> **Setup Base Workspaces** -> **Run workflow**
3. Select environment (`dev`)
4. Wait for completion -> verify in [Fabric Portal](https://app.fabric.microsoft.com)

### Create a Feature Branch

```bash
# Branch naming convention: feature/<project>/<description>
git checkout -b feature/demo/add-gold-table
git push origin feature/demo/add-gold-table
# -> Workflow auto-creates workspace
```

### Merge and Promote

```bash
# 1. Open PR -> CI validates -> reviewers approve -> merge
# 2. Feature workspace auto-destroyed
# 3. Dev folders auto-organized (deploy-dev.yml)
# 4. Promote Dev -> Test: auto on push to main (or manual dispatch)
# 5. For Test -> Prod: Actions -> Promote Test to Prod -> type "PROMOTE"
```

### Scaffold Config from an Existing Workspace (v1.8.3+)

> **Scaffold reads only** -- it does not create or modify anything in Fabric.

```bash
# Using Make (recommended)
make scaffold workspace="My Workspace [DEV]"
make scaffold workspace="My Workspace [DEV]" slug=my_project feature=true

# Then create the project from the scaffolded template
make new-project project=my_project display="My Project" template=my_project

# Or use the CLI directly
fabric-cicd scaffold "My Workspace [DEV]"
fabric-cicd scaffold "My Workspace [DEV]" --include-feature-template
```

See [Onboarding Existing Workspaces](ONBOARDING_EXISTING_WORKSPACES.md) for the full walkthrough.

### Folder Discovery (automatic in CI)

New folders created in feature workspaces are automatically discovered by the CI
pipeline when you open a PR from a `feature/*` branch. The job updates the YAML
config and auto-commits the changes to your PR branch.

```bash
# Manual discovery (CLI)
fabric-cicd discover-folders config/projects/<project>/base_workspace.yaml \
    --branch feature/<project>/<description>

# Dry run -- see what would change without writing
fabric-cicd discover-folders config/projects/<project>/base_workspace.yaml \
    --workspace "My Feature Workspace" --dry-run
```

### Update CLI Version

When a new CLI version is released:

1. Update `CLI_REPO_REF` variable: **Settings -> Variables -> Actions -> CLI_REPO_REF** -> new tag
2. Update fallback versions in workflow files (search for `v1.8.3` in `.github/workflows/`)

### Manual Feature Workspace Cleanup

If auto-cleanup didn't run (e.g., PR was closed without merge):

1. Go to **Actions** -> **Feature Workspace Cleanup** -> **Run workflow**
2. Enter the branch name (e.g., `feature/demo/old-branch`)
3. Optionally set `force_destroy_populated` to `true` if workspace has items

---

## Secrets x Workflow Matrix

Which secrets are needed by which workflow:

| Secret | Setup | Create | Cleanup | Deploy Dev | Dev->Test | Test->Prod |
|--------|:-----:|:------:|:-------:|:----------:|:---------:|:----------:|
| `AZURE_TENANT_ID` | Y | Y | Y | Y | Y | Y |
| `AZURE_CLIENT_ID` | Y | Y | Y | Y | Y | Y |
| `AZURE_CLIENT_SECRET` | Y | Y | Y | Y | Y | Y |
| `FABRIC_GITHUB_TOKEN` | Y | Y | Y | Y | Y | Y |
| `FABRIC_CAPACITY_ID` | Y | Y | -- | Y | Y | Y |
| `FABRIC_CAPACITY_ID_TEST` | Y | Y | -- | -- | Y | Y |
| `FABRIC_CAPACITY_ID_PROD` | Y | Y | -- | -- | Y | Y |
| `ADDITIONAL_ADMIN_PRINCIPAL_ID` | Y | Y | Y | Y | -- | -- |
| `ADDITIONAL_CONTRIBUTOR_PRINCIPAL_ID` | Y | Y | Y | Y | -- | -- |
| Project-specific (`*_ADMIN_ID`, `*_MEMBERS_ID`) | Y | Y | -- | Y | -- | -- |

---

## Config File Structure

```
config/projects/
+-- _templates/                    # Template configs (scaffolded or default)
|   +-- standard_data_product/
|       +-- base_workspace.yaml
|       +-- feature_workspace.yaml
+-- demo/
|   +-- base_workspace.yaml        # Dev + Pipeline + Test + Prod
|   +-- feature_workspace_demo.yaml # Feature branch template
+-- sales_analytics/
    +-- base_workspace.yaml
    +-- feature_workspace.yaml
```

Each project has two configs:

- **`base_workspace.yaml`**: Defines the main Dev workspace, folder structure, resources, principals, Git connection, and Deployment Pipeline (with Test + Prod stage workspaces).
- **`feature_workspace.yaml`**: Lightweight template for feature branch workspaces -- fewer resources, same folder structure, Git-connected to the feature branch.

---

## Feature Branch Naming Convention

```
feature/<project>/<description>
```

> **Important**: Only the `feature/` prefix triggers automated workspace creation and cleanup.
> Other prefixes like `feat/`, `fix/`, or `hotfix/` will **not** trigger the feature workspace lifecycle.
> This is by design — use `feature/` for isolated Fabric workspace development.

| Branch | Auto-detected Config | Workspace Name |
|--------|---------------------|---------------|
| `feature/demo/add-gold-table` | `config/projects/demo/feature_workspace_demo.yaml` | `<prefix>-dev-add-gold-table` |
| `feature/sales_analytics/fix-etl` | `config/projects/sales_analytics/feature_workspace.yaml` | `<prefix>-sales-dev-fix-etl` |
| `feature/generic-change` | Falls back to `$FEATURE_WORKSPACE_CONFIG` variable | `<prefix>-dev-generic-change` |

---

## Troubleshooting Quick Fixes

| Issue | Check | Fix |
|-------|-------|-----|
| Workflow fails at "Install CLI" | `FABRIC_GITHUB_TOKEN` secret | Regenerate PAT with `repo` scope |
| "Capacity not found" | `FABRIC_CAPACITY_ID` values | Verify GUIDs in Fabric Admin portal |
| Feature workspace not created | Branch naming | Must match `feature/**` pattern |
| Cleanup didn't run | PR merged? | Cleanup only triggers on merged PRs. Run manually if closed without merge. |
| Promotion fails | Pipeline name | Ensure `deployment_pipeline.pipeline_name` in config matches exactly |
| "PROMOTE" confirmation rejected | Exact text | Type exactly `PROMOTE` (all caps) |
| Exit code 2 on cleanup | Workspace has items | Use manual cleanup with `force_destroy_populated: true` |
| Items in wrong folders after sync | `folder_rules` missing | Update `folder_rules` in `base_workspace.yaml` or run `fabric-cicd discover-folders` |
| Folders not auto-organized | `deploy-dev.yml` not running | Verify the workflow is enabled and pushes to `main` trigger it |

For more, see [Replication Guide -- Troubleshooting](REPLICATION_GUIDE.md).
