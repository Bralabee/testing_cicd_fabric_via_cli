# START HERE — Fabric CI/CD Consumer Repo Template

> **Version**: 1.8.3 | **Last Updated**: 9 March 2026
>
> This is the **starting point** for the consumer repository template documentation.
> Read this page to understand what this repo does and where to go next.

---

## 1. What Is This Repository?

This is a **consumer repository template** -- a ready-to-fork GitHub repository that
contains project-specific configurations and GitHub Actions workflows for automating
Microsoft Fabric workspace management via CI/CD.

Fork or copy this repo, customise the YAML configs and GitHub Secrets for your
projects, and you have a fully automated Fabric workspace lifecycle -- no CLI code
changes needed.

### How the Two-Repo Model Works

```
+-----------------------------+        +-------------------------------+
|  CLI Library Repo            |        |  THIS REPO (Consumer Template) |
|  (usf_fabric_cli_cicd)       |        |  (fabric_cicd_test_repo)       |
|                              |        |                                |
|  - fabric-cicd CLI engine    | <------+  - config/projects/*.yaml      |
|  - Deployment logic          | pip    |  - .github/workflows/*.yml     |
|  - Blueprint templates       | install|  - Makefile automation          |
|  - 14 CLI commands           |        |  - Project secrets (GitHub)    |
+-----------------------------+        +-------------------------------+
```

**You don't modify the CLI repo.** You configure your projects here and GitHub Actions
installs the CLI at runtime via `pip install git+...@v1.8.3`.

---

## 2. Who Are You? (Start Here)

### "I'm setting up this template for a new team"

Follow the complete end-to-end setup:

1. Read this page (you are here)
2. [Replication Guide](REPLICATION_GUIDE.md) -- **THE** canonical guide (45-90 min)
3. [Workflow Options](WORKFLOW_OPTIONS.md) -- choose single vs multi-project
4. [Consumer Repo Setup Guide](07_CONSUMER_REPO_SETUP_GUIDE.md) -- hands-on Makefile walkthrough

### "I'm adding a new project to an existing consumer repo"

1. [Consumer Repo Setup Guide](07_CONSUMER_REPO_SETUP_GUIDE.md) -- Workflow B (New Project)
2. Run `make new-project project=<slug> display="<Display Name>"`
3. Configure GitHub Secrets for the new project
4. Run the `setup-base-workspaces` workflow

### "I have an existing Fabric workspace to bring into CI/CD"

1. [Onboarding Existing Workspaces](ONBOARDING_EXISTING_WORKSPACES.md) -- **THE** guide for this
2. **Shortcut**: Run `make scaffold workspace="My Workspace [DEV]"` to auto-generate YAML configs
3. Then: `make new-project project=<slug> display="<Name>" template=<slug>`
4. Review generated configs, configure secrets, run setup workflow

### "I'm developing a feature in an existing project"

1. Create a branch: `git checkout -b feature/<project>/<description>`
2. Push -- the `feature-workspace-create` workflow runs automatically
3. Develop in your isolated Fabric workspace
4. Open PR -- CI validates configs
5. Merge to `main` -- workspace auto-destroyed, Dev auto-syncs
6. Promote Dev to Test manually, then Test to Prod manually
7. See [Quick Reference](04_QUICK_REFERENCE.md) for the cheat sheet

### "Something went wrong and I need help"

1. [Quick Reference -- Troubleshooting](04_QUICK_REFERENCE.md#troubleshooting-quick-fixes) (common fixes)
2. [Replication Guide -- Troubleshooting](REPLICATION_GUIDE.md) (detailed scenarios)

---

## 3. Documentation Index

| # | Document | Description | Time |
|---|----------|-------------|------|
| **->** | [**00_START_HERE.md**](00_START_HERE.md) | You are here -- orientation and routing | 5 min |
| 1 | [WORKFLOW_OPTIONS.md](WORKFLOW_OPTIONS.md) | Single-project vs multi-project strategy | 10 min |
| 2 | [**REPLICATION_GUIDE.md**](REPLICATION_GUIDE.md) | Complete end-to-end setup guide (canonical) | 45-90 min |
| 3 | [E2E_VALIDATION_REPORT.md](E2E_VALIDATION_REPORT.md) | Live test results and bug fixes | 10 min |
| 4 | [04_QUICK_REFERENCE.md](04_QUICK_REFERENCE.md) | Cheat sheet -- secrets, commands, configs | 2 min |
| 5 | [07_CONSUMER_REPO_SETUP_GUIDE.md](07_CONSUMER_REPO_SETUP_GUIDE.md) | New repo / new project setup (Makefile) | 30 min |
| 6 | [**ONBOARDING_EXISTING_WORKSPACES.md**](ONBOARDING_EXISTING_WORKSPACES.md) | Bring existing workspaces into CI/CD | 20 min |
| 7 | [WORKFLOW_REFERENCE.md](WORKFLOW_REFERENCE.md) | Technical workflow reference (all 7 workflows) | 15 min |

### CLI Library Documentation (in the other repo)

| Guide | Description |
|-------|-------------|
| [CLI START HERE](https://github.com/<org>/usf_fabric_cli_cicd/blob/main/docs/01_User_Guides/00_START_HERE.md) | CLI repo orientation and full guide index |
| [Project Configuration](https://github.com/<org>/usf_fabric_cli_cicd/blob/main/docs/01_User_Guides/03_Project_Configuration.md) | YAML config syntax |
| [Blueprint Catalog](https://github.com/<org>/usf_fabric_cli_cicd/blob/main/docs/01_User_Guides/07_Blueprint_Catalog.md) | 11 project templates |
| [CLI Reference](https://github.com/<org>/usf_fabric_cli_cicd/blob/main/docs/01_User_Guides/CLI_REFERENCE.md) | All commands, flags, env vars |

---

## 4. Workflow Summary

This template ships with **7 GitHub Actions workflows**:

| Workflow | Trigger | What It Does |
|----------|---------|-------------|
| `ci.yml` | PR to `main` / push to `main` | YAML validation, secret scanning, config linting |
| `setup-base-workspaces.yml` | Manual (`workflow_dispatch`) | Creates Dev workspace + Deployment Pipeline + Test/Prod |
| `feature-workspace-create.yml` | Push to `feature/**` | Creates isolated feature branch workspace with Git |
| `feature-workspace-cleanup.yml` | PR merged to `main` | Destroys feature workspace, frees capacity |
| `deploy-dev.yml` | Push to `main` | Auto-organizes Dev folders after Git Sync |
| `promote-dev-to-test.yml` | Push to `main` / manual | Promotes Dev to Test via Deployment Pipeline |
| `promote-test-to-prod.yml` | Manual (`workflow_dispatch`) | Promotes Test to Prod (type "PROMOTE" to confirm) |

---

## 5. Quick Start (5 Steps)

For a new team starting from scratch:

```
Step 1: Fork/copy this repo
Step 2: Configure GitHub Secrets (see Quick Reference for the full list)
Step 3: Customise config/projects/<project>/base_workspace.yaml
Step 4: Run the setup-base-workspaces workflow
Step 5: Push a feature/* branch to test the lifecycle
```

**Full details**: [Replication Guide](REPLICATION_GUIDE.md)

---

## 6. Template Projects Included

This template ships with two demo projects pre-configured:

| Project | Config Path | Description |
|---------|-------------|-------------|
| `demo` | `config/projects/demo/` | Basic demo workspace (8-folder convention) |
| `sales_analytics` | `config/projects/sales_analytics/` | Example second project (8-folder convention) |

These are meant as starting points. Rename, modify, or delete them to suit your needs.
