# Fabric CI/CD -- Workflow Reference (Template Repo)

> **Generated**: 9 March 2026 -- validated against CLI v1.8.1 and consumer repo template

---

## 1. Architecture & Roles

### Roles

| Role | Responsibility | Day-to-Day |
|------|---------------|------------|
| **Platform Engineer** | Maintains the CLI tool (`usf_fabric_cli_cicd`, currently v1.8.1). Pushes version updates, tags releases, and updates the `CLI_REPO_REF` variable in consumer repos. | Develops in the **product repo** (`usf_fabric_cli_cicd`). Never touches consumer configs. |
| **Data Engineer** | Day-to-day feature development -- creating branches, building pipelines, notebooks, and lakehouses inside Fabric. Interacts exclusively through the **consumer repo** via GitHub. | Works in the **consumer repo**. Never installs or runs the CLI locally (GitHub Actions handles everything). |
| **Project Admin** | One-time setup per project -- runs `make new-project`, configures secrets in GitHub, and runs the "Setup Base Workspaces" workflow. | Works in GitHub Settings -> Secrets/Variables and the Actions UI. |

### Two Repositories

| Repository | Purpose | Contains |
|---|---|---|
| **Product repo** (`usf_fabric_cli_cicd`) | The CLI tool itself. Installed at workflow runtime via `pip install git+...@v1.8.1`. | Python source code, services, utilities, templates. 14 CLI commands: `deploy`, `validate`, `diagnose`, `destroy`, `promote`, `onboard`, `generate`, `list-workspaces`, `list-items`, `bulk-destroy`, `organize-folders`, `init-github-repo`, `scaffold`, `discover-folders`. |
| **Consumer repo** (this template) | Where teams interact. Config + workflows only -- no application code, no CLI source. | `config/projects/<name>/base_workspace.yaml` + `feature_workspace.yaml` per project. 7 GitHub Actions workflows. Project root directories (`/demo/`, `/sales_analytics/`, etc.) that map to Fabric workspace Git sync directories. |

### Current Template Projects

| Project Slug | Config Path | Git Sync Directory | Description |
|---|---|---|---|
| `demo` | `config/projects/demo/` | `/demo` | Basic demo workspace (8-folder convention) |
| `sales_analytics` | `config/projects/sales_analytics/` | `/sales_analytics` | Example second project (8-folder convention) |

---

## 2. Workflow -- How It Works

### Phase 1: Initial Setup (Run Once per Project)

1. **Project Admin configures secrets** in GitHub -> Settings -> Secrets and Variables -> Actions.
2. **Project Admin creates the project** via `make new-project` (which automatically updates workflow dropdowns) or manually adds the project to the `options:` list in relevant workflow files.
3. **Project Admin creates the YAML configs** (`config/projects/<slug>/base_workspace.yaml` and `feature_workspace.yaml`). Two options:
   - **New workspace**: Copy from `config/projects/_templates/` and customise.
   - **Existing workspace**: Run `fabric-cicd scaffold "Workspace Name" --include-feature-template` to auto-generate configs.
4. **Project Admin runs** "Setup Base Workspaces" workflow (Actions -> "Setup Base Workspaces" -> Run workflow). This:
   - Creates the Dev workspace and Git-syncs it to `main`
   - Creates the Deployment Pipeline
   - Creates Test and Prod workspaces and assigns them to pipeline stages

### Phase 2: Feature Development (Repeats per Feature)

5. **Data Engineer creates a feature branch** following the naming convention `feature/<project>/<description>` (e.g., `feature/demo/add-gold-table`). Two ways:
   - **Push-triggered**: `git checkout -b feature/demo/add-gold-table && git push` -- the `feature-workspace-create.yml` fires automatically.
   - **Manual dispatch**: Actions -> "Create Feature Workspace" -> enter feature name -> Run workflow.
6. The workflow runs `fabric-cicd deploy <config> --env dev --branch <branch> --force-branch-workspace`, which:
   - Creates an isolated workspace connected to the feature branch
   - Creates lakehouses, folders, and other items defined in `feature_workspace.yaml`
   - Connects the workspace to the consumer repo via Git integration
7. **Data Engineer works in the feature workspace** in the Fabric portal -- commits go to the feature branch via Fabric Git integration.

