# Replication Guide — Microsoft Fabric CI/CD from Scratch

> **Version**: 2.0.0 · **Last Updated**: 15 February 2026
>
> Complete end-to-end guide to set up a fully automated Microsoft Fabric CI/CD
> lifecycle using the `usf_fabric_cli_cicd` CLI and this consumer repository as a
> template. Covers prerequisite setup, configuration, deployment, testing,
> multi-project support, and customisation.

---

## Table of Contents

1. [Overview](#1-overview)
2. [Prerequisites](#2-prerequisites)
   - 2.1 [Azure Entra ID (Service Principal)](#21-azure-entra-id-service-principal)
   - 2.2 [Microsoft Fabric Capacity](#22-microsoft-fabric-capacity)
   - 2.3 [GitHub Account & PAT](#23-github-account--pat)
3. [Repository Setup](#3-repository-setup)
   - 3.1 [Fork or Copy the Repos](#31-fork-or-copy-the-repos)
   - 3.2 [Understand the Two-Repo Model](#32-understand-the-two-repo-model)
4. [Choose Your Workflow Strategy](#4-choose-your-workflow-strategy)
   - 4.1 [Option A — Single-Project per Repo (Default)](#41-option-a--single-project-per-repo-default)
   - 4.2 [Option B — Multi-Project in One Repo](#42-option-b--multi-project-in-one-repo)
   - 4.3 [Side-by-Side Comparison](#43-side-by-side-comparison)
   - 4.4 [How to Switch Between Options](#44-how-to-switch-between-options)
5. [Configure Secrets & Variables](#5-configure-secrets--variables)
   - 5.1 [GitHub Secrets (Required)](#51-github-secrets-required)
   - 5.2 [GitHub Repository Variables (Optional)](#52-github-repository-variables-optional)
   - 5.3 [Additional Variables for Multi-Project (Option B)](#53-additional-variables-for-multi-project-option-b)
6. [Customise the Configuration](#6-customise-the-configuration)
   - 6.1 [Choose Your Project Prefix](#61-choose-your-project-prefix)
   - 6.2 [Edit Config Files](#62-edit-config-files)
   - 6.3 [Add a New Project (Option B Only)](#63-add-a-new-project-option-b-only)
7. [Phase 1 — Initial Deployment](#7-phase-1--initial-deployment)
   - 7.1 [Single-Project Setup (Option A)](#71-single-project-setup-option-a)
   - 7.2 [Multi-Project Setup (Option B)](#72-multi-project-setup-option-b)
8. [Phase 2 — Feature Branch Lifecycle](#8-phase-2--feature-branch-lifecycle)
   - 8.1 [Feature Branches in Single-Project (Option A)](#81-feature-branches-in-single-project-option-a)
   - 8.2 [Feature Branches in Multi-Project (Option B)](#82-feature-branches-in-multi-project-option-b)
9. [Phase 3 — Promotion (Dev → Test → Prod)](#9-phase-3--promotion-dev--test--prod)
   - 9.1 [Promotion in Single-Project (Option A)](#91-promotion-in-single-project-option-a)
   - 9.2 [Promotion in Multi-Project (Option B)](#92-promotion-in-multi-project-option-b)
10. [Verification Checklist](#10-verification-checklist)
11. [Common Bottlenecks & Troubleshooting](#11-common-bottlenecks--troubleshooting)
12. [Keeping the CLI Updated](#12-keeping-the-cli-updated)
13. [Customising for Your Own Project](#13-customising-for-your-own-project)
14. [Architecture Reference](#14-architecture-reference)

---

## 1. Overview

This guide walks you through replicating the complete Microsoft Fabric CI/CD lifecycle for your own organisation. By the end, you will have:

- **3 Fabric workspaces per project** (Dev, Test, Prod) connected via a Deployment Pipeline
- **Automated feature workspace isolation** — push a `feature/*` branch, get a workspace; merge the PR, workspace is destroyed
- **Automated promotion** — code merged to `main` auto-promotes Dev → Test; manual trigger promotes Test → Prod
- **Git-synced development** — the Dev workspace tracks the `main` branch automatically
- **Choice of single-project or multi-project strategy** — decide at project initiation

**Time estimate**: 45–90 minutes (first time), depending on Azure/Fabric familiarity.

### How It Works

```
┌─────────────────────────────────────────────────────────────────────┐
│                     YOUR CONSUMER REPO (GitHub)                     │
│                                                                     │
│  config/projects/                                                   │
│    ├── demo/                     ← Project 1 (included as default) │
│    │   ├── base_workspace.yaml   ← Dev + Pipeline + Test + Prod    │
│    │   └── feature_workspace_demo.yaml  ← Feature template         │
│    └── sales_analytics/          ← Project 2 (example, Option B)   │
│        ├── base_workspace.yaml                                      │
│        └── feature_workspace.yaml                                   │
│                                                                     │
│  .github/workflows/              ← Active (single-project default) │
│  .github/multi-project-workflows/ ← Alternative (multi-project)    │
├─────────────────────────────────────────────────────────────────────┤
│                           ↓ installs at runtime ↓                   │
│                  CLI REPO (usf_fabric_cli_cicd)                     │
│         Provides: fabric-cicd deploy / destroy / promote            │
└─────────────────────────────────────────────────────────────────────┘
                           ↓ talks to ↓
┌─────────────────────────────────────────────────────────────────────┐
│                    MICROSOFT FABRIC (Cloud)                         │
│                                                                     │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐                      │
│  │  Dev WS   │───▶│  Test WS  │───▶│  Prod WS  │  (per project)   │
│  │ (Git sync)│    │           │    │           │                    │
│  └──────────┘    └──────────┘    └──────────┘                      │
│        ▲          Deployment Pipeline                               │
│        │                                                            │
│  ┌──────────┐                                                       │
│  │Feature WS │  ← temporary, per-branch                            │
│  └──────────┘                                                       │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 2. Prerequisites

### 2.1 Azure Entra ID (Service Principal)

> **⚠️ Bottleneck alert**: This is the #1 setup blocker. Most issues stem from
> insufficient Service Principal permissions.

You need a Service Principal (SP) with credentials for automated deployments.

**Create the SP:**

```bash
# Install Azure CLI if needed: https://learn.microsoft.com/en-us/cli/azure/install-azure-cli
az login

# Create the Service Principal
az ad sp create-for-rbac \
  --name "fabric-cicd-sp" \
  --role Contributor \
  --scopes /subscriptions/<YOUR_SUBSCRIPTION_ID>
```

This outputs:
```json
{
  "appId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",     ← AZURE_CLIENT_ID
  "password": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", ← AZURE_CLIENT_SECRET
  "tenant": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"      ← AZURE_TENANT_ID
}
```

**Save these values** — you will need them in Step 5.

**Grant Fabric permissions to the SP:**

1. Go to **Microsoft Fabric Admin Portal** → **Tenant settings**
2. Under **Developer settings**, enable:
   - ✅ *Service principals can use Fabric APIs*
   - ✅ *Service principals can create and use profiles*
3. Add your SP (by App ID or Security Group) to the allowed list
4. Under **Workspace settings** → enable *Service principals can access workspaces*

> **💡 Tip**: If your Fabric admin has locked down API access to a specific Security
> Group, add your SP's App ID to that group in Entra ID.

**Get the SP's Object ID** (needed for `DEV_ADMIN_OBJECT_ID`):

```bash
az ad sp show --id <YOUR_APP_ID> --query id -o tsv
```

### 2.2 Microsoft Fabric Capacity

You need an active Fabric capacity (F2 or higher) to create workspaces.

**Check your capacity:**

1. Go to **Fabric Admin Portal** → **Capacity settings**
2. Note the **Capacity ID** (a GUID) — this becomes `FABRIC_CAPACITY_ID`
3. Ensure your SP has **Capacity Contributor** role on the capacity:
   - Admin Portal → Capacity → Permissions → Add your SP

> **⚠️ F2 (trial) limits**: F2 capacities have low workspace and compute limits.
> If you hit "capacity exhausted" errors, clean up unused workspaces or upgrade.

**If you don't have a capacity:**

- **Trial**: [Start a Fabric trial](https://learn.microsoft.com/en-us/fabric/get-started/fabric-trial) (F2, 60 days free)
- **Pay-as-you-go**: Create an F2 capacity in Azure Portal → Microsoft Fabric

### 2.3 GitHub Account & PAT

**Create a Personal Access Token (PAT):**

1. Go to **GitHub → Settings → Developer settings → Personal access tokens → Fine-grained tokens**
2. Create a token with these permissions:
   - ✅ **Contents**: Read and write (to clone the CLI repo)
   - ✅ **Metadata**: Read-only
3. Set the scope to the organisation/repos that host your CLI repo

> **💡 Why a PAT?** Fabric's Git integration uses this token to connect workspaces
> to your GitHub repository. The workflows also use it to clone the CLI package.

**Save the PAT** — this becomes `FABRIC_GITHUB_TOKEN` in Step 5.

---

## 3. Repository Setup

### 3.1 Fork or Copy the Repos

You need **two repositories**:

| Repo | Purpose | What to do |
|------|---------|------------|
| **CLI repo** (product) | Contains the `fabric-cicd` CLI tool | Fork `usf_fabric_cli_cicd` into your GitHub org, or use as-is if you have read access |
| **Consumer repo** (this one) | Contains config + workflows | Fork `fabric_cicd_test_repo` into your GitHub org, then customise |

**Fork the consumer repo:**

```bash
# Option A: Fork via GitHub UI (recommended)
# Go to the repo → Fork → Choose your org

# Option B: Create a fresh copy
mkdir my-fabric-cicd && cd my-fabric-cicd
git init
# Copy the contents of fabric_cicd_test_repo into this directory
git add -A && git commit -m "chore: initial setup from template"
git remote add origin https://github.com/<YOUR_ORG>/<YOUR_REPO>.git
git push -u origin main
```

### 3.2 Understand the Two-Repo Model

```
┌──────────────────────────────────┐    ┌──────────────────────────────┐
│  CLI REPO (product)              │    │  CONSUMER REPO (yours)       │
│                                  │    │                              │
│  • fabric-cicd CLI binary        │◄───│  • Workflows install CLI     │
│  • deploy / destroy / promote    │    │    at runtime via pip        │
│  • Shared across all projects    │    │  • Config YAML per project   │
│                                  │    │  • GitHub Actions workflows  │
└──────────────────────────────────┘    └──────────────────────────────┘
```

**Why two repos?**
- The CLI is a shared tool — many consumer repos can use the same CLI version
- Your configs and workflows are project-specific
- Separating concerns makes upgrades clean (update CLI version, consumer stays stable)

---

## 4. Choose Your Workflow Strategy

Before configuring secrets and variables, decide how you will organise your Fabric
projects. This repo ships with **two complete workflow sets** — choose one at
project initiation time:

### 4.1 Option A — Single-Project per Repo (Default)

**One consumer repo = one Fabric project.** This is how the repo ships out of the box.

```
fabric_cicd_consumer_repo/
├── .github/workflows/              ← Active workflows (single-project)
├── config/projects/demo/
│   ├── base_workspace.yaml
│   └── feature_workspace_demo.yaml
```

**When to use Option A:**
- Different teams own different Fabric projects
- Different Service Principals needed per project (security isolation)
- Different promotion cadences (Project A auto-promotes, Project B is manual)
- You want the simplest possible workflow logic
- Enterprise/regulated environments where blast radius must be minimised

**How Option A works:**

| Action | How |
|:---|:---|
| Setup workspace | Actions → "Setup Base Workspaces" → Run |
| Feature branch | `git checkout -b feature/my-feature` |
| Feature cleanup | Automatic on PR merge |
| Dev → Test | Automatic on push to `main` |
| Test → Prod | Manual dispatch, type "PROMOTE" |

**Branch convention:** `feature/<feature-name>`
Examples: `feature/add-gold-table`, `feature/fix-pipeline`

### 4.2 Option B — Multi-Project in One Repo

**One consumer repo = multiple Fabric projects.** The alternative workflows in
`.github/multi-project-workflows/` handle project selection automatically.

```
fabric_cicd_consumer_repo/
├── .github/
│   ├── workflows/                    ← Replace with multi-project versions
│   └── multi-project-workflows/      ← Source of truth for Option B
├── config/projects/
│   ├── demo/                         ← Project 1
│   │   ├── base_workspace.yaml
│   │   └── feature_workspace_demo.yaml
│   └── sales_analytics/             ← Project 2
│       ├── base_workspace.yaml
│       └── feature_workspace.yaml
```

**When to use Option B:**
- Small team managing multiple related Fabric projects
- Same Service Principal handles all projects
- Same promotion rules apply to all projects
- You want fewer repos to manage
- Projects share the same capacity and admin group

**How Option B works:**

| Action | How |
|:---|:---|
| Setup workspace | Actions → "Setup Base Workspaces" → **select project** → Run |
| Feature branch | `git checkout -b feature/<project>/<feature-name>` |
| Feature cleanup | Automatic on PR merge (project extracted from branch name) |
| Dev → Test | **All projects** promoted in parallel on push to `main` |
| Test → Prod | Manual dispatch → **select project** → type "PROMOTE" |

**Branch convention:** `feature/<project>/<feature-name>`
Examples: `feature/demo/add-gold-table`, `feature/sales_analytics/fix-pipeline`

> **Fallback**: If you push `feature/something` (no project segment), it defaults
> to the `DEFAULT_PROJECT` repo variable (or `demo` if not set).

**Multi-project key design decisions:**
- **Dev → Test promotion** uses a **matrix strategy**: a `discover-projects` job scans
  all `config/projects/*/base_workspace.yaml` files that have a `deployment_pipeline`
  section, then a parallel matrix job promotes each project independently with
  `fail-fast: false` (one project's failure doesn't block others)
- **Feature workspace creation** extracts the project name from the branch name to locate
  the correct config under `config/projects/<project>/`
- **Setup and Test → Prod** workflows use a `type: choice` dropdown listing known projects

### 4.3 Side-by-Side Comparison

| Aspect | Option A (Single) | Option B (Multi) |
|:---|:---|:---|
| **Repos to manage** | One per project | One for all |
| **Secrets isolation** | Full (per-repo secrets) | Shared (all projects use same SP) |
| **Branch naming** | `feature/<name>` | `feature/<project>/<name>` |
| **Setup workflow** | Deploys the one project | Select project from dropdown |
| **Promotion** | One project promoted | All projects promoted in parallel (matrix) |
| **Adding a project** | Fork/copy the entire repo | Add a config folder + update choice lists |
| **CODEOWNERS** | Per-repo | Shared (can use path-based rules) |
| **Complexity** | Simple | Moderate |
| **Blast radius** | One project | All projects in the repo |

### 4.4 How to Switch Between Options

**Switching from Option A → Option B:**

```bash
# 1. Back up current workflows (optional)
mkdir -p .github/single-project-workflows
cp .github/workflows/*.yml .github/single-project-workflows/

# 2. Replace active workflows with multi-project versions
cp .github/multi-project-workflows/*.yml .github/workflows/

# 3. Add new project configs (copy + customise)
cp -r config/projects/demo config/projects/my_new_project
# Edit config/projects/my_new_project/base_workspace.yaml

# 4. Update the project choice lists in workflows that use `type: choice`
#    Search for "# ➕ Add new projects here" in the workflow files:
#    - setup-base-workspaces.yml  (inputs.project.options)
#    - promote-test-to-prod.yml   (inputs.project.options)

# 5. Commit and push
git add -A && git commit -m "feat: switch to multi-project workflows"
git push
```

**Switching from Option B → Option A:**

```bash
# Restore single-project workflows
cp .github/single-project-workflows/*.yml .github/workflows/
git add -A && git commit -m "revert: switch back to single-project workflows"
```

---

## 5. Configure Secrets & Variables

Go to your **consumer repo** on GitHub → **Settings** → **Secrets and variables** → **Actions**.

### 5.1 GitHub Secrets (Required)

These are sensitive values that must never appear in code or logs.

| Secret Name | Value | Where to get it |
|-------------|-------|------------------|
| `AZURE_TENANT_ID` | Your Entra ID tenant GUID | Step 2.1 (`az ad sp create-for-rbac` output) |
| `AZURE_CLIENT_ID` | Service Principal application ID | Step 2.1 |
| `AZURE_CLIENT_SECRET` | Service Principal password | Step 2.1 |
| `FABRIC_GITHUB_TOKEN` | GitHub PAT with repo access | Step 2.3 |
| `FABRIC_CAPACITY_ID` | Fabric capacity GUID | Step 2.2 |
| `DEV_ADMIN_OBJECT_ID` | SP's Object ID (for workspace admin) | Step 2.1 (`az ad sp show`) |

**How to add secrets:**

1. Go to repo **Settings → Secrets and variables → Actions**
2. Click **New repository secret**
3. Enter the name (e.g., `AZURE_TENANT_ID`) and the value
4. Repeat for all 6 secrets

### 5.2 GitHub Repository Variables (Optional)

These customise the deployment without touching code. All have sensible defaults.

Go to **Settings → Secrets and variables → Actions → Variables tab**.

| Variable | Default | Description |
|----------|---------|-------------|
| `PROJECT_PREFIX` | `fabric-cicd-demo` | Prefix for all workspace names (e.g., `myproject` → workspaces named `myproject-dev`, `myproject-test`, `myproject-prod`) |
| `CLI_REPO_URL` | `github.com/your-org/your-cli-repo` | URL to your CLI repo (without `https://`) |
| `CLI_REPO_REF` | `v1.7.6` | Tag (or branch) of the CLI repo to install |
| `FABRIC_CLI_VERSION` | `1.3.1` | Version of the Microsoft `ms-fabric-cli` package |
| `FEATURE_WORKSPACE_CONFIG` | *(auto-detected)* | Path to feature workspace config, e.g., `config/projects/demo/feature_workspace_demo.yaml` |

> **💡 Quick start**: If you only change one thing, set `PROJECT_PREFIX` to something
> meaningful for your project (e.g., `sales-analytics`, `hr-reporting`). This names
> all your workspaces accordingly.

**How to add variables:**

1. Go to repo **Settings → Secrets and variables → Actions → Variables tab**
2. Click **New repository variable**
3. Enter the name (e.g., `PROJECT_PREFIX`) and value (e.g., `my-project`)

### 5.3 Additional Variables for Multi-Project (Option B)

If you chose Option B (multi-project), these additional repo variables are available:

| Variable | Default | Purpose |
|:---|:---|:---|
| `DEFAULT_PROJECT` | `demo` | Fallback project when a feature branch name doesn't include a project segment (e.g., `feature/something` instead of `feature/demo/something`) |
| `FEATURE_WORKSPACE_CONFIG` | *(auto-discovered)* | Override: force all feature workspaces to use a specific config file path instead of per-project discovery |

---

## 6. Customise the Configuration

### 6.1 Choose Your Project Prefix

The `PROJECT_PREFIX` variable determines workspace naming:

| PROJECT_PREFIX | Dev Workspace | Test Workspace | Prod Workspace | Pipeline Name |
|----------------|---------------|----------------|----------------|---------------|
| `fabric-cicd-demo` | `fabric-cicd-demo-dev` | `fabric-cicd-demo-test` | `fabric-cicd-demo-prod` | `fabric-cicd-demo-pipeline` |
| `sales-analytics` | `sales-analytics-dev` | `sales-analytics-test` | `sales-analytics-prod` | `sales-analytics-pipeline` |
| `hr-reporting` | `hr-reporting-dev` | `hr-reporting-test` | `hr-reporting-prod` | `hr-reporting-pipeline` |

You can set this as a **repo variable** (Step 5.2) or accept the default.

### 6.2 Edit Config Files

The configs in `config/projects/demo/` work out of the box. If you need to customise:

**`base_workspace.yaml`** — the main Dev workspace + pipeline:

```yaml
# All names use ${PROJECT_PREFIX} — set via repo variable, not here
workspace:
  name: ${PROJECT_PREFIX}-dev
  display_name: ${PROJECT_PREFIX} - Development
  capacity_id: ${FABRIC_CAPACITY_ID}
  git_repo: ${GIT_REPO_URL}
  git_branch: main

# Add more resources as needed:
lakehouses:
  - name: lh_bronze
    folder: Bronze
  - name: lh_silver        # ← Add your own
    folder: Silver

notebooks:
  - name: demo_notebook
    folder: Bronze
  - name: transform_data   # ← Add your own
    folder: Silver

# Deployment Pipeline — connects Dev → Test → Prod
deployment_pipeline:
  pipeline_name: "${PROJECT_PREFIX}-pipeline"
  stages:
    development:
      workspace_name: ${PROJECT_PREFIX}-dev
      capacity_id: ${FABRIC_CAPACITY_ID}
    test:
      workspace_name: ${PROJECT_PREFIX}-test
      capacity_id: ${FABRIC_CAPACITY_ID}
    production:
      workspace_name: ${PROJECT_PREFIX}-prod
      capacity_id: ${FABRIC_CAPACITY_ID}
```

**`feature_workspace_demo.yaml`** — the feature branch workspace template:

```yaml
workspace:
  name: ${PROJECT_PREFIX}
  capacity_id: ${FABRIC_CAPACITY_ID}
  git_repo: ${GIT_REPO_URL}
  git_branch: main

# Feature workspaces inherit the same structure
# The CLI appends the branch name to the workspace name automatically
```

### 6.3 Add a New Project (Option B Only)

If you are using multi-project workflows (Option B), add a new Fabric project as follows:

**1. Create a config folder:**

```bash
mkdir -p config/projects/my_project
```

**2. Copy and customise YAML configs:**

```bash
cp config/projects/demo/base_workspace.yaml config/projects/my_project/
cp config/projects/demo/feature_workspace_demo.yaml config/projects/my_project/feature_workspace.yaml
```

Edit both files — change workspace names, resources, lakehouses, notebooks, etc.
For example, see the included `config/projects/sales_analytics/` for a second-project template.

**3. Update workflow choice lists** (only for manual-dispatch workflows):

Edit these files and add your new project name to the `options` list:
- `.github/workflows/setup-base-workspaces.yml` → `inputs.project.options`
- `.github/workflows/promote-test-to-prod.yml` → `inputs.project.options`

Look for the `# ➕ Add new projects here` comment in each file.

> **Note**: The `promote-dev-to-test.yml` auto-discovers projects — no change needed
> there. It scans `config/projects/*/base_workspace.yaml` at runtime.

**4. Run initial setup for the new project:**

```
Actions → "Setup Base Workspaces" → project: my_project → Run
```

**5. Start developing:**

```bash
git checkout -b feature/my_project/first-feature
```

---

## 7. Phase 1 — Initial Deployment

This creates your base workspaces and the deployment pipeline. **Run once per project.**

### 7.1 Single-Project Setup (Option A)

**Step 1: Trigger the Setup Workflow**

1. Go to your consumer repo on GitHub
2. Click **Actions** → **Setup Base Workspaces** (left sidebar)
3. Click **Run workflow** → select `dev` → **Run workflow**

**Step 2: Monitor the Run**

- Watch the workflow logs in the Actions tab
- **Expected duration**: 2–5 minutes
- The workflow will:
  1. Install the CLI from your CLI repo
  2. Deploy the Dev workspace with Git sync to `main`
  3. Create the Deployment Pipeline
  4. Create Test and Prod workspaces and assign them to pipeline stages

**Step 3: Verify in Fabric Portal**

1. Go to [app.fabric.microsoft.com](https://app.fabric.microsoft.com)
2. You should see three new workspaces:
   - `<prefix>-dev` (connected to your GitHub `main` branch)
   - `<prefix>-test`
   - `<prefix>-prod`
3. Go to **Deployment Pipelines** → you should see `<prefix>-pipeline` with all three stages assigned

> **⚠️ If the workflow fails**: Jump to [Section 11 — Troubleshooting](#11-common-bottlenecks--troubleshooting).

### 7.2 Multi-Project Setup (Option B)

**Step 1: Trigger Setup for Each Project**

1. Go to **Actions** → **Setup Base Workspaces**
2. Click **Run workflow** → **select the project** from the dropdown (e.g., `demo`) → **Run**
3. Wait for it to complete, then repeat for the next project (e.g., `sales_analytics`)

Each run creates that project's Dev/Test/Prod workspaces and Deployment Pipeline.

**Step 2: Verify in Fabric Portal**

You should see workspaces for each project:

| Project | Dev | Test | Prod | Pipeline |
|:---|:---|:---|:---|:---|
| `demo` | `<prefix>-dev` | `<prefix>-test` | `<prefix>-prod` | `<prefix>-pipeline` |
| `sales_analytics` | `<prefix>-sales-dev` | `<prefix>-sales-test` | `<prefix>-sales-prod` | `<prefix>-sales-pipeline` |

---

## 8. Phase 2 — Feature Branch Lifecycle

### 8.1 Feature Branches in Single-Project (Option A)

**Step 1: Create a Feature Branch**

```bash
git checkout -b feature/test-isolation
echo "# Test" >> test.md
git add test.md
git commit -m "feat: test feature workspace isolation"
git push origin feature/test-isolation
```

**Step 2: Watch Workspace Creation**

1. Go to **Actions** → you'll see **Create Feature Workspace** running
2. **Expected duration**: 2–4 minutes
3. After completion, check Fabric portal — you'll see a new workspace:
   `<prefix>-feature-test-isolation`

**Step 3: Work in the Feature Workspace**

- Open the feature workspace in Fabric portal
- It is Git-connected to your `feature/test-isolation` branch
- Make changes in Fabric → they sync back to the branch
- Make changes in Git → they sync to the feature workspace

**Step 4: Merge and Clean Up**

```bash
# Create a PR on GitHub
gh pr create --title "feat: test isolation" --base main
# Merge the PR
gh pr merge --squash --delete-branch
```

After merge:
1. **Cleanup workflow** runs automatically → destroys the feature workspace
2. **Promote Dev → Test** workflow runs automatically (because `main` was updated)

**Step 5: Verify**

- Feature workspace is gone from Fabric portal
- Dev workspace has the changes (Git-synced from `main`)
- Test workspace has the promoted content

### 8.2 Feature Branches in Multi-Project (Option B)

The workflow is the same, but your branch name includes the project:

**Step 1: Create a Feature Branch**

```bash
# Note the project name in the branch path
git checkout -b feature/demo/test-isolation
echo "# Test" >> test.md
git add test.md
git commit -m "feat: test feature workspace isolation for demo project"
git push origin feature/demo/test-isolation
```

The workflow parses `feature/demo/test-isolation`:
- **Project**: `demo` → looks up `config/projects/demo/feature_workspace*.yaml`
- **Feature**: `test-isolation` → used for workspace naming

**Step 2: For a Different Project**

```bash
git checkout -b feature/sales_analytics/new-report
echo "# Sales Report" >> sales.md
git add sales.md
git commit -m "feat: new sales report for sales_analytics"
git push origin feature/sales_analytics/new-report
```

The workflow finds `config/projects/sales_analytics/feature_workspace.yaml`.

**Fallback behaviour**: If you push `feature/something` (no project segment), the
workflow uses the `DEFAULT_PROJECT` repo variable (default: `demo`).

**Steps 3–5** are the same as Option A — work in Fabric, merge the PR, workspace
is cleaned up automatically, and promotion triggers.

---

## 9. Phase 3 — Promotion (Dev → Test → Prod)

### 9.1 Promotion in Single-Project (Option A)

**Dev → Test (Automatic)**

This happens automatically whenever code is pushed to `main`:
1. Fabric Git Sync updates the Dev workspace (30–120 seconds)
2. The promote workflow waits 60 seconds for sync to complete
3. CLI calls `fabric-cicd promote` to push Dev content → Test

**Test → Prod (Manual)**

1. Go to **Actions** → **Promote Test → Production**
2. Click **Run workflow**
3. Type `PROMOTE` (exact, case-sensitive) in the confirmation field
4. Optionally add a deployment note
5. Click **Run workflow**

### 9.2 Promotion in Multi-Project (Option B)

**Dev → Test (Automatic, All Projects in Parallel)**

When code is pushed to `main`, the multi-project promote workflow:
1. Runs a **discovery job** that scans all `config/projects/*/base_workspace.yaml`
   files to find projects with a `deployment_pipeline.pipeline_name`
2. Creates a **matrix** of all discovered projects
3. Promotes each project's Dev → Test **in parallel** using `fail-fast: false`
4. If one project fails, the others continue independently

You can also trigger a single-project promotion manually:
- Actions → **Promote Dev → Test** → Run workflow → enter the project name

**Test → Prod (Manual, Per-Project)**

1. Go to **Actions** → **Promote Test → Production**
2. Click **Run workflow**
3. **Select the project** from the dropdown (e.g., `demo` or `sales_analytics`)
4. Type `PROMOTE` (exact, case-sensitive)
5. Optionally add a deployment note
6. Click **Run workflow**

---

## 10. Verification Checklist

After completing all three phases, verify:

**For each project (repeat per project if using Option B):**

| Check | Expected Result | How to Verify |
|-------|-----------------|---------------|
| ✅ Dev workspace exists | `<prefix>-dev` in Fabric portal | Fabric Portal → Workspaces |
| ✅ Test workspace exists | `<prefix>-test` in Fabric portal | Fabric Portal → Workspaces |
| ✅ Prod workspace exists | `<prefix>-prod` in Fabric portal | Fabric Portal → Workspaces |
| ✅ Deployment Pipeline exists | `<prefix>-pipeline` with 3 stages | Fabric Portal → Deployment Pipelines |
| ✅ Dev is Git-synced | Connected to `main` branch | Dev workspace → Source control |
| ✅ Feature workspace created | Workspace appeared on branch push | Actions → Create Feature Workspace |
| ✅ Feature workspace destroyed | Workspace gone after PR merge | Actions → Cleanup Feature Workspace |
| ✅ Dev → Test promoted | Test has Dev content | Fabric Portal → Deployment Pipelines |
| ✅ Test → Prod promoted | Prod has Test content | Fabric Portal → Deployment Pipelines |

**Option B additional checks:**

| Check | Expected Result | How to Verify |
|-------|-----------------|---------------|
| ✅ Multi-project branches work | `feature/<project>/<feature>` triggers correct config | Actions → Create Feature Workspace logs |
| ✅ Matrix promotion works | All projects promoted in parallel | Actions → Promote Dev → Test (multiple jobs) |
| ✅ Project discovery works | CI lists all projects with ✅/❌ | Actions → CI → "List discovered projects" step |

---

## 11. Common Bottlenecks & Troubleshooting

### ❌ "InsufficientPrivileges" or "Access is forbidden"

**Cause**: The Service Principal lacks permissions.

**Fix:**
1. Ensure SP has **Admin** role on the Fabric workspace (or the SP created the workspace)
2. In Fabric Admin Portal → Tenant settings:
   - Enable *Service principals can use Fabric APIs*
   - Add your SP to the security group if one is configured
3. Ensure SP has **Capacity Contributor** on the Fabric capacity

### ❌ "Capacity ID not found" or workspace creation fails

**Cause**: Invalid or inaccessible capacity.

**Fix:**
1. Verify `FABRIC_CAPACITY_ID` secret is correct (it's a GUID)
2. Confirm capacity is in **Active** state (not paused/deallocated)
3. Ensure SP has permissions on the capacity

### ❌ "Repository not found" during Git sync

**Cause**: The PAT lacks access to the consumer repo, or the URL is wrong.

**Fix:**
1. Verify `FABRIC_GITHUB_TOKEN` has **Contents: Read and write** permissions
2. Ensure the token is scoped to the correct organisation/repository
3. Check that `GIT_REPO_URL` is auto-populated correctly (this is set automatically by the workflow from `github.server_url` + `github.repository`)

### ❌ "pip install" fails for the CLI

**Cause**: Can't install the CLI package from your CLI repo.

**Fix:**
1. Verify `CLI_REPO_URL` variable points to the correct repo (without `https://`, e.g., `github.com/your-org/your-cli-repo`)
2. Ensure `FABRIC_GITHUB_TOKEN` has read access to the CLI repo
3. Check `CLI_REPO_REF` (branch) exists on the CLI repo

### ❌ Promote workflow resolves pipeline name as empty

**Cause**: `${PROJECT_PREFIX}` in the YAML config wasn't resolved to the environment variable.

**Fix:**
1. Ensure `PROJECT_PREFIX` is set as a GitHub Actions **environment variable** in the workflow (it should be — the workflows set it via `vars.PROJECT_PREFIX`)
2. The promote workflow uses Python's `re.sub` to resolve `${VAR}` patterns at runtime — this requires the env vars to be set in the workflow step

### ❌ Feature workspace not created (no workflow triggered)

**Cause**: Branch naming doesn't match the trigger.

**Fix:**
1. Branch must start with `feature/` (e.g., `feature/my-thing`)
2. Check the push went to the correct remote (`origin`)
3. Ensure GitHub Actions is enabled on the repo

### ❌ Cleanup doesn't run after PR merge

**Cause**: The PR must be **merged** (not just closed), and the source branch must start with `feature/`.

**Fix:**
1. Merge the PR (the green "Merge" button), don't just close it
2. If the branch was already deleted, use the manual workflow dispatch:
   - Actions → Cleanup Feature Workspace → Run workflow → enter the branch name (e.g., `feature/my-thing`)

### ⏳ Promotion fails intermittently

**Cause**: Fabric Git Sync hasn't completed before the promote step runs.

**Fix:**
The promote-dev-to-test workflow includes a 60-second wait by default. If your workspace is large, you may need more time. Edit the wait step in the workflow to increase the duration.

### ❌ Multi-project: Feature branch creates workspace for wrong project (Option B)

**Cause**: Branch name doesn't include a project segment, or `DEFAULT_PROJECT` is set to the wrong value.

**Fix:**
1. Use the full branch convention: `feature/<project>/<feature-name>` (e.g., `feature/sales_analytics/my-feature`)
2. Check your `DEFAULT_PROJECT` repo variable (Settings → Variables) — this is the fallback when no project segment is found
3. Verify the project folder exists: `config/projects/<project>/feature_workspace.yaml`

### ❌ Multi-project: Matrix promotion only promotes some projects (Option B)

**Cause**: The auto-discovery job only finds projects that have a `deployment_pipeline.pipeline_name` in their `base_workspace.yaml`.

**Fix:**
1. Ensure each project's `config/projects/<project>/base_workspace.yaml` has a `deployment_pipeline:` section with a `pipeline_name`
2. Run the CI workflow — the "List discovered projects" step shows what was found with ✅/❌ markers
3. If using manual trigger, verify the project name matches the folder name exactly

### ❌ Multi-project: "Config not found" in setup workflow (Option B)

**Cause**: The project selected in the dropdown doesn't have a matching config folder.

**Fix:**
1. Ensure `config/projects/<project>/base_workspace.yaml` exists
2. If you've added a new project, remember to also update the `type: choice` options in:
   - `setup-base-workspaces.yml`
   - `promote-test-to-prod.yml`

### 💡 General Debugging Steps

1. **Read the workflow logs**: Actions tab → click the failed run → expand the failed step
2. **Check secrets**: Settings → Secrets → verify all 6 are set and not expired
3. **Check variables**: Settings → Variables → verify `PROJECT_PREFIX` etc. if you set them
4. **Test locally**: Install the CLI locally and run deploy manually to isolate issues:
   ```bash
   # Install CLI
   pip install ms-fabric-cli==1.3.1
   pip install "git+https://<your-pat>@<your-cli-repo>.git@v1.7.6"

   # Set env vars
   export AZURE_TENANT_ID=...
   export AZURE_CLIENT_ID=...
   export AZURE_CLIENT_SECRET=...
   export FABRIC_CAPACITY_ID=...
   export PROJECT_PREFIX=my-test

   # Deploy
   fabric-cicd deploy config/projects/demo/base_workspace.yaml --env dev
   ```

---

## 12. Keeping the CLI Updated

The consumer repo installs the CLI from source via `git+https://` pinned to a **version tag**
(e.g. `v1.7.6`). This means the CLI version only changes when you explicitly update it.

### When to Update

After any meaningful change to the CLI repo (new feature, bug fix, config change),
you need to **tag the new version** in the CLI repo and **update the consumer workflows**.

### Step-by-Step Update Routine

```bash
# ── In the CLI repo ──

# 1. Make your code changes, commit, push
git add -A && git commit -m "feat: your improvement"
git push origin main

# 2. Update the version in pyproject.toml
#    e.g. version = "1.7.6" → version = "1.8.0"

# 3. Tag the release
git tag -a v1.8.0 -m "Release v1.8.0 — description of changes"
git push origin v1.8.0
```

```bash
# ── In the consumer repo ──

# Option A: Update the default in all workflows (recommended for permanent upgrades)
sed -i "s/vars.CLI_REPO_REF || 'v1.7.6'/vars.CLI_REPO_REF || 'v1.8.0'/g" \
  .github/workflows/*.yml
git add -A && git commit -m "chore: bump CLI to v1.8.0"
git push origin main

# Option B: Set a repo variable (no code change required)
#   Settings → Variables → CLI_REPO_REF = v1.8.0
```

### What Happens If You Forget

- **Nothing breaks** — workflows keep using the pinned tag (e.g. `v1.7.6`)
- You just won't get the latest CLI features or fixes until you update
- This is intentional: consumer repos are stable until you choose to upgrade

### Quick Checklist

| Step | Where | Command / Action |
|------|-------|------------------|
| 1. Code & push | CLI repo | `git commit` + `git push` |
| 2. Bump version | CLI repo | Edit `pyproject.toml` |
| 3. Tag release | CLI repo | `git tag -a vX.Y.Z` + `git push origin vX.Y.Z` |
| 4. Update consumer | Consumer repo | `sed` the default OR set `CLI_REPO_REF` variable |
| 5. Verify | Consumer repo | Run any workflow — check install step in logs |

---

## 13. Customising for Your Own Project

Once you've validated the lifecycle with the demo configs, customise for your real project.

### 13.1 Change Workspace Names

Set the `PROJECT_PREFIX` repo variable (Settings → Variables):

```
PROJECT_PREFIX = sales-analytics
```

This automatically renames all workspaces, the pipeline, and feature workspaces
via the `${PROJECT_PREFIX}` placeholder used throughout the YAML configs.

### 13.2 Add Resources

Edit your project's `base_workspace.yaml`:

```yaml
lakehouses:
  - name: lh_bronze
    folder: Bronze
  - name: lh_silver
    folder: Silver
  - name: lh_gold
    folder: Gold

notebooks:
  - name: ingest_data
    folder: Bronze
  - name: transform_data
    folder: Silver
  - name: aggregate_reports
    folder: Gold

# Add generic Fabric resources (Eventstream, KQL Database, etc.)
resources:
  - type: Eventstream
    name: iot_ingestion
  - type: KQLDatabase
    name: realtime_analytics
```

### 13.3 Multi-Project Setup (Option B)

If you chose **Option B** (multi-project workflows), adding a new project requires
two steps:

**Step 1 — Create the config directory:**

```
config/projects/
├── demo/                          # Demo project (keep as reference)
│   ├── base_workspace.yaml
│   └── feature_workspace_demo.yaml
├── sales_analytics/               # New project
│   ├── base_workspace.yaml
│   └── feature_workspace.yaml
└── compliance/                    # Another new project
    ├── base_workspace.yaml
    └── feature_workspace.yaml
```

**Step 2 — Run the setup workflow:**

Go to **Actions → Setup Base Workspaces**, select your new project from the
dropdown, and run. The multi-project workflow validates that the config directory
exists before deploying.

**Auto-Discovery**: The multi-project promotion workflows automatically scan
`config/projects/*/base_workspace.yaml` and promote every project that has one.
No workflow edits needed when you add a project — just add the config files.

**Feature Branches**: Use the `feature/<project>/<feature-name>` convention:

```bash
git checkout -b feature/sales_analytics/add-reports
```

The multi-project feature-workspace-create workflow extracts the project name
from the branch path and finds the matching config under `config/projects/`.

> **Tip**: For the full comparison between Option A and Option B, including
> how to switch between them, see [WORKFLOW_OPTIONS.md](WORKFLOW_OPTIONS.md).

### 13.4 Point to a Different CLI Version

Set the `CLI_REPO_REF` repo variable to a specific tag or branch:

```
CLI_REPO_REF = v1.7.6
```

### 13.5 Use Your Own CLI Fork

Set the `CLI_REPO_URL` variable:

```
CLI_REPO_URL = github.com/your-org/your-cli-fork
```

---

## 14. Architecture Reference

### 14.1 Workflow Trigger Map — Option A (Single-Project)

```
                    push feature/*        merge PR to main        manual
                         │                      │                   │
                         ▼                      ▼                   ▼
              ┌─────────────────┐    ┌─────────────────┐  ┌──────────────────┐
              │  Create Feature │    │  Cleanup Feature │  │  Promote Test →  │
              │    Workspace    │    │    Workspace     │  │    Production    │
              └─────────────────┘    └────────┬────────┘  └──────────────────┘
                                              │
                                    push to main triggers
                                              │
                                              ▼
                                   ┌─────────────────┐
                                   │ Promote Dev →    │
                                   │    Test          │
                                   └─────────────────┘
```

### 14.2 Workflow Trigger Map — Option B (Multi-Project)

```
              push feature/<project>/*    merge PR to main           manual
                         │                      │                      │
                         ▼                      ▼                      ▼
              ┌─────────────────┐    ┌─────────────────┐   ┌──────────────────┐
              │ Create Feature  │    │ Cleanup Feature  │   │ Promote Test →   │
              │ Workspace       │    │ Workspace        │   │   Production     │
              │ (project from   │    │ (project from    │   │ (select project  │
              │  branch path)   │    │  branch path)    │   │  from dropdown)  │
              └─────────────────┘    └────────┬────────┘   └──────────────────┘
                                              │
                                    push to main triggers
                                              │
                                              ▼
                                   ┌─────────────────┐
                                   │ Discover ALL     │
                                   │ projects → Matrix│
                                   │ Promote Dev→Test │
                                   │  (parallel)      │
                                   └─────────────────┘
```

### 14.3 Environment Variable Resolution

The YAML configs use `${VAR_NAME}` placeholders. These are resolved at runtime:

1. **In workflows**: GitHub Actions sets environment variables from secrets and variables
2. **In the CLI**: The deployer resolves `${VAR_NAME}` patterns against the shell environment
3. **In promote workflows**: A Python `re.sub` regex resolves `${VAR_NAME}` in the pipeline name read from YAML:

```python
# This is how promote workflows resolve config values
import os, re, yaml
config = yaml.safe_load(open('config/projects/demo/base_workspace.yaml'))
name = config['deployment_pipeline']['pipeline_name']
# Resolve ${VAR} patterns against environment variables
name = re.sub(r'\$\{(\w+)\}', lambda m: os.environ.get(m.group(1), m.group(0)), name)
```

### 14.4 Files Reference

**Option A — Single-Project (Default)**

| File | Purpose |
|------|---------|
| `config/projects/demo/base_workspace.yaml` | Dev workspace + Deployment Pipeline definition |
| `config/projects/demo/feature_workspace_demo.yaml` | Feature workspace template |
| `.github/workflows/ci.yml` | CI validation (YAML lint, secret scan) |
| `.github/workflows/setup-base-workspaces.yml` | One-time Dev workspace setup |
| `.github/workflows/feature-workspace-create.yml` | Auto-provision on `feature/*` push |
| `.github/workflows/feature-workspace-cleanup.yml` | Auto-destroy on PR merge |
| `.github/workflows/promote-dev-to-test.yml` | Auto-promote Dev → Test on push to `main` |
| `.github/workflows/promote-test-to-prod.yml` | Manual promote Test → Prod |

**Option B — Multi-Project (Alternative)**

| File | Purpose |
|------|---------|
| `config/projects/<project>/base_workspace.yaml` | Per-project Dev workspace + pipeline (one per project) |
| `config/projects/<project>/feature_workspace.yaml` | Per-project feature workspace template |
| `.github/multi-project-workflows/ci.yml` | CI validation + project discovery listing |
| `.github/multi-project-workflows/setup-base-workspaces.yml` | Setup with project dropdown selector |
| `.github/multi-project-workflows/feature-workspace-create.yml` | Auto-provision using `feature/<project>/<name>` branch |
| `.github/multi-project-workflows/feature-workspace-cleanup.yml` | Auto-destroy with project extraction from branch |
| `.github/multi-project-workflows/promote-dev-to-test.yml` | Auto-discover + matrix-promote all projects |
| `.github/multi-project-workflows/promote-test-to-prod.yml` | Manual promote with project dropdown |
| `docs/WORKFLOW_OPTIONS.md` | Comparison guide + switching instructions |

### 14.5 Secrets & Variables Quick Reference

**Secrets** (sensitive, encrypted — Settings → Secrets):

| Secret | Purpose |
|--------|---------|
| `AZURE_TENANT_ID` | Entra ID tenant |
| `AZURE_CLIENT_ID` | SP application ID |
| `AZURE_CLIENT_SECRET` | SP secret |
| `FABRIC_GITHUB_TOKEN` | GitHub PAT (for Fabric Git integration) |
| `FABRIC_CAPACITY_ID` | Fabric capacity GUID |
| `DEV_ADMIN_OBJECT_ID` | SP's Object ID (workspace admin) |

**Variables** (non-sensitive, with defaults — Settings → Variables):

| Variable | Default | Purpose |
|----------|---------|---------|
| `PROJECT_PREFIX` | `fabric-cicd-demo` | Prefix for all workspace names |
| `CLI_REPO_URL` | `github.com/your-org/your-cli-repo` | CLI source repository |
| `CLI_REPO_REF` | `v1.7.6` | CLI version tag to install |
| `FABRIC_CLI_VERSION` | `1.3.1` | Microsoft Fabric CLI version |
| `FEATURE_WORKSPACE_CONFIG` | auto-discovered | Feature workspace config path (Option A only) |
| `DEFAULT_PROJECT` | `demo` | Fallback project name (Option B only) |

---

## Appendix: Security Considerations

- **Never commit secrets** to the repo — always use GitHub Secrets
- **PAT rotation**: Set a short expiry on your GitHub PAT and rotate regularly
- **SP secret rotation**: Azure SP secrets expire (default: 2 years). Set a calendar reminder.
- **Least privilege**: The SP only needs Fabric API access and workspace admin — don't give it Azure subscription Owner
- **Audit trail**: The CLI writes structured audit logs (JSONL) for every operation. Review these for compliance.
