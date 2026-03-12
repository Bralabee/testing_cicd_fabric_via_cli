# GitHub Copilot Instructions for Fabric CI/CD Test Repo

**Consumer repository** demonstrating the complete Microsoft Fabric CI/CD lifecycle — from environment setup through feature branch development to Deployment Pipeline promotion — using `usf_fabric_cli_cicd` CLI and GitHub Actions.

## 🏗 Architecture

This is a **consumer repo** — it doesn't contain application code. It demonstrates the full lifecycle:

```
PHASE 1 — SETUP (once):
  workflow_dispatch → setup-base-workspaces.yml
    → fabric-cicd deploy base_workspace.yaml
    → Dev workspace created + Deployment Pipeline provisioned + Test/Prod workspaces assigned

PHASE 2 — FEATURE DEVELOPMENT (per feature):
  Developer pushes feature/X
    → feature-workspace-create.yml → Workspace created + Git-connected
  Developer merges PR to main
    → feature-workspace-cleanup.yml → Workspace destroyed, capacity freed

PHASE 3 — PROMOTION (after merge):
  Push to main → promote-dev-to-test.yml → Auto-promote Dev → Test
  workflow_dispatch → promote-test-to-prod.yml → Manual promote Test → Prod
```

### Project Structure
```
fabric_cicd_test_repo/
├── .github/
│   ├── workflows/                         # Option A — single-project workflows (active)
│   │   ├── ci.yml                        # CI validation (YAML lint, secret scan)
│   │   ├── setup-base-workspaces.yml     # One-time Dev workspace + Deployment Pipeline setup
│   │   ├── feature-workspace-create.yml  # Auto-provision on feature/* push
│   │   ├── feature-workspace-cleanup.yml # Auto-destroy on PR merge to main
│   │   ├── promote-dev-to-test.yml       # Auto-promote Dev → Test on push to main
│   │   └── promote-test-to-prod.yml      # Manual promote Test → Prod
│   ├── multi-project-workflows/           # Option B — multi-project alternative (inactive)
│   │   ├── ci.yml
│   │   ├── setup-base-workspaces.yml
│   │   ├── feature-workspace-create.yml
│   │   ├── feature-workspace-cleanup.yml
│   │   ├── promote-dev-to-test.yml
│   │   └── promote-test-to-prod.yml
│   ├── copilot-instructions.md
│   ├── PULL_REQUEST_TEMPLATE.md
│   ├── CODEOWNERS
│   └── dependabot.yml
├── config/
│   └── projects/
│       ├── demo/                              # Demo project configs
│       │   ├── base_workspace.yaml            # Dev workspace + Deployment Pipeline config
│       │   └── feature_workspace_demo.yaml    # Feature branch workspace template
│       └── sales_analytics/                   # Sales Analytics project configs
│           ├── base_workspace.yaml
│           └── feature_workspace.yaml
├── docs/
│   ├── REPLICATION_GUIDE.md               # How to fork/replicate this repo
│   ├── WORKFLOW_OPTIONS.md                # Option A vs Option B comparison
│   └── E2E_VALIDATION_REPORT.md           # Live test results
└── README.md
```

## 🔐 Required Secrets

Configure in **Settings → Secrets and variables → Actions**:

| Secret | Purpose |
|--------|---------|
| `AZURE_TENANT_ID` | Entra ID tenant |
| `AZURE_CLIENT_ID` | Service Principal app ID |
| `AZURE_CLIENT_SECRET` | Service Principal secret |
| `FABRIC_GITHUB_TOKEN` | PAT for Fabric Git integration |
| `FABRIC_CAPACITY_ID` | Fabric capacity for workspaces |
| `DEV_ADMIN_OBJECT_ID` | Object ID for workspace admin |

## 🛠 Workflows