### Phase 3: Merge & Cleanup

8. **Data Engineer opens a PR** from `feature/<project>/<description>` to `main`. The CI pipeline validates:
   - YAML syntax, credential scanning, config linting
9. **On PR merge**, two things happen automatically:
   - `feature-workspace-cleanup.yml` triggers and destroys the feature workspace (with `--safe` mode -- populated workspaces are protected).
   - `deploy-dev.yml` triggers on the `main` push and runs `fabric-cicd organize-folders` on affected Dev workspaces to move items into their correct folders.

### Phase 4: Promotion

10. **Promote Dev -> Test**: Automatic on push to `main` (via `promote-dev-to-test.yml`) or manual dispatch.
11. **Promote Test -> Prod**: Manual trigger with safety gate -- Actions -> "Promote Test -> Prod" -> type "PROMOTE" to confirm.

### All 7 Workflows

| # | Workflow | Trigger | What It Does |
|---|---|---|---|
| 1 | `ci.yml` | PR to `main` / push to `main` | YAML validation, secret scanning, config linting |
| 2 | `setup-base-workspaces.yml` | Manual dispatch (once per project) | Creates Dev + Test + Prod workspaces, Deployment Pipeline, Git integration |
| 3 | `feature-workspace-create.yml` | `feature/**` push OR manual dispatch | Creates isolated feature workspace + Git-connects to feature branch |
| 4 | `feature-workspace-cleanup.yml` | PR merged to `main` OR manual dispatch | Destroys feature workspace (safe mode by default) |
| 5 | `deploy-dev.yml` | Push to `main` | Detects changed projects, runs `organize-folders` on affected Dev workspaces |
| 6 | `promote-dev-to-test.yml` | Push to `main` / manual dispatch | Promotes Dev -> Test via Fabric Deployment Pipeline |
| 7 | `promote-test-to-prod.yml` | Manual dispatch + safety gate | Promotes Test -> Prod via Fabric Deployment Pipeline |

---

## 3. Secrets & Configuration

### How Secrets Flow

The CLI uses environment variable loading to resolve credentials in priority order:
1. **Environment variables** (set by GitHub Actions `env:` blocks, sourced from GitHub Secrets)
2. **`.env` file** (local development only)
3. **Azure Key Vault** (optional, if `AZURE_KEYVAULT_URL` is configured)

The YAML configs use `${VAR_NAME}` syntax for variable substitution. The variable names in YAML **must match** the environment variable names set in GitHub Actions, which in turn reference GitHub Secrets with the same names.

### Secrets vs Variables

