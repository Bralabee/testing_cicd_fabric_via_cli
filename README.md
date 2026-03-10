# Fabric CI/CD Consumer Repo Template

**Consumer repository template** demonstrating the complete Microsoft Fabric CI/CD lifecycle with GitHub Actions -- from environment setup through feature branch development to production promotion.

> **Reusable**: This repo is designed to be forked/copied for any Fabric project.
> Customize via GitHub repo variables and YAML configs -- no code changes needed.
> **CLI Version**: v1.8.0

## Repository Structure

```
fabric_cicd_test_repo/
+-- .github/
|   +-- workflows/                       # 7 GitHub Actions workflows
|       +-- ci.yml                       # CI validation (YAML lint, secret scan)
|       +-- setup-base-workspaces.yml    # One-time: provision Dev + Pipeline
|       +-- feature-workspace-create.yml # Auto-create feature workspaces
|       +-- feature-workspace-cleanup.yml# Auto-destroy on PR merge
|       +-- deploy-dev.yml              # Auto-organize Dev folders after sync
|       +-- promote-dev-to-test.yml     # Promote Dev -> Test
|       +-- promote-test-to-prod.yml    # Promote Test -> Prod (manual gate)
+-- config/
|   +-- projects/
|       +-- _templates/                  # Scaffold and template configs
|       |   +-- standard_data_product/
|       +-- demo/                        # Demo project config
|       |   +-- base_workspace.yaml
|       |   +-- feature_workspace_demo.yaml
|       +-- sales_analytics/             # Sales Analytics project config
|           +-- base_workspace.yaml
|           +-- feature_workspace.yaml
+-- docs/                               # Documentation (5+ guides)
|   +-- 00_START_HERE.md
|   +-- 04_QUICK_REFERENCE.md
|   +-- 07_CONSUMER_REPO_SETUP_GUIDE.md
|   +-- ONBOARDING_EXISTING_WORKSPACES.md
|   +-- REPLICATION_GUIDE.md
|   +-- WORKFLOW_OPTIONS.md
|   +-- WORKFLOW_REFERENCE.md
+-- demo/                               # Git sync directory (demo project)
|   +-- .gitkeep
+-- sales_analytics/                     # Git sync directory (sales_analytics)
|   +-- .gitkeep
+-- Makefile                             # Automation (20 commands)
+-- CHANGELOG.md
+-- README.md
```

## How It Works

```
 SETUP (once)          DEVELOP (per feature)                    PROMOTE (after merge)
 -----------           ---------------------                    ---------------------
 Deploy Dev workspace  Push feature/<project>/X                 PR merged to main
 Create Deploy Pipe    -> Feature workspace auto-created        -> Feature workspace destroyed
 Assign stages         -> Developer works in isolation          -> Dev workspace Git-syncs
                       -> PR review -> Merge                    -> Dev folders auto-organized
                                                                -> Dev -> Test (auto/manual)
                                                                -> Test -> Prod (manual)
```

## Workflows

| Workflow | Trigger | Purpose |
|:---|:---|:---|
| `ci.yml` | Push/PR to `main` | CI validation (YAML lint, secret scan) |
| `setup-base-workspaces.yml` | Manual dispatch | One-time: provision Dev workspace + Deployment Pipeline |
| `feature-workspace-create.yml` | Push to `feature/**` / manual | Create isolated feature workspace |
| `feature-workspace-cleanup.yml` | PR merged to `main` / manual | Destroy feature workspace (safe mode) |
| `deploy-dev.yml` | Push to `main` | Auto-organize Dev workspace folders after Git Sync |
| `promote-dev-to-test.yml` | Push to `main` / manual | Promote Dev -> Test via Deployment Pipeline |
| `promote-test-to-prod.yml` | Manual dispatch + confirm | Promote Test -> Prod (type "PROMOTE" to confirm) |

## Project Configs

| Config | Display Name | Git Directory | Purpose |
|:---|:---|:---|:---|
| `config/projects/demo/base_workspace.yaml` | `${PROJECT_PREFIX} - Development` | `/` | Dev workspace + Deployment Pipeline |
| `config/projects/demo/feature_workspace_demo.yaml` | Feature workspace template | `/` | Feature branch workspace |
| `config/projects/sales_analytics/base_workspace.yaml` | `${PROJECT_PREFIX} Sales Analytics - Development` | `/` | Sales Analytics Dev workspace |
| `config/projects/sales_analytics/feature_workspace.yaml` | Feature workspace template | `/` | Sales Analytics feature workspace |

## Workspace Access Control

The template uses a **two-tier access model**:

**Governance tier** (applied to every workspace):
- `ADDITIONAL_ADMIN_PRINCIPAL_ID` -- IT governance admin group (Admin role)
- `ADDITIONAL_CONTRIBUTOR_PRINCIPAL_ID` -- Governance contributor group (Contributor role)

**Project tier** (per project):
- `<PROJECT>_ADMIN_ID` -- Project admin security group (Admin role)
- `<PROJECT>_MEMBERS_ID` -- Project member group (Member role)

## Required Secrets

Configure in **Settings -> Secrets and variables -> Actions**:

### Core

| Secret | Purpose |
|:---|:---|
| `AZURE_TENANT_ID` | Entra ID tenant |
| `AZURE_CLIENT_ID` | Service Principal app ID |
| `AZURE_CLIENT_SECRET` | Service Principal secret |
| `FABRIC_GITHUB_TOKEN` | PAT for Fabric Git integration |
| `SP_OBJECT_ID` | Service Principal object ID |