### Setup Base Workspaces (`setup-base-workspaces.yml`)
- **Trigger**: `workflow_dispatch` (manual, run once)
- **Action**: Deploys Dev workspace, creates Deployment Pipeline, provisions Test/Prod workspaces
- **Config**: Uses `config/projects/demo/base_workspace.yaml`

### Feature Workspace Create (`feature-workspace-create.yml`)
- **Trigger**: Push to `feature/**` branch
- **Action**: Installs CLI, deploys workspace with Git connection
- **Config**: Uses `config/projects/demo/feature_workspace_demo.yaml`

### Feature Workspace Cleanup (`feature-workspace-cleanup.yml`)
- **Trigger**: PR merged to `main` (auto) or `workflow_dispatch` (manual)
- **Action**: Destroys the feature workspace, frees capacity
- **Safety**: Uses `--safe` by default — populated workspaces (with Fabric items) are protected. Use `force_destroy_populated: true` input to override.
- **Exit code 2**: Indicates safety block — workspace was NOT deleted because it contains items

### Promote Dev → Test (`promote-dev-to-test.yml`)
- **Trigger**: Push to `main` (auto, after PR merge)
- **Action**: Waits for Fabric Git Sync, then promotes via Deployment Pipeline
- **Config**: Reads `pipeline_name` from `base_workspace.yaml`

### Promote Test → Prod (`promote-test-to-prod.yml`)
- **Trigger**: `workflow_dispatch` with safety gate (type "PROMOTE")
- **Action**: Promotes Test stage content to Production via Deployment Pipeline

## 📝 Configuration

### Base Workspace (`config/projects/demo/base_workspace.yaml`)
- Defines the Dev workspace connected to `main` branch
- Includes `deployment_pipeline:` section with pipeline name and stage workspace names
- Used by setup and promotion workflows

### Feature Workspace (`config/projects/demo/feature_workspace_demo.yaml`)
- Uses `${VAR_NAME}` env var substitution for all secrets
- Workspace name derived from branch name
- Resources, lakehouses, and notebooks defined declaratively

## ⚠️ Important Notes

1. **No application code here** — this repo only contains config + workflow definitions
2. **CLI comes from upstream**: `usf_fabric_cli_cicd` is installed at workflow runtime
3. **Secrets must be configured** in GitHub repo settings before any workflow runs
4. **Branch naming**: Only `feature/**` branches trigger workspace creation
5. **Capacity limits**: F2 trial capacity has low limits — clean up stale workspaces
6. **CLI version sync**: When a new CLI version is released, update the `CLI_REPO_REF` repo variable AND the fallback version in all workflow `pip install` lines

## 🔗 Related Projects

- **usf_fabric_cli_cicd**: The CLI library this repo consumes (v1.8.2)
- **usf-fabric-cicd**: Legacy monolith version

## 🔄 CI/CD Protocols (MANDATORY)

### Quality Gate — Every PR Must Pass
All changes must pass the automated CI pipeline before merge:
1. **YAML Validation**: All config files must parse without errors
2. **No Hardcoded Secrets**: Environment variable placeholders (`${VAR_NAME}`) enforced
3. **Workflow Syntax**: GitHub Actions YAML files must be valid

### Commit Message Convention
Follow [Conventional Commits](https://www.conventionalcommits.org/):
```
feat: add new workspace resources to config
fix: correct capacity_id placeholder
docs: update README with new secrets
ci: upgrade action versions
chore: update CLI version reference
```

### PR Requirements
- Fill out PR template completely
- All CI checks pass (green)
- No secrets or hardcoded values committed
- Tested with real feature workspace lifecycle (if workflow changes)

### Docs Freshness Audit (every commit)
Before final commit, verify all docs reflect true state: CLI version refs match `CLI_REPO_REF`, workflow counts match `ls .github/workflows/*.yml | wc -l`, file listings match actual directories. Grep for old version strings and archived tool references.

### Dependency Management
- **Dependabot** monitors GitHub Actions dependencies weekly
