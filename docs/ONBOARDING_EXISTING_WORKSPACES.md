# Onboarding Existing Fabric Workspaces into CI/CD

> **Audience**: Data Engineers, Project Admins
> **Last Updated**: 9 March 2026

This guide explains how to bring an **existing** Microsoft Fabric workspace (one that already has items like lakehouses, pipelines, notebooks, etc.) into the automated CI/CD workflow using the `usf_fabric_cli_cicd` CLI and GitHub Actions.

---

## Overview

The process has **3 phases**:

```
Phase 1 -- CONFIGURE (one-time, ~30 min)
  Create a YAML config that matches your existing workspace structure
  Create project via `make new-project` (auto-updates workflow dropdowns)

Phase 2 -- CONNECT (one-time, ~15 min)
  Set GitHub Secrets for your project credentials
  Run the CLI deploy -> connects Git, assigns principals, creates pipeline
  (Workspace already exists -> CLI skips creation, only adds Git + access)

Phase 3 -- USE (daily workflow)
  Create feature workspaces via GitHub Actions
  Develop -> Commit -> PR -> Merge -> Auto-sync Dev -> Manual promote
```

---

## Prerequisites

| Requirement | Details |
|:---|:---|
| **Existing Fabric workspace** | The Dev workspace you want to onboard |
| **GitHub repo access** | Push access to the consumer repository |
| **Service Principal** | `AZURE_CLIENT_ID` / `AZURE_CLIENT_SECRET` / `AZURE_TENANT_ID` |
| **Workspace Admin** | The Service Principal must be Admin on the existing workspace |
| **Fabric Capacity ID** | The capacity GUID your workspace runs on |

---

## Phase 1: Create the YAML Configuration

### Shortcut: Auto-Generate from Live Workspace

Instead of manually inspecting and writing YAML, you can **auto-scaffold** the config directly from your existing workspace.

> **Important**: Scaffolding does **not** create anything in Fabric. It reads an existing workspace and generates the YAML config files that let our CLI manage it going forward. Think of it as an **adopt/import** operation for workspaces that already exist.

**Option A -- Using Make (recommended, from within the consumer repo):**

```bash
# Basic -- generates base_workspace.yaml into _templates/
make scaffold workspace="RDSC Supply Chain [DEV]"

# With explicit slug name
make scaffold workspace="RDSC Supply Chain [DEV]" slug=rdsc_supply_chain

# With feature template and deployment pipeline
make scaffold workspace="RDSC Supply Chain [DEV]" feature=true pipeline=true
```

**Option B -- Using the CLI directly:**

```bash
# Basic -- generates base_workspace.yaml
fabric-cicd scaffold "RDSC Supply Chain [DEV]"

# With feature template and deployment pipeline
fabric-cicd scaffold "RDSC Supply Chain [DEV]" \
    --include-feature-template \
    --pipeline-name "RDSC Supply Chain - Pipeline"

# Custom output path
fabric-cicd scaffold "RDSC Supply Chain [DEV]" \
    --output config/projects/_templates/rdsc_supply_chain/base_workspace.yaml \
    --include-feature-template
```

**What it does:**

1. Connects to the live workspace via Fabric REST API
2. Discovers all folders and items (lakehouses, notebooks, pipelines, etc.)
3. Auto-generates `base_workspace.yaml` with folder rules, item inventory, and `${VAR}` placeholders
4. Optionally generates `feature_workspace.yaml` template

**Output**: `config/projects/_templates/<slug>/base_workspace.yaml` (and optionally `feature_workspace.yaml`)

> **Why `_templates/`?** Scaffolded configs land in the templates directory -- not directly in `config/projects/<project>/` -- so they are clearly templates that need review before use. Copy them to a project folder when ready (see below).

