# GitHub Copilot Instructions for Fabric CI/CD Test Repo

**Consumer repository** for testing the `usf_fabric_cli_cicd` Feature Branch Workspace automation pattern with Microsoft Fabric and GitHub Actions.

## 🏗 Architecture

This is a **consumer repo** — it doesn't contain application code. It demonstrates the automated feature workspace lifecycle:

```
Developer pushes feature/X branch
  → GitHub Actions: feature-workspace-create.yml
    → Installs CLI from BralaBee-LEIT/usf_fabric_cli_cicd
      → fabric-cicd deploy → Fabric workspace created + Git-connected

Developer merges PR to main
  → GitHub Actions: feature-workspace-cleanup.yml
    → fabric-cicd destroy → Workspace deleted, capacity freed
```

### Project Structure
```
fabric_cicd_test_repo/
├── .github/
│   ├── workflows/
│   │   ├── feature-workspace-create.yml  # Auto-provision on feature/* push
│   │   └── feature-workspace-cleanup.yml # Auto-destroy on branch delete/merge
│   ├── copilot-instructions.md
│   ├── PULL_REQUEST_TEMPLATE.md
│   ├── CODEOWNERS
│   └── dependabot.yml
├── config/
│   └── projects/
│       └── demo/
│           └── feature_workspace_demo.yaml  # Workspace config template
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

## 🛠 Workflows

### Feature Workspace Create (`feature-workspace-create.yml`)
- **Trigger**: Push to `feature/**` branch
- **Action**: Installs CLI, deploys workspace with Git connection
- **Config**: Uses `config/projects/demo/feature_workspace_demo.yaml`

### Feature Workspace Cleanup (`feature-workspace-cleanup.yml`)
- **Trigger**: Branch delete (after PR merge) or `workflow_dispatch`
- **Action**: Destroys the feature workspace, frees capacity

## 📝 Configuration

### YAML Config (`config/projects/demo/feature_workspace_demo.yaml`)
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

- **usf_fabric_cli_cicd**: The CLI library this repo consumes (v1.7.5)
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
