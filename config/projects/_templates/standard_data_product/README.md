# Standard Data Product Template

Reusable workspace configuration template using the **8-folder convention** for Microsoft Fabric CI/CD consumer repositories.

## 8-Folder Convention

| Folder           | Fabric Item Types                    | Purpose                          |
| ---------------- | ------------------------------------ | -------------------------------- |
| 000 Orchestrate  | DataPipeline, DataflowGen2           | Scheduling, orchestration        |
| 100 Ingest       | Eventstream                          | Real-time and batch ingestion    |
| 200 Store        | Lakehouse                            | Bronze + Silver data layers      |
| 300 Prepare      | Notebook, SparkJobDefinition         | Transformation, data prep        |
| 400 Model        | Warehouse, SemanticModel             | Curated models, star schemas     |
| 500 Visualize    | Report, Dashboard                    | End-user reporting               |
| 999 Libraries    | Environment                          | Shared libraries, dependencies   |
| Archive          | *(any)*                              | Deprecated / retired items       |

## How to Use

### Option A: `make new-project` (Recommended)

```bash
make new-project project=my_project display="My Project"
```

This copies the template, replaces all `CHANGE-ME` placeholders, creates the Git sync directory, and updates workflow dropdowns automatically.

### Option B: `make scaffold` (From Existing Workspace)

```bash
make scaffold workspace="My Workspace [DEV]" slug=my_project
make new-project project=my_project display="My Project" template=my_project
```

Scaffold introspects a live Fabric workspace and generates a config template. Then use `new-project` with the `template=` parameter to create the project from it.

### Option C: Manual Copy

1. Copy this folder to `config/projects/<your_project>/`
2. In `base_workspace.yaml`:
   - Replace `CHANGE-ME [DEV]` with `<Display Name> [DEV]` (and TEST, PROD)
   - Replace `CHANGE-ME - Pipeline` with `<Display Name> - Pipeline`
   - Replace `/CHANGE-ME` with `/<your_project>` (git_directory)
   - Replace `CHANGEME_ADMIN_ID` with `<YOUR_PROJECT>_ADMIN_ID`
   - Replace `CHANGEME_MEMBERS_ID` with `<YOUR_PROJECT>_MEMBERS_ID`
3. In `feature_workspace.yaml`:
   - Replace `/CHANGE-ME` with `/<your_project>`
   - Replace `CHANGEME_ADMIN_ID` / `CHANGEME_MEMBERS_ID` as above
4. Create the Git sync directory: `mkdir -p <your_project> && touch <your_project>/.gitkeep`
5. Add the project to workflow dropdowns (search for `# Add new projects here`)

## Access Control Environment Variables

| Variable                            | Type             | Role        | Description                              |
| ----------------------------------- | ---------------- | ----------- | ---------------------------------------- |
| `AZURE_CLIENT_ID`                   | ServicePrincipal | Admin       | Automation SP (shared, all projects)     |
| `ADDITIONAL_ADMIN_PRINCIPAL_ID`     | Group            | Admin       | IT governance admin group (shared)       |
| `ADDITIONAL_CONTRIBUTOR_PRINCIPAL_ID` | Group          | Contributor | Governance contributor group (shared)    |
| `<PROJECT>_ADMIN_ID`               | Group            | Admin       | Project-specific admin group             |
| `<PROJECT>_MEMBERS_ID`             | Group            | Member      | Project-specific team members            |

Set these as GitHub Secrets. The `<PROJECT>` prefix is the UPPER_CASE version of your project slug (e.g., `HR_ANALYTICS_ADMIN_ID`).