| Type | Where Set | Visibility | Examples |
|---|---|---|---|
| **GitHub Secrets** | Settings -> Secrets -> Actions | Write-once, never viewable after creation | `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, `FABRIC_CAPACITY_ID` |
| **GitHub Variables** | Settings -> Variables -> Actions | Visible to anyone with repo access | `PROJECT_PREFIX`, `CLI_REPO_REF` (e.g., `v1.8.1`), `FABRIC_CLI_VERSION` |

### Required Secrets per Consumer Repo

**Global (shared across all projects):**

| Secret | Purpose |
|---|---|
| `AZURE_TENANT_ID` | Entra ID tenant |
| `AZURE_CLIENT_ID` | Service Principal app ID |
| `AZURE_CLIENT_SECRET` | Service Principal secret |
| `SP_OBJECT_ID` | Service Principal object ID (for workspace access) |
| `FABRIC_GITHUB_TOKEN` | GitHub PAT for Fabric Git integration and CLI installation |
| `FABRIC_CAPACITY_ID` | Default Fabric capacity for Dev workspaces |
| `FABRIC_CAPACITY_ID_TEST` | Fabric capacity for Test workspaces (falls back to `FABRIC_CAPACITY_ID`) |
| `FABRIC_CAPACITY_ID_PROD` | Fabric capacity for Prod workspaces (falls back to `FABRIC_CAPACITY_ID`) |
| `ADDITIONAL_ADMIN_PRINCIPAL_ID` | Governance admin group (applied to all workspaces) |
| `ADDITIONAL_CONTRIBUTOR_PRINCIPAL_ID` | Governance contributor group (applied to all workspaces) |

**Per-project (add a pair for each new project):**

| Secret Pattern | Purpose |
|---|---|
| `<PROJECT>_ADMIN_ID` | Project admin security group Object ID (e.g., `DEMO_ADMIN_ID`) |
| `<PROJECT>_MEMBERS_ID` | Project members security group Object ID (e.g., `DEMO_MEMBERS_ID`) |

### Adding a New Project Checklist

1. Create `config/projects/<slug>/base_workspace.yaml` and `feature_workspace.yaml`
2. Create the project root directory: `mkdir <slug> && touch <slug>/.gitkeep`
3. Add `<PROJECT>_ADMIN_ID` and `<PROJECT>_MEMBERS_ID` secrets in GitHub
4. Add the project slug to the `options:` list in workflow dispatch workflows
5. Add the secret env mappings to all workflow `env:` blocks
6. Commit and push to `main`
7. Run "Setup Base Workspaces" workflow selecting the new project

---

## 4. Key Design Decisions

### GitHub Is the Single Source of Truth

All workspace lifecycle operations go through GitHub:
- Workspace creation -> push `feature/**` branch or manual dispatch
- Content changes -> Fabric Git Sync keeps workspace <-> repo in sync
- Workspace destruction -> merge PR to `main`
- Promotion -> manual dispatch

Working directly in the Fabric portal is supported for content editing (notebooks, pipelines) because Fabric Git Integration commits changes back to the branch. But **workspace creation, deletion, and promotion must go through GitHub Actions** to ensure audit trail and consistent behaviour.

### Don't Merge Until Done

Merging a feature branch to `main` triggers:
1. Feature workspace cleanup -- the workspace is destroyed
2. Dev workspace folder organisation via `deploy-dev.yml`

The `--safe` flag on cleanup protects against accidental deletion -- if the workspace still contains Fabric items, it will not be deleted (exit code 2). The Data Engineer must either ensure all content is committed/synced before merging, or use `force_destroy_populated: true` on the manual cleanup dispatch.

### Templates Must Be Kept in Sync with Workspace Structure

The YAML configs define:
- `folders:` -- the folder structure in the workspace
- `folder_rules:` -- rules mapping item types to folders

If new items are created in the workspace that don't match any `folder_rules` entry, they will remain at the workspace root after Git Sync. The `organize-folders` command (run automatically by `deploy-dev.yml` on push to `main`) only moves items that match a rule.

**Solution**: Use `fabric-cicd discover-folders` to detect new folders and rules, or re-run `fabric-cicd scaffold` to regenerate configs with the current workspace structure.

### Organize-Folders After Git Sync

Fabric Git Sync does not preserve folder assignments. When content syncs into a workspace via Git, all items land at the workspace root. The `deploy-dev.yml` workflow runs `organize-folders` after every push to `main`, reading the `folder_rules` from each project's `base_workspace.yaml` and moving items into their designated folders.

---

## 5. CLI Commands Reference

All commands available via `fabric-cicd <command>`:

| Command | Purpose | Used By |
|---|---|---|
| `deploy` | Deploy workspace from YAML config | GitHub Actions (setup, feature create) |
| `validate` | Validate YAML config without deploying | Local development |
| `diagnose` | Pre-flight checks (CLI version, auth, API connectivity) | Local development |
| `destroy` | Destroy workspace (with `--safe` mode) | GitHub Actions (feature cleanup) |
| `promote` | Promote via Fabric Deployment Pipeline | GitHub Actions (dev->test, test->prod) |
| `onboard` | Generate config + deploy in one step | Local development |
| `generate` | Generate project config from blueprint template | Local development |
| `list-workspaces` | List accessible Fabric workspaces | Debugging |
| `list-items` | List items in a workspace | Debugging |
| `bulk-destroy` | Destroy multiple workspaces by pattern | Cleanup / Admin |
| `organize-folders` | Move workspace items into folders per rules | GitHub Actions (deploy-dev) |
| `init-github-repo` | Initialize a new GitHub repo for a project | One-time setup |
| `scaffold` | Reverse-engineer YAML config from existing workspace (read-only) | Existing workspace onboarding |
| `discover-folders` | Scan workspace for new folders/rules, update YAML config | CI pipeline (pre-merge), manual |
