# Fabric CI/CD Test Repo

**Consumer repository** demonstrating the complete Microsoft Fabric CI/CD lifecycle with GitHub Actions — from environment setup through feature branch development to production promotion.

## Full Lifecycle

```
 SETUP (once)          DEVELOP (per feature)                    PROMOTE (after merge)
 ───────────           ─────────────────────                    ─────────────────────
 Deploy Dev workspace  Push feature/X                           PR merged to main
 Create Deploy Pipe    → Feature workspace auto-created         → Feature workspace destroyed
 Assign stages         → Developer works in isolation           → Dev workspace Git-syncs
                       → PR review → Merge                     → Auto Dev → Test
                                                                → Manual Test → Prod
```

## Workflows

| Workflow | Trigger | Purpose |
|:---|:---|:---|
| `setup-base-workspaces.yml` | Manual dispatch | One-time: provision Dev workspace |
| `feature-workspace-create.yml` | Push to `feature/**` | Create isolated feature workspace |
| `feature-workspace-cleanup.yml` | PR merge / branch delete | Destroy feature workspace |
| `promote-dev-to-test.yml` | Push to `main` | Auto-promote Dev → Test via Deployment Pipeline |
| `promote-test-to-prod.yml` | Manual dispatch + confirm | Promote Test → Prod (type "PROMOTE" to confirm) |

## Project Configs

| Config | Purpose |
|:---|:---|
| `config/projects/demo/base_workspace.yaml` | Dev workspace + Deployment Pipeline definition |
| `config/projects/demo/feature_workspace_demo.yaml` | Feature branch workspace template |

## Required Secrets

Configure in **Settings → Secrets and variables → Actions**:

| Secret | Purpose |
|:---|:---|
| `AZURE_TENANT_ID` | Entra ID tenant |
| `AZURE_CLIENT_ID` | Service Principal app ID |
| `AZURE_CLIENT_SECRET` | Service Principal secret |
| `FABRIC_GITHUB_TOKEN` | PAT for Fabric Git integration |
| `FABRIC_CAPACITY_ID` | Fabric capacity for workspaces |
| `DEV_ADMIN_OBJECT_ID` | Object ID for workspace admin |

## Quick Start

### 1. Initial Setup (run once)

```bash
# Run the setup workflow in GitHub Actions
gh workflow run setup-base-workspaces.yml

# Then in Fabric portal:
# 1. Create Deployment Pipeline: fabric-cicd-demo-pipeline
# 2. Assign workspaces: Dev → Development, Test → Test, Prod → Production
```

### 2. Feature Development

```bash
git checkout -b feature/my-data-product
echo "# My Feature" > FEATURE_NOTES.md
git add . && git commit -m "feat: my-data-product"
git push origin feature/my-data-product
# → Feature workspace auto-created in Fabric
```

### 3. Merge & Promote

```bash
gh pr create --title "feat: my-data-product" --base main
gh pr merge --squash --delete-branch
# → Feature workspace destroyed
# → Dev workspace syncs main
# → Auto Dev → Test promotion triggers
```

### 4. Production Release

```
GitHub → Actions → Promote Test → Production → Run workflow → Type "PROMOTE"
```

## Related

- [usf_fabric_cli_cicd](https://github.com/BralaBee-LEIT/usf_fabric_cli_cicd_codebase) — CLI library (v1.7.6)
- [Full Lifecycle Guide](https://github.com/BralaBee-LEIT/usf_fabric_cli_cicd_codebase/blob/main/docs/01_User_Guides/10_Feature_Branch_Workspace_Guide.md)

