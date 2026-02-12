# Fabric CICD Test Repo

This repository is used to demonstrate the **Feature Branch → Workspace** automation pattern
with Microsoft Fabric and GitHub Actions.

## How It Works

### 1. Create a Feature Workspace

Push a `feature/**` branch and a Fabric workspace is automatically created and connected to it:

```bash
git checkout -b feature/my-data-product
git push origin feature/my-data-product
```

### 2. Work in Isolation

The feature workspace is fully isolated — changes in Fabric are tracked in the feature branch.

### 3. Merge & Cleanup

Create a PR to `main`, merge it, and the feature workspace is automatically destroyed:

- PR merge → Cleanup workflow triggers → Workspace deleted → Capacity freed

## Required Secrets

Configure these in **Settings → Secrets and variables → Actions**:

| Secret | Purpose |
|:---|:---|
| `AZURE_TENANT_ID` | Entra ID tenant |
| `AZURE_CLIENT_ID` | Service Principal app ID |
| `AZURE_CLIENT_SECRET` | Service Principal secret |
| `FABRIC_GITHUB_TOKEN` | PAT for Fabric Git integration |
| `FABRIC_CAPACITY_ID` | Fabric capacity for workspaces |

## Architecture

```
Developer pushes feature/X
  → GitHub Actions triggers feature-workspace-create.yml
    → Installs usf-fabric-cli from BralaBee-LEIT/usf_fabric_cli_cicd
      → CLI calls Fabric API to provision workspace
        → Workspace is created and connected to the feature branch

Developer merges PR to main
  → GitHub Actions triggers feature-workspace-cleanup.yml
    → CLI calls Fabric API to destroy the feature workspace
```

# Trigger CI/CD with fixed CLI