> **Prerequisites**: The Service Principal credentials (`AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, `AZURE_TENANT_ID`) must be set in your environment or `.env` file. The SP must have at least Viewer access on the target workspace.

> **Built-in validation** -- The `scaffold` command doubles as a connectivity and credential check. A successful scaffold run confirms that your credentials and Fabric API connectivity are all working.

After running the scaffold command, **review the generated YAML** in `config/projects/_templates/<slug>/`, then create the project:

```bash
# Recommended: Use Makefile (handles placeholder replacement + workflow dropdown update)
make new-project project=rdsc_supply_chain display="RDSC Supply Chain" template=rdsc_supply_chain

# Or copy manually
cp -r config/projects/_templates/rdsc_supply_chain/ config/projects/rdsc_supply_chain/
```

> **End-to-end flow**: `make scaffold` generates the template, then `make new-project template=<slug>` consumes it. The `template=` parameter tells `new-project` which template directory under `_templates/` to copy from (defaults to `standard_data_product` if omitted).

- **If you used `--include-feature-template`**: Both files were generated. Review them and skip to Step 1.5.
- **If you did NOT use `--include-feature-template`**: Only `base_workspace.yaml` was generated. Copy the feature template and edit it:
  ```bash
  cp config/projects/_templates/standard_data_product/feature_workspace.yaml config/projects/<your_project_slug>/
  ```

If you prefer to write the YAML manually from scratch, follow the steps below.

---

### Step 1.1 -- Inspect Your Existing Workspace (Manual Method)

Open your workspace in the [Fabric portal](https://app.fabric.microsoft.com) and note:

1. **Workspace name** -- e.g., `HR Analytics [DEV]`
2. **Folder structure** -- list all folders (e.g., `000 Orchestrate`, `200 Store`, etc.)
3. **Items** -- note what types exist (Lakehouses, Pipelines, Notebooks, etc.)
4. **Who needs access** -- admin groups, member groups

> **Important**: If your workspace has special characters in the name (e.g., `*`, `#`), rename it first. These characters cause issues with the Fabric CLI.

### Step 1.2 -- Copy the Template

```bash
# From the consumer repo root
cp -r config/projects/_templates/standard_data_product config/projects/<your_project_slug>
```

### Step 1.3 -- Edit `base_workspace.yaml`

Update every line marked with `<- CHANGE`:

```yaml
workspace:
  name: "HR Analytics [DEV]"           # <- Must match EXACTLY what's in Fabric
  display_name: "HR Analytics [DEV]"
  description: HR Analytics data product workspace
  capacity_id: ${FABRIC_CAPACITY_ID}
  git_repo: ${GIT_REPO_URL}
  git_branch: main
  git_directory: /hr_analytics          # <- Must match the config folder name
```

**Folder structure** -- adjust to match what's already in your workspace:

```yaml
folders:
  - Bronze
  - Silver
  - Gold
```

> If your workspace uses the 8-folder convention (e.g., `000 Orchestrate`, `100 Ingest`, etc.), list those names instead.

**Folder rules** -- these tell the auto-organize step (`deploy-dev.yml`) which folder to place each item type into after Git Sync:

```yaml
folder_rules:
  - type: DataPipeline
    folder: "000 Orchestrate"
  - type: Lakehouse
    folder: "200 Store"
  - type: Notebook
    folder: "300 Prepare"
  - type: SemanticModel
    folder: "400 Model"
  - type: Report
    folder: "500 Visualize"
```

> Fabric Git Sync always places items at the workspace root. The `folder_rules` section defines how `organize-folders` moves them back into the right folders after sync. Adjust the mapping to match your folder structure.

**Items** -- for existing workspaces, you typically **do NOT** define items in the YAML. The existing items will sync via Git:

```yaml
lakehouses: []
notebooks: []
resources: []
```

**Principals** -- update the project-specific principal variable names:

```yaml
principals:
  - id: "${AZURE_CLIENT_ID}"
    type: ServicePrincipal
    role: Admin
    description: Automation Service Principal

  - id: "${ADDITIONAL_ADMIN_PRINCIPAL_ID}"
    type: Group
    role: Admin
    description: IT governance admin group

  - id: "${ADDITIONAL_CONTRIBUTOR_PRINCIPAL_ID}"
    type: Group
    role: Contributor
    description: Governance contributor group

  - id: "${HR_ANALYTICS_ADMIN_ID}"
    type: Group
    role: Admin
    description: "HR Analytics admins"

  - id: "${HR_ANALYTICS_MEMBERS_ID}"
    type: Group
    role: Member
    description: "HR Analytics team members"
```

**Deployment Pipeline:**

```yaml
deployment_pipeline:
  pipeline_name: "HR Analytics - Pipeline"
  stages:
    development:
      workspace_name: "HR Analytics [DEV]"
      capacity_id: ${FABRIC_CAPACITY_ID}
    test:
      workspace_name: "HR Analytics [TEST]"
      capacity_id: ${FABRIC_CAPACITY_ID_TEST:-FABRIC_CAPACITY_ID}
    production:
      workspace_name: "HR Analytics [PROD]"
      capacity_id: ${FABRIC_CAPACITY_ID_PROD:-FABRIC_CAPACITY_ID}
```

### Step 1.4 -- Edit `feature_workspace.yaml`

Update the `git_directory` and principal variable names to match your project.

### Step 1.5 -- Create the Git Directory

```bash
# Create the sync directory at repo root (Fabric Git Sync writes here)
mkdir -p hr_analytics
touch hr_analytics/.gitkeep
```

---

## Phase 2: Set Secrets and Deploy

### Step 2.1 -- Set GitHub Secrets

Go to **GitHub -> Settings -> Secrets and variables -> Actions** and add:

| Secret Name | Description |
|:---|:---|
| `AZURE_TENANT_ID` | Azure AD tenant ID (already set globally if repo has other projects) |
| `AZURE_CLIENT_ID` | Service Principal app ID |
| `AZURE_CLIENT_SECRET` | Service Principal secret |
| `SP_OBJECT_ID` | Service Principal Object ID |
| `FABRIC_CAPACITY_ID` | Fabric capacity GUID (Dev) |
| `FABRIC_GITHUB_TOKEN` | GitHub PAT for Fabric Git integration |
| `HR_ANALYTICS_ADMIN_ID` | Your project admin group Object ID |
| `HR_ANALYTICS_MEMBERS_ID` | Your project member group Object ID |

> **Finding Object IDs**: Go to Azure Portal -> Entra ID -> Groups -> search for your group -> copy the Object ID.

### Step 2.2 -- Add Project to Workflow Dropdowns

> **If you used `make new-project`**: The workflow dropdowns were already updated automatically. You only need to add the secret env vars to workflow `env:` blocks.

If you created the project manually, add it to the `options:` list in:
- `.github/workflows/setup-base-workspaces.yml`
- `.github/workflows/promote-test-to-prod.yml`

### Step 2.3 -- Commit and Push

```bash
git add config/projects/hr_analytics/
git add hr_analytics/.gitkeep
git add .github/workflows/
git commit -m "feat: add HR Analytics project configuration"
git push origin main
```

### Step 2.4 -- Run Base Workspace Setup

Go to **GitHub -> Actions -> "Setup Base Workspaces" -> Run workflow**:
- Select your project from the dropdown
- Environment: `dev`
- Click **Run workflow**

**What happens for an existing workspace:**

1. CLI detects the workspace already exists -- **skips creation** (idempotent)
2. Creates folders if they don't exist -- skips existing ones
3. Assigns principals (admin groups, member groups)
4. Connects Git integration to the repository
5. Creates the Deployment Pipeline + Test/Prod workspaces

> **The CLI will NOT overwrite or delete existing items.** It only adds what's missing.

---

## Phase 3: Daily Workflow

### Creating a Feature Workspace

**Option A: From GitHub UI (recommended)**

1. Go to **Actions -> "Create Feature Workspace"**
2. Click **Run workflow**
3. Enter feature name: `add-gold-table`
4. Click **Run workflow**

**Option B: From VS Code / CLI**

```bash
git checkout -b feature/hr_analytics/add-gold-table
git push origin feature/hr_analytics/add-gold-table
```

The push triggers the GitHub Action automatically.

### Making Changes

1. Open the feature workspace in Fabric
2. Make your changes (add pipelines, modify notebooks, etc.)
3. In Fabric, click **Source control -> Commit** to push changes to your feature branch
4. In GitHub, create a **Pull Request** from your feature branch -> `main`
5. Review and **Merge** the PR

### What Happens on Merge

1. Cleanup workflow triggers and destroys the feature workspace (`--safe` mode by default)
2. Dev workspace auto-syncs from `main` via Fabric Git Sync
3. `deploy-dev.yml` auto-runs and organizes items into folders based on `folder_rules`

> **Key caveat -- Fabric Git Sync and folders**: Git Sync does **not** store folder assignments in Git metadata. When content syncs into a workspace, all items land at the workspace root. The `organize-folders` command reads your `folder_rules` and moves items back into the correct folders. This is why keeping `folder_rules` up to date in your YAML is critical.
>
> **Automatic folder discovery**: The CI pipeline can include a `discover-folders` job that scans feature workspaces on PRs from `feature/*` branches. It automatically detects new folders or item-to-folder mappings and commits updates to the PR's YAML config.

### Promoting to Test and Production

1. **Dev -> Test**: Automatic on push to `main` (or manual dispatch)
2. **Test -> Prod**: Manual trigger via **Actions -> "Promote Test -> Prod"** (requires typing "PROMOTE" for safety)

---

## Checklist for New Project Onboarding

- [ ] Workspace name has no special characters (`*`, `#`, etc.)
- [ ] Service Principal is Admin on the existing workspace
- [ ] `config/projects/<project>/base_workspace.yaml` created and matches workspace structure
- [ ] `config/projects/<project>/feature_workspace.yaml` created with matching folders
- [ ] `folder_rules` defined for all item types in the workspace
- [ ] Git directory created at repo root: `<project>/.gitkeep`
- [ ] GitHub Secrets set for project-specific admin/member group IDs
- [ ] Project added to workflow dropdown options
- [ ] Secret env vars added to workflow `env` blocks
- [ ] Base workspace setup workflow ran successfully
- [ ] Able to create a feature workspace from the GitHub UI

---

## Troubleshooting

> **Quick diagnostic**: Run `fabric-cicd scaffold "<workspace-name>"` against any workspace. A successful run confirms Service Principal authentication and Fabric REST API connectivity.

| Issue | Cause | Fix |
|:---|:---|:---|
| "Workspace creation failed" | Workspace name mismatch | Ensure YAML `name` matches Fabric portal exactly |
| "Capacity not found" | Wrong capacity ID | Verify `FABRIC_CAPACITY_ID` secret value |
| "Insufficient permissions" | SP not workspace Admin | Add SP as Admin in Fabric workspace settings |
| scaffold returns "Workspace not found" | SP lacks access or name misspelled | Verify workspace name and SP access |
| scaffold returns authentication error | Token expired or SP credentials wrong | Re-check credentials in `.env` or environment |
| Feature workspace empty | Git sync not connected | Run base workspace setup first |
| Items in wrong folders | Folder rules mismatch | Update `folder_rules` in base_workspace.yaml |
| Cleanup didn't delete feature workspace | `--safe` mode blocked deletion | Re-run manually with `force_destroy_populated: true` |
| Template changes not reflected | Feature workspace stale | Template only matters at creation time -- recreate |
| Principal role not upgraded | CLI treats "already has a role" as success | Manually update role in Fabric portal |
| Git connection not switching repos | CLI treats "already connected" as success | Disconnect Git in Fabric portal first |

---

## Known Limitations

**1. Fabric Git Sync drops folder assignments**

Git Sync does not store folder placement in Git metadata. When content syncs into a workspace, all items land at the workspace root. The `organize-folders` CLI command (run automatically by `deploy-dev.yml` on push to `main`) moves items back to their assigned folders based on the `folder_rules` in `base_workspace.yaml`. Items without matching rules remain at the root.

**Mitigation**: Keep `folder_rules` up to date. Use `fabric-cicd discover-folders` to auto-detect new folders and rules from feature workspaces.

**2. Principal role mismatch not auto-upgraded**

If a principal already has a role on the workspace and your config specifies a different role, the Fabric API returns "already has a role assigned". The CLI treats this as idempotent success and does not upgrade the role.

**Workaround**: Manually update the principal's role in the Fabric portal, or remove the principal first and re-run setup.

---

## FAQ

**Q: Will the CLI overwrite my existing workspace items?**
A: **No.** The CLI is idempotent. If a workspace already exists, it skips creation and only adds missing configurations (Git, principals, folders). Existing items are never touched.

**Q: Do I need to define all my existing items in the YAML?**
A: **No.** For existing workspaces, leave `lakehouses: []`, `notebooks: []`, `resources: []`. Existing items sync through Git.

**Q: What if someone adds a new folder in the Fabric workspace that's not in the YAML?**
A: Items in that folder will still sync via Git, but Git Sync places all items at the workspace root. Without matching `folder_rules`, those items remain at root after sync. Use `fabric-cicd discover-folders` to detect and add the new rules, or add them manually.

**Q: Can I use different capacity IDs for Dev vs. Test vs. Prod?**
A: Yes. Add separate secrets (`FABRIC_CAPACITY_ID_TEST`, `FABRIC_CAPACITY_ID_PROD`) and reference them in the deployment pipeline stages.

**Q: Do I need to run a preflight check before onboarding?**
A: **No.** The `scaffold` command validates credentials and API connectivity as part of its normal operation. If `scaffold` succeeds, you are ready to proceed.
