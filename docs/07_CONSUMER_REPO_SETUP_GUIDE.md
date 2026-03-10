# Consumer Repo Setup Guide -- Step by Step

> **Version**: 1.1.0 | **Last Updated**: 9 March 2026
>
> Hands-on walkthrough for creating and configuring a Fabric CI/CD consumer
> repository. Covers **all three workflows** -- creating a brand new repo from
> scratch, adding a new project to an existing repo, and scaffolding from a live
> Fabric workspace.
>
> **Prerequisites**: [REPLICATION_GUIDE.md](REPLICATION_GUIDE.md) for
> Azure/Fabric/GitHub prerequisites | [04_QUICK_REFERENCE.md](04_QUICK_REFERENCE.md)
> for secrets cheat sheet

---

## Table of Contents

1. [Three Workflows -- Know the Difference](#1-three-workflows--know-the-difference)
2. [Workflow A -- New Repo from Scratch](#2-workflow-a--new-repo-from-scratch)
   - 2.1 [Automated (Makefile)](#21-automated-makefile)
   - 2.2 [Manual (step-by-step)](#22-manual-step-by-step)
3. [Workflow B -- New Project in Existing Repo](#3-workflow-b--new-project-in-existing-repo)
   - 3.1 [Automated (Makefile)](#31-automated-makefile)
   - 3.2 [Manual (step-by-step)](#32-manual-step-by-step)
4. [Workflow C -- Scaffold from Existing Workspace](#4-workflow-c--scaffold-from-existing-workspace)
5. [After Scaffolding -- Common Steps](#5-after-scaffolding--common-steps)
6. [Validation Checklist](#6-validation-checklist)
7. [Makefile Command Reference](#7-makefile-command-reference)
8. [Frequently Asked Questions](#8-frequently-asked-questions)

---

## 1. Three Workflows -- Know the Difference

There are **three distinct workflows** for onboarding Fabric projects. Choosing the
wrong one leads to confusion, so read this section first.

```
+---------------------------+  +----------------------------+  +----------------------------+
|  WORKFLOW A -- New Repo    |  |  WORKFLOW B -- New Project   |  |  WORKFLOW C -- Scaffold      |
|                           |  |                            |  |                            |
|  "I need a brand new      |  |  "I already have a         |  |  "I have an existing       |
|   GitHub repo for a new   |  |   consumer repo and need   |  |   Fabric workspace and     |
|   team / department."     |  |   to add another data      |  |   want to bring it under   |
|                           |  |   product to it."          |  |   CI/CD management."       |
|                           |  |                            |  |                            |
|  Creates:                 |  |  Creates:                  |  |  Generates:                |
|  * New Git repository     |  |  * config/projects/<p>/    |  |  * YAML config template    |
|  * Full scaffold          |  |  * <project>/.gitkeep      |  |    from live workspace     |
|  * First project          |  |  * Customised YAML         |  |  * Feeds into Workflow B   |
|  * Initial commit         |  |  * Updated dropdown        |  |    via template= param     |
|                           |  |                            |  |                            |
|  Use: make new-repo       |  |  Use: make new-project     |  |  Use: make scaffold        |
|  Time: ~2 minutes         |  |  Time: ~30 seconds         |  |  Time: ~1 minute           |
+---------------------------+  +----------------------------+  +----------------------------+
```

### When to use which?

| Scenario | Workflow |
|----------|----------|
| Brand new team that needs isolated CI/CD | **A -- New Repo** |
| New department with separate GitHub permissions | **A -- New Repo** |
| POC/demo that should not affect production repos | **A -- New Repo** |
| Adding a second data product alongside an existing one | **B -- New Project** |
| Team already has a consumer repo with other projects | **B -- New Project** |
| **Existing Fabric workspace to bring into CI/CD** | **C -- Scaffold**, then **B -- New Project** |
| Workspace already has folders, items, and principals | **C -- Scaffold**, then **B -- New Project** |

> **Workflow C feeds into B**: Scaffold reads a live workspace and generates a config template. You then pass that template to `make new-project template=<slug>` to create the project. Scaffold does **not** create anything in Fabric -- it only reads and generates config.

### Key difference

| Aspect | A (New Repo) | B (New Project) | C (Scaffold) |
|--------|-------------|-----------------|--------------|
| Starting point | No repo exists | Repo on GitHub | Live Fabric workspace |
| Git history | Starts fresh | Adds to existing | No git changes |
| Workflows | Copied from template | Already present | N/A (feeds into B) |
| GitHub Secrets | All must be configured | Core secrets already set | SP credentials required |
| What it creates | Full repo + first project | Project config + git dir | YAML template only |

---

## 2. Workflow A -- New Repo from Scratch

### 2.1 Automated (Makefile)

```bash
# From the template repo root:
make new-repo name=acme-fabric-cicd project=finance display="Finance Reporting"
```

This runs 6 steps automatically:

1. `git init ../acme-fabric-cicd` with `main` branch
2. Copies scaffold files (`.github/`, `config/_templates/`, `docs/`, `Makefile`)
3. Creates the first project (`config/projects/finance/`)
4. Replaces `CHANGE-ME` placeholders in YAML configs
5. Updates workflow project dropdowns
6. Creates initial commit

**After completion:**

```bash
cd ../acme-fabric-cicd
gh repo create <org>/acme-fabric-cicd --private --source . --push
# -- or --
git remote add origin https://github.com/<org>/acme-fabric-cicd.git
git push -u origin main
```

Then configure GitHub Secrets and run the setup workflow.

### 2.2 Manual (step-by-step)

1. **Fork or copy this repo** to your GitHub organization
2. **Rename** the repo to match your team (e.g., `acme-fabric-cicd`)
3. **Edit** `config/projects/demo/base_workspace.yaml`:
   - Update workspace names, display names, descriptions
   - Set the `git_directory` to match your project
   - Update principal variable names
4. **Edit** `config/projects/demo/feature_workspace_demo.yaml` similarly
5. **Rename** the `demo/` directory to your project slug
6. **Update** workflow files to reference your project in dropdown options
7. **Configure** GitHub Secrets (see [Quick Reference](04_QUICK_REFERENCE.md))
8. **Push** to `main` and run the setup workflow

---

## 3. Workflow B -- New Project in Existing Repo

### 3.1 Automated (Makefile)

```bash
make new-project project=hr_analytics display="HR Analytics"

# With a specific template (e.g., from a scaffold output):
make new-project project=hr_analytics display="HR Analytics" template=hr_analytics
```

This runs 4 steps automatically:

1. Copies template to `config/projects/hr_analytics/`
2. Creates Git sync directory: `hr_analytics/.gitkeep`
3. Replaces `CHANGE-ME` placeholders
4. Updates workflow project dropdowns

### 3.2 Manual (step-by-step)

1. **Copy template:**
   ```bash
   cp -r config/projects/_templates/standard_data_product config/projects/hr_analytics
   ```

2. **Create Git sync directory:**
   ```bash
   mkdir -p hr_analytics
   touch hr_analytics/.gitkeep
   ```

3. **Edit `base_workspace.yaml`** -- update workspace names, folders, principals, `git_directory`

4. **Edit `feature_workspace.yaml`** -- match folder structure and `git_directory`

5. **Update workflow dropdowns** -- add `hr_analytics` to the `options:` list in:
   - `setup-base-workspaces.yml`
   - `promote-test-to-prod.yml`

6. **Add project-specific secrets** to GitHub:
   - `HR_ANALYTICS_ADMIN_ID`
   - `HR_ANALYTICS_MEMBERS_ID`

7. **Commit and push:**
   ```bash
   git add config/projects/hr_analytics/ hr_analytics/.gitkeep .github/workflows/
   git commit -m "feat: onboard hr_analytics project"
   git push origin main
   ```

8. **Run** the Setup Base Workspaces workflow selecting `hr_analytics`

---

## 4. Workflow C -- Scaffold from Existing Workspace

Use when you have a **live Fabric workspace** you want to bring under CI/CD.

### Using Make (recommended)

```bash
# Basic -- generates base_workspace.yaml into _templates/
make scaffold workspace="RDSC Supply Chain [DEV]"

# With explicit slug name
make scaffold workspace="RDSC Supply Chain [DEV]" slug=rdsc_supply_chain

# With feature template and deployment pipeline
make scaffold workspace="RDSC Supply Chain [DEV]" feature=true pipeline=true
```

### Using the CLI directly

```bash
# Basic
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

**Output**: `config/projects/_templates/<slug>/base_workspace.yaml`

> **Why `_templates/`?** Scaffolded configs land in the templates directory so they are clearly templates that need review before use. Copy them to a project folder when ready.

> **Prerequisites**: The Service Principal credentials (`AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, `AZURE_TENANT_ID`) must be set in your environment or `.env` file.

### Then create the project from the scaffold

```bash
make new-project project=rdsc_supply_chain display="RDSC Supply Chain" template=rdsc_supply_chain
```

---

## 5. After Scaffolding -- Common Steps

Regardless of which workflow you used, these steps apply:

1. **Review generated YAML** -- check workspace names, folder structure, principals
2. **Configure GitHub Secrets** -- project-specific admin and member group IDs
3. **Add secret env vars to workflows** -- add `<PROJECT>_ADMIN_ID` and `<PROJECT>_MEMBERS_ID` to all relevant workflow `env:` blocks
4. **Commit and push** changes to `main`
5. **Run Setup Base Workspaces** workflow
6. **Verify in Fabric Portal** -- Dev workspace created, Git-synced, pipeline connected
7. **Test the lifecycle** -- create a `feature/<project>/test` branch and verify workspace creation

---

## 6. Validation Checklist

- [ ] `config/projects/<project>/base_workspace.yaml` exists and has valid YAML syntax
- [ ] `config/projects/<project>/feature_workspace*.yaml` exists and has valid YAML syntax
- [ ] `git_directory` in both configs matches the project slug directory
- [ ] Git sync directory exists at repo root: `<project>/.gitkeep`
- [ ] No hardcoded GUIDs in YAML configs (use `${VAR_NAME}` substitution)
- [ ] No `CHANGE-ME` or `CHANGEME_` placeholders remaining in configs
- [ ] Project added to workflow dropdown options (if using multi-project)
- [ ] Project-specific secrets configured in GitHub
- [ ] Secret env vars added to all relevant workflow files
- [ ] Setup Base Workspaces workflow ran successfully
- [ ] Feature workspace creation test passed (push a `feature/<project>/test` branch)

---

## 7. Makefile Command Reference

### Scaffolding & Project Management

| Command | Description | Parameters |
|---------|-------------|------------|
| `make new-repo` | Scaffold a brand new consumer repo | `name=<repo> project=<slug> display="<Name>"` |
| `make new-project` | Add a new project to this repo | `project=<slug> display="<Name>" [template=<name>]` |
| `make scaffold` | Generate config from existing workspace | `workspace="<Name>" [slug=<s>] [feature=true] [pipeline=true]` |
| `make list-projects` | List all configured projects | -- |
| `make validate` | Validate project YAML configs | `project=<slug>` |
| `make show-secrets` | Show required GitHub secrets | `project=<slug>` |
| `make check-structure` | Verify repo structure is correct | -- |

### Git Workflow

| Command | Description | Parameters |
|---------|-------------|------------|
| `make status` | Show branch, remote, and working tree status | -- |
| `make feature` | Create a feature branch | `project=<slug> name=<description>` |
| `make commit` | Stage all changes and commit | `msg="<message>"` |
| `make commit-project` | Stage and commit a project | `project=<slug>` |
| `make push` | Push current branch to remote | -- |
| `make push-new` | First push -- add remote and push main | `remote=<url>` |
| `make pr` | Create a Pull Request to main | `title="<title>" [body="<desc>"]` |
| `make log` | Show recent commit history | -- |
| `make diff` | Show uncommitted changes | -- |

### Information

| Command | Description |
|---------|-------------|
| `make help` | Show all available commands |
| `make guide` | Open the step-by-step guide |

---

## 8. Frequently Asked Questions

**Q: What's the difference between Workflow A and just forking the repo?**
A: `make new-repo` creates a clean repo with only the scaffold files and your first project already configured. Forking gives you the entire template repo including demo configs that you'd need to clean up. Either approach works -- `make new-repo` is faster for a clean start.

**Q: Can I add multiple projects at once?**
A: Run `make new-project` once per project. Each invocation is additive and doesn't affect existing projects.

**Q: What if `make new-project` fails because the template is missing?**
A: Ensure `config/projects/_templates/standard_data_product/` exists with `base_workspace.yaml` and `feature_workspace.yaml`. If you are using a custom template from scaffold, pass `template=<slug>` and ensure that slug directory exists under `_templates/`.

**Q: Do I need to update workflow files when adding a project?**
A: `make new-project` automatically updates workflow dropdowns. If you create a project manually, you need to add it to the `options:` list in `setup-base-workspaces.yml` and `promote-test-to-prod.yml`.

**Q: What's the `template=` parameter for?**
A: It tells `make new-project` which template directory under `_templates/` to copy from. Defaults to `standard_data_product`. Use a scaffold output slug (e.g., `template=hr_analytics`) to create a project from a scaffolded config.

**Q: How do I onboard an existing workspace?**
A: Run `make scaffold workspace="My Workspace [DEV]"` to generate configs, then `make new-project project=<slug> display="<Name>" template=<slug>` to create the project from those configs. See [Onboarding Existing Workspaces](ONBOARDING_EXISTING_WORKSPACES.md) for the full guide.