### Capacity

| Secret | Purpose |
|:---|:---|
| `FABRIC_CAPACITY_ID` | Fabric capacity for Dev workspaces |
| `FABRIC_CAPACITY_ID_TEST` | Fabric capacity for Test (falls back to Dev) |
| `FABRIC_CAPACITY_ID_PROD` | Fabric capacity for Prod (falls back to Dev) |

### Governance

| Secret | Purpose |
|:---|:---|
| `ADDITIONAL_ADMIN_PRINCIPAL_ID` | IT governance admin group Object ID |
| `ADDITIONAL_CONTRIBUTOR_PRINCIPAL_ID` | Governance contributor group Object ID |

### Project-Specific

| Secret | Project | Purpose |
|:---|:---|:---|
| `DEMO_ADMIN_ID` | demo | Admin security group OID |
| `DEMO_MEMBERS_ID` | demo | Member group OID |
| `SALES_ANALYTICS_ADMIN_ID` | sales_analytics | Admin security group OID |
| `SALES_ANALYTICS_MEMBERS_ID` | sales_analytics | Member group OID |

## Repository Variables

Configure in **Settings -> Secrets and variables -> Actions -> Variables tab**:

| Variable | Default | Purpose |
|:---|:---|:---|
| `PROJECT_PREFIX` | `fabric-cicd-demo` | Naming prefix for all workspaces and pipelines |
| `CLI_REPO_URL` | `github.com/BralaBee-LEIT/usf_fabric_cli_cicd_codebase` | URL to CLI repo (without `https://`) |
| `CLI_REPO_REF` | `v1.8.0` | Git ref (branch/tag) for CLI install |
| `FABRIC_CLI_VERSION` | `1.3.1` | Microsoft Fabric CLI version |
| `FEATURE_WORKSPACE_CONFIG` | *(auto-discovered)* | Override path to feature workspace config |

## Make Commands

### Scaffolding & Project Management

| Command | Description | Parameters |
|:---|:---|:---|
| `make new-repo` | Scaffold a brand new consumer repo | `name=<repo> project=<slug> display="<Name>"` |
| `make new-project` | Add a new project to this repo | `project=<slug> display="<Name>" [template=<name>]` |
| `make scaffold` | Generate config from existing workspace | `workspace="<Name>" [slug=<s>] [feature=true]` |
| `make list-projects` | List all configured projects | -- |
| `make validate` | Validate project YAML configs | `project=<slug>` |
| `make show-secrets` | Show required GitHub secrets | `project=<slug>` |
| `make check-structure` | Verify repo structure is correct | -- |
| `make help` | Show all available commands | -- |
| `make guide` | Open the step-by-step guide | -- |

### Git Workflow

| Command | Description | Parameters |
|:---|:---|:---|
| `make status` | Show branch, remote, and working tree status | -- |
| `make feature` | Create a feature branch | `project=<slug> name=<description>` |
| `make commit` | Stage all changes and commit | `msg="<message>"` |
| `make commit-project` | Stage and commit a project | `project=<slug>` |
| `make push` | Push current branch to remote | -- |
| `make push-new` | First push -- add remote and push main | `remote=<url>` |
| `make pr` | Create a Pull Request to main | `title="<title>" [body="<desc>"]` |
| `make log` | Show recent commit history | -- |
| `make diff` | Show uncommitted changes | -- |

## Quick Start

### 1. Fork/Copy This Repo

Fork or copy this template to your GitHub organization.

### 2. Configure GitHub Secrets

Add all required secrets in **Settings -> Secrets and variables -> Actions**.
See the [Quick Reference](docs/04_QUICK_REFERENCE.md) for the full list.

### 3. Add Your First Project

```bash
make new-project project=finance display="Finance Reporting"
```

### 4. Customise Configs

Edit `config/projects/finance/base_workspace.yaml` -- update workspace names, folders, principals.

### 5. Run Setup Workflow

```bash
# Via GitHub CLI
gh workflow run setup-base-workspaces.yml
```

Or go to **Actions -> "Setup Base Workspaces" -> Run workflow**.

### 6. Test the Lifecycle

```bash
git checkout -b feature/finance/first-test
echo "# Test" > FEATURE_NOTES.md
git add . && git commit -m "feat: test feature workspace"
git push origin feature/finance/first-test
# -> Feature workspace auto-created in Fabric
```

## Documentation

| Document | Description |
|:---|:---|
| [START HERE](docs/00_START_HERE.md) | Orientation and routing |
| [Quick Reference](docs/04_QUICK_REFERENCE.md) | Cheat sheet -- secrets, commands, configs |
| [Setup Guide](docs/07_CONSUMER_REPO_SETUP_GUIDE.md) | Hands-on setup (3 workflows) |
| [Onboarding Guide](docs/ONBOARDING_EXISTING_WORKSPACES.md) | Bring existing workspaces into CI/CD |
| [Replication Guide](docs/REPLICATION_GUIDE.md) | Complete end-to-end setup |
| [Workflow Options](docs/WORKFLOW_OPTIONS.md) | Single vs multi-project strategy |
| [Workflow Reference](docs/WORKFLOW_REFERENCE.md) | Technical workflow reference |

## Related

- **usf_fabric_cli_cicd** -- The CLI library this repo consumes. Set the `CLI_REPO_URL` repo variable to point at your fork/copy.
- See the CLI repo's `docs/01_User_Guides/10_Feature_Branch_Workspace_Guide.md` for the full lifecycle guide.
