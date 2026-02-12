# GitHub Copilot Instructions for Fabric CI/CD Test Repo

**Consumer repository** demonstrating the complete Microsoft Fabric CI/CD lifecycle — from environment setup through feature branch development to Deployment Pipeline promotion — using `usf_fabric_cli_cicd` CLI and GitHub Actions.

## 🏗 Architecture

This is a **consumer repo** — it doesn't contain application code. It demonstrates the full lifecycle:

```
PHASE 1 — SETUP (once):
  workflow_dispatch → setup-base-workspaces.yml
    → fabric-cicd deploy base_workspace.yaml → Dev workspace created
  Fabric Portal: Create Deployment Pipeline, assign Dev/Test/Prod workspaces

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
│   ├── workflows/
│   │   ├── setup-base-workspaces.yml     # One-time Dev workspace setup
│   │   ├── feature-workspace-create.yml  # Auto-provision on feature/* push
│   │   ├── feature-workspace-cleanup.yml # Auto-destroy on branch delete/merge
│   │   ├── promote-dev-to-test.yml       # Auto-promote Dev → Test on push to main
│   │   └── promote-test-to-prod.yml      # Manual promote Test → Prod
│   ├── copilot-instructions.md
│   ├── PULL_REQUEST_TEMPLATE.md
│   ├── CODEOWNERS
│   └── dependabot.yml
├── config/
│   └── projects/
│       └── demo/
│           ├── base_workspace.yaml            # Dev workspace + Deployment Pipeline config
│           └── feature_workspace_demo.yaml    # Feature branch workspace template
├── README.md
└── Makefile
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
- **Action**: Deploys Dev workspace from `base_workspace.yaml`
- **Next**: Create Deployment Pipeline in Fabric portal, assign workspaces to stages

### Feature Workspace Create (`feature-workspace-create.yml`)
- **Trigger**: Push to `feature/**` branch
- **Action**: Installs CLI, deploys workspace with Git connection
- **Config**: Uses `config/projects/demo/feature_workspace_demo.yaml`

### Feature Workspace Cleanup (`feature-workspace-cleanup.yml`)
- **Trigger**: Branch delete (after PR merge) or `workflow_dispatch`
- **Action**: Destroys the feature workspace, frees capacity

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

## 🔗 Related Projects

- **usf_fabric_cli_cicd**: The CLI library this repo consumes (v1.7.6)
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

### Dependency Management
- **Dependabot** monitors GitHub Actions dependencies weekly
