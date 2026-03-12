# ═══════════════════════════════════════════════════════════════════════════════
# Consumer Repo — Makefile
# ═══════════════════════════════════════════════════════════════════════════════
#
# Automates the two primary workflows for Fabric CI/CD consumer repositories:
#
#   WORKFLOW A — New Repo    (make new-repo)
#     Scaffold a brand new consumer repository from scratch.
#     Use when: a new team/department needs their own isolated GitHub repo.
#     What it does: git init → copy scaffold → create first project → commit.
#
#   WORKFLOW B — New Project (make new-project)
#     Add a new data product to an EXISTING consumer repo.
#     Use when: you already have a repo and need to onboard another project.
#     What it does: copy template → replace placeholders → create git-sync dir.
#
# QUICK START:
#   make help                     # Show all available commands
#   make new-repo   name=my-repo project=finance display="Finance"
#   make new-project project=hr display="Human Resources"
#   make list-projects            # Show all configured projects
#   make validate project=finance # Validate a project's YAML configs
#
# ═══════════════════════════════════════════════════════════════════════════════

# Use bare 'bash' so Make finds it via PATH on all platforms.
# Linux/macOS: bash is always on PATH.
# Windows: requires Git for Windows (https://git-scm.com) which adds bash to PATH.
ifeq ($(OS),Windows_NT)
    SHELL := bash
else
    SHELL := /bin/bash
endif
.DEFAULT_GOAL := help

# ── Paths ────────────────────────────────────────────────────────────────────
# template= parameter overrides the default template (e.g., template=my_scaffold)
TEMPLATE_DIR   := config/projects/_templates/$(or $(template),standard_data_product)
PROJECTS_DIR   := config/projects
WORKFLOWS_DIR  := .github/workflows

# ── Colours (for terminal output) ────────────────────────────────────────────
BOLD   := \033[1m
GREEN  := \033[32m
YELLOW := \033[33m
RED    := \033[31m
CYAN   := \033[36m
DIM    := \033[2m
RESET  := \033[0m

# ═══════════════════════════════════════════════════════════════════════════════
# HELP
# ═══════════════════════════════════════════════════════════════════════════════

.PHONY: help
help: ## Show this help message
	@echo ""
	@echo -e "$(BOLD)$(CYAN)Consumer Repo — Make Commands$(RESET)"
	@echo -e "$(DIM)Fabric CI/CD consumer repository automation$(RESET)"
	@echo ""
	@echo -e "$(BOLD)━━━ WORKFLOW A: New Repo (from scratch) ━━━$(RESET)"
	@echo -e "  $(GREEN)make new-repo$(RESET)          Scaffold a brand new consumer repo"
	@echo -e "                        $(DIM)name=<repo_name> project=<first_project> display=\"<Display Name>\"$(RESET)"
	@echo ""
	@echo -e "$(BOLD)━━━ WORKFLOW B: New Project (in existing repo) ━━━$(RESET)"
	@echo -e "  $(GREEN)make new-project$(RESET)       Add a new data product project"
	@echo -e "                        $(DIM)project=<project_name> display=\"<Display Name>\" [template=<name>]$(RESET)"
	@echo ""
	@echo -e "$(BOLD)━━━ Scaffold (from live workspace) ━━━$(RESET)"
	@echo -e "  $(GREEN)make scaffold$(RESET)          Generate a config template from an existing Fabric workspace"
	@echo -e "                        $(DIM)workspace=\"<Workspace Name>\" [slug=<project_slug>] [feature=true] [pipeline=\"<Name>\"]$(RESET)"
	@echo -e "                        $(YELLOW)Example:$(RESET)"
	@echo -e "                        $(DIM)make scaffold workspace=\"Sales\" slug=sales_analytics feature=true pipeline=\"Sales Pipeline\"$(RESET)"
	@echo -e "                        $(DIM)Output: config/projects/_templates/<slug>/$(RESET)"
	@echo ""
	@echo -e "$(BOLD)━━━ Project Management ━━━$(RESET)"
	@echo -e "  $(GREEN)make list-projects$(RESET)     List all configured projects"
	@echo -e "  $(GREEN)make validate$(RESET)          Validate project YAML configs"
	@echo -e "                        $(DIM)project=<project_name>$(RESET)"
	@echo -e "  $(GREEN)make show-secrets$(RESET)      Show required GitHub secrets for a project"
	@echo -e "                        $(DIM)project=<project_name>$(RESET)"
	@echo -e "  $(GREEN)make check-structure$(RESET)   Verify repo structure is correct"
	@echo ""
	@echo -e "$(BOLD)━━━ Git Workflow ━━━$(RESET)"
	@echo -e "  $(GREEN)make status$(RESET)            Show current branch, remote, and working tree status"
	@echo -e "  $(GREEN)make feature$(RESET)           Create a feature branch (follows naming convention)"
	@echo -e "                        $(DIM)project=<project_name> name=<description>$(RESET)"
	@echo -e "  $(GREEN)make commit$(RESET)            Stage all changes and commit with a message"
	@echo -e "                        $(DIM)msg=\"<commit message>\"$(RESET)"
	@echo -e "  $(GREEN)make commit-project$(RESET)    Stage and commit a new/modified project"
	@echo -e "                        $(DIM)project=<project_name>$(RESET)"
	@echo -e "  $(GREEN)make push$(RESET)              Push current branch to remote (with tracking)"
	@echo -e "  $(GREEN)make push-new$(RESET)          First push — add remote and push main"
	@echo -e "                        $(DIM)remote=<github_url>$(RESET)"
	@echo -e "  $(GREEN)make pr$(RESET)                Create a Pull Request to main (requires gh CLI)"
	@echo -e "                        $(DIM)title=\"<PR title>\" [body=\"<description>\"]$(RESET)"
	@echo -e "  $(GREEN)make log$(RESET)               Show recent commit history (compact)"
	@echo -e "  $(GREEN)make diff$(RESET)              Show uncommitted changes"
	@echo ""
	@echo -e "$(BOLD)━━━ Information ━━━$(RESET)"
	@echo -e "  $(GREEN)make help$(RESET)              Show this help message"
	@echo -e "  $(GREEN)make guide$(RESET)             Open the step-by-step guide"
	@echo ""
	@echo -e "$(DIM)For full documentation: docs/07_CONSUMER_REPO_SETUP_GUIDE.md$(RESET)"
	@echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# WORKFLOW A — NEW REPO (from scratch)
# ═══════════════════════════════════════════════════════════════════════════════
#
# Creates a brand new consumer repository with a single project configured.
# The new repo is created as a sibling directory (next to this repo).
#
# Parameters:
#   name     — Repository directory name (e.g., acme-fabric-cicd)
#   project  — First project slug (lowercase, underscores) (e.g., finance)
#   display  — Human-readable project name (e.g., "Finance Reporting")
#
# Example:
#   make new-repo name=acme-fabric-cicd project=finance display="Finance"
#
# What it does:
#   1. git init ../$(name) with main branch
#   2. Copy scaffold files (.github, config/_templates, docs, .gitignore, etc.)
#   3. Run the "new-project" logic for the first project
#   4. Create initial commit
#
# ═══════════════════════════════════════════════════════════════════════════════

.PHONY: new-repo
new-repo: _validate-new-repo-params ## Scaffold a new consumer repo (name=<repo> project=<slug> display="<Name>")
	@echo ""
	@echo -e "$(BOLD)$(CYAN)═══ WORKFLOW A: Scaffolding New Consumer Repo ═══$(RESET)"
	@echo ""
	@# ── Step 1: Check target directory doesn't exist ────────────────────
	@if [ -d "../$(name)" ]; then \
		echo -e "$(RED)ERROR: Directory ../$(name) already exists.$(RESET)"; \
		echo -e "$(DIM)Remove it first or choose a different name.$(RESET)"; \
		exit 1; \
	fi
	@# ── Step 2: Git init ────────────────────────────────────────────────
	@echo -e "$(GREEN)Step 1/6$(RESET) — Initialising Git repository: ../$(name)"
	@git init "../$(name)" --quiet
	@cd "../$(name)" && git branch -m main
	@echo -e "         $(DIM)✓ Created on branch 'main'$(RESET)"
	@echo ""
	@# ── Step 3: Copy scaffold ───────────────────────────────────────────
	@echo -e "$(GREEN)Step 2/6$(RESET) — Copying scaffold files"
	@cp -r .github "../$(name)/.github"
	@mkdir -p "../$(name)/$(TEMPLATE_DIR)"
	@cp -r $(TEMPLATE_DIR)/. "../$(name)/$(TEMPLATE_DIR)/"
	@cp -r docs "../$(name)/docs"
	@cp .gitignore "../$(name)/.gitignore" 2>/dev/null || true
	@# Create a clean README for the new repo
	@echo "# $(name)" > "../$(name)/README.md"
	@echo "" >> "../$(name)/README.md"
	@echo "Consumer repository for Microsoft Fabric CI/CD." >> "../$(name)/README.md"
	@echo "" >> "../$(name)/README.md"
	@echo "## Quick Start" >> "../$(name)/README.md"
	@echo "" >> "../$(name)/README.md"
	@echo '```bash' >> "../$(name)/README.md"
	@echo "make help              # See all available commands" >> "../$(name)/README.md"
	@echo "make list-projects     # List configured projects" >> "../$(name)/README.md"
	@echo 'make new-project project=<name> display="<Display Name>"  # Add a project' >> "../$(name)/README.md"
	@echo '```' >> "../$(name)/README.md"
	@echo "" >> "../$(name)/README.md"
	@echo "See [docs/07_CONSUMER_REPO_SETUP_GUIDE.md](docs/07_CONSUMER_REPO_SETUP_GUIDE.md) for the full guide." >> "../$(name)/README.md"
	@# Create a minimal CHANGELOG
	@echo "# Changelog" > "../$(name)/CHANGELOG.md"
	@echo "" >> "../$(name)/CHANGELOG.md"
	@echo "## [Unreleased]" >> "../$(name)/CHANGELOG.md"
	@echo "" >> "../$(name)/CHANGELOG.md"
	@echo "### Added" >> "../$(name)/CHANGELOG.md"
	@echo "- Initial consumer repo scaffold" >> "../$(name)/CHANGELOG.md"
	@echo "- Project: $(project) ($(display))" >> "../$(name)/CHANGELOG.md"
	@# Copy the Makefile itself
	@cp Makefile "../$(name)/Makefile"
	@echo -e "         $(DIM)✓ .github/ (workflows + scripts)$(RESET)"
	@echo -e "         $(DIM)✓ config/projects/_templates/$(RESET)"
	@echo -e "         $(DIM)✓ docs/ (guides)$(RESET)"
	@echo -e "         $(DIM)✓ Makefile, README, CHANGELOG, .gitignore$(RESET)"
	@echo ""
	@# ── Step 4: Create the first project inside the new repo ────────────
	@echo -e "$(GREEN)Step 3/6$(RESET) — Creating first project: $(project)"
	@cp -r "../$(name)/$(TEMPLATE_DIR)/." "../$(name)/$(PROJECTS_DIR)/$(project)/"
	@mkdir -p "../$(name)/$(project)"
	@touch "../$(name)/$(project)/.gitkeep"
	@echo -e "         $(DIM)✓ Config: $(PROJECTS_DIR)/$(project)/$(RESET)"
	@echo -e "         $(DIM)✓ Git Sync dir: $(project)/$(RESET)"
	@echo ""
	@# ── Step 5: Replace placeholders ────────────────────────────────────
	@echo -e "$(GREEN)Step 4/6$(RESET) — Customising config placeholders"
	@$(call replace-placeholders,../${name},${project},${display})
	@echo ""
	@# ── Step 6: Update workflow project dropdown ────────────────────────
	@echo -e "$(GREEN)Step 5/6$(RESET) — Updating workflow project dropdown"
	@$(call update-workflow-dropdown,../${name},${project})
	@echo ""
	@# ── Step 7: Initial commit ──────────────────────────────────────────
	@echo -e "$(GREEN)Step 6/6$(RESET) — Creating initial commit"
	@cd "../$(name)" && git add -A && git commit -m "chore: initial consumer repo scaffold" \
		-m "" \
		-m "- Scaffolded from consumer repo template" \
		-m "- Project: $(project) ($(display))" \
		-m "- 6 GitHub Actions workflows" \
		-m "- Git Sync directory: $(project)/" \
		--quiet
	@echo -e "         $(DIM)✓ Committed to main$(RESET)"
	@echo ""
	@echo -e "$(BOLD)$(GREEN)═══ Done! New consumer repo ready at: ../$(name) ═══$(RESET)"
	@echo ""
	@echo -e "$(BOLD)Next steps:$(RESET)"
	@echo -e "  1. $(CYAN)cd ../$(name)$(RESET)"
	@echo -e "  2. Create a GitHub repo and push:"
	@echo -e "     $(DIM)gh repo create <org>/$(name) --private --source . --push$(RESET)"
	@echo -e "     $(DIM)— or —$(RESET)"
	@echo -e "     $(DIM)git remote add origin https://github.com/<org>/$(name).git$(RESET)"
	@echo -e "     $(DIM)git push -u origin main$(RESET)"
	@echo -e "  3. Configure GitHub Secrets (see: $(CYAN)make show-secrets project=$(project)$(RESET))"
	@echo -e "  4. Run $(CYAN)Setup Base Workspaces$(RESET) workflow in GitHub Actions"
	@echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# WORKFLOW B — NEW PROJECT (in existing repo)
# ═══════════════════════════════════════════════════════════════════════════════
#
# Adds a new data product project to THIS consumer repo.
# Use when onboarding additional projects into a multi-project setup.
#
# Parameters:
#   project  — Project slug (lowercase, underscores) (e.g., hr_analytics)
#   display  — Human-readable project name (e.g., "HR Analytics")
#
# Example:
#   make new-project project=hr_analytics display="HR Analytics"
#
# What it does:
#   1. Copy template to config/projects/<project>/
#   2. Create <project>/.gitkeep for Git sync
#   3. Replace CHANGE-ME placeholders in both YAML configs
#   4. Update workflow dropdown (if applicable)
#   5. Print next steps (secrets, workflow, commit)
#
# ═══════════════════════════════════════════════════════════════════════════════

.PHONY: new-project
new-project: _validate-new-project-params ## Add a new project (project=<slug> display="<Name>" [template=<name>])
	@echo ""
	@echo -e "$(BOLD)$(CYAN)═══ WORKFLOW B: Adding New Project ═══$(RESET)"
	@echo ""
	@# ── Check project doesn't already exist ──────────────────────────────
	@if [ -d "$(PROJECTS_DIR)/$(project)" ]; then \
		echo -e "$(RED)ERROR: Project '$(project)' already exists at $(PROJECTS_DIR)/$(project)/$(RESET)"; \
		echo -e "$(DIM)Use 'make list-projects' to see existing projects.$(RESET)"; \
		exit 1; \
	fi
	@# ── Check template exists ────────────────────────────────────────────
	@if [ ! -d "$(TEMPLATE_DIR)" ]; then \
		echo -e "$(RED)ERROR: Template not found at $(TEMPLATE_DIR)/$(RESET)"; \
		echo -e "$(DIM)Ensure the _templates directory exists in config/projects/.$(RESET)"; \
		exit 1; \
	fi
	@# ── Step 1: Copy template ────────────────────────────────────────────
	@echo -e "$(GREEN)Step 1/4$(RESET) — Copying template ($(notdir $(TEMPLATE_DIR))) to $(PROJECTS_DIR)/$(project)/"
	@cp -r "$(TEMPLATE_DIR)/." "$(PROJECTS_DIR)/$(project)/"
	@echo -e "         $(DIM)✓ base_workspace.yaml$(RESET)"
	@echo -e "         $(DIM)✓ feature_workspace.yaml$(RESET)"
	@echo -e "         $(DIM)✓ README.md$(RESET)"
	@echo ""
	@# ── Step 2: Create Git sync directory ────────────────────────────────
	@echo -e "$(GREEN)Step 2/4$(RESET) — Creating Git sync directory: $(project)/"
	@mkdir -p "$(project)"
	@touch "$(project)/.gitkeep"
	@echo -e "         $(DIM)✓ $(project)/.gitkeep$(RESET)"
	@echo ""
	@# ── Step 3: Replace placeholders ─────────────────────────────────────
	@echo -e "$(GREEN)Step 3/4$(RESET) — Customising config placeholders"
	@$(call replace-placeholders,.,${project},${display})
	@echo ""
	@# ── Step 4: Update workflow dropdown ─────────────────────────────────
	@echo -e "$(GREEN)Step 4/4$(RESET) — Updating workflow project dropdown"
	@$(call update-workflow-dropdown,.,${project})
	@echo ""
	@# ── Summary ──────────────────────────────────────────────────────────
	@UPPER_PROJECT=$$(echo "$(project)" | tr '[:lower:]' '[:upper:]'); \
	echo -e "$(BOLD)$(GREEN)═══ Done! Project '$(project)' created ═══$(RESET)"; \
	echo ""; \
	echo -e "$(BOLD)Files created:$(RESET)"; \
	echo -e "  $(CYAN)$(PROJECTS_DIR)/$(project)/base_workspace.yaml$(RESET)    — Dev + Pipeline config"; \
	echo -e "  $(CYAN)$(PROJECTS_DIR)/$(project)/feature_workspace.yaml$(RESET) — Feature branch template"; \
	echo -e "  $(CYAN)$(project)/.gitkeep$(RESET)                              — Git Sync directory"; \
	echo ""; \
	echo -e "$(BOLD)Next steps:$(RESET)"; \
	echo -e "  1. Review the generated configs:"; \
	echo -e "     $(DIM)cat $(PROJECTS_DIR)/$(project)/base_workspace.yaml$(RESET)"; \
	echo -e "  2. Add GitHub Secrets for this project:"; \
	echo -e "     $(CYAN)$${UPPER_PROJECT}_ADMIN_ID$(RESET)    — Entra ID group Object ID for project admins"; \
	echo -e "     $(CYAN)$${UPPER_PROJECT}_MEMBERS_ID$(RESET)  — Entra ID group Object ID for project members"; \
	echo -e "  3. Add the secret references to ALL workflow env blocks"; \
	echo -e "     $(DIM)(search for '# ── Project-specific principals' in .github/workflows/*.yml)$(RESET)"; \
	echo -e "  4. Commit and push:"; \
	echo -e "     $(DIM)git add -A && git commit -m \"feat: onboard $(project) project\"$(RESET)"; \
	echo -e "  5. Run $(CYAN)Setup Base Workspaces$(RESET) workflow → select '$(project)'"; \
	echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# PROJECT MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════════════

.PHONY: list-projects
list-projects: ## List all configured projects
	@echo ""
	@echo -e "$(BOLD)Configured Projects$(RESET)"
	@echo -e "$(DIM)Location: $(PROJECTS_DIR)/<project>/$(RESET)"
	@echo ""
	@found=0; \
	for dir in $(PROJECTS_DIR)/*/; do \
		proj=$$(basename "$$dir"); \
		if [ "$$proj" = "_templates" ]; then continue; fi; \
		found=$$((found + 1)); \
		has_base="✗"; has_feature="✗"; has_gitdir="✗"; \
		if [ -f "$$dir/base_workspace.yaml" ]; then has_base="$(GREEN)✓$(RESET)"; fi; \
		if [ -f "$$dir/feature_workspace.yaml" ]; then has_feature="$(GREEN)✓$(RESET)"; fi; \
		if [ -d "$$proj" ]; then has_gitdir="$(GREEN)✓$(RESET)"; fi; \
		echo -e "  $(BOLD)$$proj$(RESET)"; \
		echo -e "    base_workspace.yaml:    $$has_base"; \
		echo -e "    feature_workspace.yaml: $$has_feature"; \
		echo -e "    Git sync dir ($$proj/):  $$has_gitdir"; \
		echo ""; \
	done; \
	if [ $$found -eq 0 ]; then \
		echo -e "  $(DIM)No projects found. Run:$(RESET)"; \
		echo -e "  $(CYAN)make new-project project=<name> display=\"<Display Name>\"$(RESET)"; \
		echo ""; \
	fi

.PHONY: validate
validate: ## Validate project config files (project=<name>)
	@if [ -z "$(project)" ]; then \
		echo ""; \
		printf "\033[31mERROR: Missing required parameter 'project'\033[0m\n"; \
		echo ""; \
		printf "\033[1mUsage:\033[0m\n"; \
		printf "  make validate project=<project_slug>\n"; \
		echo ""; \
		printf "\033[1mExample:\033[0m\n"; \
		printf "  make validate project=finance\n"; \
		echo ""; \
		exit 1; \
	fi
	@echo ""
	@echo -e "$(BOLD)Validating project: $(project)$(RESET)"
	@echo ""
	@errors=0; \
	base="$(PROJECTS_DIR)/$(project)/base_workspace.yaml"; \
	feat="$(PROJECTS_DIR)/$(project)/feature_workspace.yaml"; \
	gitdir="$(project)"; \
	\
	echo -n "  base_workspace.yaml exists ........... "; \
	if [ -f "$$base" ]; then echo -e "$(GREEN)✓$(RESET)"; else echo -e "$(RED)✗ MISSING$(RESET)"; errors=$$((errors+1)); fi; \
	\
	echo -n "  feature_workspace.yaml exists ........ "; \
	if [ -f "$$feat" ]; then echo -e "$(GREEN)✓$(RESET)"; else echo -e "$(RED)✗ MISSING$(RESET)"; errors=$$((errors+1)); fi; \
	\
	echo -n "  Git sync directory exists ............ "; \
	if [ -d "$$gitdir" ]; then echo -e "$(GREEN)✓$(RESET)"; else echo -e "$(RED)✗ MISSING (run: mkdir -p $(project) && touch $(project)/.gitkeep)$(RESET)"; errors=$$((errors+1)); fi; \
	\
	echo -n "  No CHANGE-ME placeholders remain ..... "; \
	cm_bad=""; \
	if [ -f "$$base" ] && grep -q "CHANGE-ME" "$$base"; then cm_bad="base"; fi; \
	if [ -f "$$feat" ] && grep -q "CHANGE-ME" "$$feat"; then cm_bad="$$cm_bad feat"; fi; \
	if [ -z "$$cm_bad" ]; then \
		echo -e "$(GREEN)✓$(RESET)"; \
	else \
		echo -e "$(RED)✗$(RESET)"; \
		if echo "$$cm_bad" | grep -q "base"; then echo -e "         $(RED)→ Found in base_workspace.yaml$(RESET)"; errors=$$((errors+1)); fi; \
		if echo "$$cm_bad" | grep -q "feat"; then echo -e "         $(RED)→ Found in feature_workspace.yaml$(RESET)"; errors=$$((errors+1)); fi; \
	fi; \
	\
	echo -n "  No CHANGEME_ placeholders remain ..... "; \
	cm2_bad=""; \
	if [ -f "$$base" ] && grep -q "CHANGEME_" "$$base"; then cm2_bad="base"; fi; \
	if [ -f "$$feat" ] && grep -q "CHANGEME_" "$$feat"; then cm2_bad="$$cm2_bad feat"; fi; \
	if [ -z "$$cm2_bad" ]; then \
		echo -e "$(GREEN)✓$(RESET)"; \
	else \
		echo -e "$(RED)✗$(RESET)"; \
		if echo "$$cm2_bad" | grep -q "base"; then echo -e "         $(RED)→ Found in base_workspace.yaml$(RESET)"; errors=$$((errors+1)); fi; \
		if echo "$$cm2_bad" | grep -q "feat"; then echo -e "         $(RED)→ Found in feature_workspace.yaml$(RESET)"; errors=$$((errors+1)); fi; \
	fi; \
	\
	echo -n "  git_directory matches project slug ... "; \
	if [ -f "$$base" ] && grep -q "git_directory: /$(project)" "$$base"; then \
		echo -e "$(GREEN)✓$(RESET)"; \
	else \
		echo -e "$(RED)✗ Expected: git_directory: /$(project)$(RESET)"; errors=$$((errors+1)); \
	fi; \
	\
	echo -n "  YAML syntax valid .................... "; \
	if command -v python3 &>/dev/null; then \
		yaml_bad=""; \
		if [ -f "$$base" ] && ! python3 -c "import yaml; yaml.safe_load(open('$$base'))" 2>/dev/null; then yaml_bad="base"; fi; \
		if [ -f "$$feat" ] && ! python3 -c "import yaml; yaml.safe_load(open('$$feat'))" 2>/dev/null; then yaml_bad="$$yaml_bad feat"; fi; \
		if [ -z "$$yaml_bad" ]; then \
			echo -e "$(GREEN)✓$(RESET)"; \
		else \
			echo -e "$(RED)✗$(RESET)"; \
			if echo "$$yaml_bad" | grep -q "base"; then echo -e "         $(RED)→ Invalid YAML in base_workspace.yaml$(RESET)"; errors=$$((errors+1)); fi; \
			if echo "$$yaml_bad" | grep -q "feat"; then echo -e "         $(RED)→ Invalid YAML in feature_workspace.yaml$(RESET)"; errors=$$((errors+1)); fi; \
		fi; \
	else \
		echo -e "$(YELLOW)⚠ Skipped (python3 not found)$(RESET)"; \
	fi; \
	\
	echo -n "  Required fields present .............. "; \
	if command -v python3 &>/dev/null && [ -f "$$base" ]; then \
		missing=$$(python3 -c " \
import yaml, sys; \
c = yaml.safe_load(open('$$base')); \
ws = c.get('workspace', {}); \
missing = [f for f in ['name', 'capacity_id', 'git_directory', 'git_repo', 'git_branch'] if f not in ws]; \
print(' '.join(missing)) if missing else sys.exit(0) \
" 2>/dev/null); \
		if [ -z "$$missing" ]; then \
			echo -e "$(GREEN)✓$(RESET)"; \
		else \
			echo -e "$(RED)✗ Missing: $$missing$(RESET)"; errors=$$((errors+1)); \
		fi; \
	else \
		echo -e "$(YELLOW)⚠ Skipped$(RESET)"; \
	fi; \
	\
	echo -n "  Feature git_directory matches base ... "; \
	if [ -f "$$base" ] && [ -f "$$feat" ]; then \
		base_gd=$$(grep 'git_directory:' "$$base" | head -1 | sed 's/.*git_directory:\s*//; s/["\x27]//g; s/\s*#.*//; s/\s*$$//'); \
		feat_gd=$$(grep 'git_directory:' "$$feat" | head -1 | sed 's/.*git_directory:\s*//; s/["\x27]//g; s/\s*#.*//; s/\s*$$//'); \
		if [ "$$base_gd" = "$$feat_gd" ]; then \
			echo -e "$(GREEN)✓$(RESET) ($$base_gd)"; \
		else \
			echo -e "$(RED)✗ base=$$base_gd vs feature=$$feat_gd$(RESET)"; errors=$$((errors+1)); \
		fi; \
	else \
		echo -e "$(YELLOW)⚠ Skipped (file missing)$(RESET)"; \
	fi; \
	\
	echo -n "  No hardcoded GUIDs in principals ..... "; \
	if [ -f "$$base" ]; then \
		hc=$$(grep -E '^\s*-?\s*id:\s*"?[a-f0-9]{8}-[a-f0-9]{4}-' "$$base" 2>/dev/null | head -1); \
		if [ -z "$$hc" ]; then \
			echo -e "$(GREEN)✓$(RESET)"; \
		else \
			echo -e "$(YELLOW)⚠ Found hardcoded GUID — consider using \$${} env var$(RESET)"; \
		fi; \
	else \
		echo -e "$(YELLOW)⚠ Skipped$(RESET)"; \
	fi; \
	\
	echo ""; \
	if [ $$errors -eq 0 ]; then \
		echo -e "  $(GREEN)$(BOLD)All checks passed ✓$(RESET)"; \
	else \
		echo -e "  $(RED)$(BOLD)$$errors check(s) failed$(RESET)"; \
	fi; \
	echo ""

.PHONY: show-secrets
show-secrets: ## Show required GitHub secrets for a project (project=<name>)
	@if [ -z "$(project)" ]; then \
		echo ""; \
		printf "\033[31mERROR: Missing required parameter 'project'\033[0m\n"; \
		echo ""; \
		printf "\033[1mUsage:\033[0m\n"; \
		printf "  make show-secrets project=<project_slug>\n"; \
		echo ""; \
		printf "\033[1mExample:\033[0m\n"; \
		printf "  make show-secrets project=finance\n"; \
		echo ""; \
		exit 1; \
	fi
	@UPPER=$$(echo "$(project)" | tr '[:lower:]' '[:upper:]'); \
	echo ""; \
	echo -e "$(BOLD)GitHub Secrets Required for '$(project)'$(RESET)"; \
	echo ""; \
	echo -e "$(BOLD)Core secrets (shared across all projects):$(RESET)"; \
	echo -e "  AZURE_TENANT_ID                      — Entra ID tenant GUID"; \
	echo -e "  AZURE_CLIENT_ID                      — Service Principal app ID"; \
	echo -e "  AZURE_CLIENT_SECRET                  — Service Principal secret"; \
	echo -e "  FABRIC_GITHUB_TOKEN                  — GitHub PAT with repo scope"; \
	echo -e "  FABRIC_CAPACITY_ID                   — Dev Fabric capacity GUID"; \
	echo -e "  FABRIC_CAPACITY_ID_TEST              — Test capacity GUID"; \
	echo -e "  FABRIC_CAPACITY_ID_PROD              — Prod capacity GUID"; \
	echo -e "  ADDITIONAL_ADMIN_PRINCIPAL_ID         — IT governance admin group OID"; \
	echo -e "  ADDITIONAL_CONTRIBUTOR_PRINCIPAL_ID   — Governance contributor group OID"; \
	echo ""; \
	echo -e "$(BOLD)Project-specific secrets (for $(project)):$(RESET)"; \
	echo -e "  $(CYAN)$${UPPER}_ADMIN_ID$(RESET)     — Entra ID security group OID for project admins"; \
	echo -e "  $(CYAN)$${UPPER}_MEMBERS_ID$(RESET)   — Entra ID security group OID for project members"; \
	echo ""; \
	echo -e "$(BOLD)Where to configure:$(RESET)"; \
	echo -e "  GitHub → Settings → Secrets and variables → Actions → Secrets"; \
	echo ""; \
	echo -e "$(BOLD)Workflow env block addition (all 6 workflows):$(RESET)"; \
	echo -e "  $(DIM)$${UPPER}_ADMIN_ID: \$${{ secrets.$${UPPER}_ADMIN_ID }}$(RESET)"; \
	echo -e "  $(DIM)$${UPPER}_MEMBERS_ID: \$${{ secrets.$${UPPER}_MEMBERS_ID }}$(RESET)"; \
	echo ""

.PHONY: check-structure
check-structure: ## Verify repo structure is correct
	@echo ""
	@echo -e "$(BOLD)Checking repo structure$(RESET)"
	@echo ""
	@errors=0; \
	\
	echo -n "  .github/workflows/ exists ............ "; \
	if [ -d ".github/workflows" ]; then echo -e "$(GREEN)✓$(RESET)"; else echo -e "$(RED)✗$(RESET)"; errors=$$((errors+1)); fi; \
	\
	echo -n "  setup-base-workspaces.yml ............ "; \
	if [ -f ".github/workflows/setup-base-workspaces.yml" ]; then echo -e "$(GREEN)✓$(RESET)"; else echo -e "$(RED)✗$(RESET)"; errors=$$((errors+1)); fi; \
	\
	echo -n "  feature-workspace-create.yml ......... "; \
	if [ -f ".github/workflows/feature-workspace-create.yml" ]; then echo -e "$(GREEN)✓$(RESET)"; else echo -e "$(RED)✗$(RESET)"; errors=$$((errors+1)); fi; \
	\
	echo -n "  feature-workspace-cleanup.yml ........ "; \
	if [ -f ".github/workflows/feature-workspace-cleanup.yml" ]; then echo -e "$(GREEN)✓$(RESET)"; else echo -e "$(RED)✗$(RESET)"; errors=$$((errors+1)); fi; \
	\
	echo -n "  promote-dev-to-test.yml .............. "; \
	if [ -f ".github/workflows/promote-dev-to-test.yml" ]; then echo -e "$(GREEN)✓$(RESET)"; else echo -e "$(RED)✗$(RESET)"; errors=$$((errors+1)); fi; \
	\
	echo -n "  promote-test-to-prod.yml ............. "; \
	if [ -f ".github/workflows/promote-test-to-prod.yml" ]; then echo -e "$(GREEN)✓$(RESET)"; else echo -e "$(RED)✗$(RESET)"; errors=$$((errors+1)); fi; \
	\
	echo -n "  ci.yml ............................... "; \
	if [ -f ".github/workflows/ci.yml" ]; then echo -e "$(GREEN)✓$(RESET)"; else echo -e "$(RED)✗$(RESET)"; errors=$$((errors+1)); fi; \
	\
	echo -n "  config/projects/_templates/ .......... "; \
	if [ -d "config/projects/_templates" ]; then echo -e "$(GREEN)✓$(RESET)"; else echo -e "$(YELLOW)⚠ Missing (new projects cannot be scaffolded)$(RESET)"; fi; \
	\
	echo -n "  docs/ directory ...................... "; \
	if [ -d "docs" ]; then echo -e "$(GREEN)✓$(RESET)"; else echo -e "$(YELLOW)⚠ Missing$(RESET)"; fi; \
	\
	echo -n "  Makefile ............................. "; \
	if [ -f "Makefile" ]; then echo -e "$(GREEN)✓$(RESET)"; else echo -e "$(RED)✗$(RESET)"; errors=$$((errors+1)); fi; \
	\
	echo ""; \
	echo -e "  $(BOLD)Projects with Git sync directories:$(RESET)"; \
	found=0; \
	for dir in config/projects/*/; do \
		proj=$$(basename "$$dir"); \
		if [ "$$proj" = "_templates" ]; then continue; fi; \
		found=$$((found+1)); \
		if [ -d "$$proj" ]; then \
			echo -e "    $(GREEN)✓$(RESET) $$proj/ → config/projects/$$proj/"; \
		else \
			echo -e "    $(RED)✗$(RESET) $$proj/ missing (config exists at config/projects/$$proj/)"; \
			errors=$$((errors+1)); \
		fi; \
	done; \
	if [ $$found -eq 0 ]; then echo -e "    $(DIM)No projects configured yet$(RESET)"; fi; \
	echo ""; \
	if [ $$errors -eq 0 ]; then \
		echo -e "  $(GREEN)$(BOLD)Structure OK ✓$(RESET)"; \
	else \
		echo -e "  $(RED)$(BOLD)$$errors issue(s) found$(RESET)"; \
	fi; \
	echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# SCAFFOLD — Generate config template from a live Fabric workspace
# ═══════════════════════════════════════════════════════════════════════════════
#
# Connects to an existing Fabric workspace and introspects its folders, items,
# and principals to generate a base_workspace.yaml (and optionally feature YAML).
# The output lands in config/projects/_templates/<slug>/ — ready for use with:
#
#   make new-project project=<name> display="<Name>" template=<slug>
#
# Requires:
#   - fabric-cicd CLI installed (pip install usf-fabric-cli)
#   - Authentication: FABRIC_TOKEN or SP credentials (AZURE_CLIENT_ID, etc.)
#
# Parameters:
#   workspace  — (required) Name of the live Fabric workspace to scan
#   slug       — (optional) Template slug name (default: derived from workspace name)
#   feature    — (optional) Also generate feature_workspace.yaml (feature=true)
#   pipeline   — (optional) Also generate pipeline config (pipeline=true)
#
# Example:
#   make scaffold workspace="Sales" slug=sales_analytics feature=true pipeline="Sales Pipeline"
#
# ═══════════════════════════════════════════════════════════════════════════════

.PHONY: scaffold
scaffold: ## Generate config template from a live workspace (workspace="<Name>" [slug=<slug>] [feature=true] [pipeline="<Name>"])
	@if [ -z "$(workspace)" ]; then \
		echo ""; \
		echo -e "$(RED)ERROR: Missing required parameter 'workspace'$(RESET)"; \
		echo ""; \
		echo -e "$(BOLD)Usage:$(RESET)"; \
		echo -e "  make scaffold workspace=\"<Workspace Name>\" [slug=<template_slug>] [feature=true] [pipeline=\"<Name>\"]"; \
		echo ""; \
		echo -e "$(BOLD)Example:$(RESET)"; \
		echo -e "  make scaffold workspace=\"Sales\" slug=sales_analytics feature=true pipeline=\"Sales Pipeline\""; \
		echo ""; \
		echo -e "$(YELLOW)Note: Do not put spaces around the '=' sign (e.g., workspace= \"...\").$(RESET)"; \
		echo ""; \
		echo -e "$(BOLD)Parameters:$(RESET)"; \
		echo -e "  $(CYAN)workspace$(RESET)  Name of the live Fabric workspace to scan (required)"; \
		echo -e "  $(CYAN)slug$(RESET)       Template slug for the output directory (default: derived from workspace)"; \
		echo -e "  $(CYAN)feature$(RESET)    (Required for CI/CD flow) Set feature=true to also generate feature_workspace.yaml"; \
		echo -e "  $(CYAN)pipeline$(RESET)   (Required for Prod promotion) Pipeline name for deployment_pipeline section"; \
		echo ""; \
		echo -e "$(BOLD)Output:$(RESET)"; \
		echo -e "  config/projects/_templates/<slug>/base_workspace.yaml"; \
		echo ""; \
		echo -e "$(BOLD)Then use with:$(RESET)"; \
		echo -e "  make new-project project=<name> display=\"<Name>\" template=<slug>"; \
		echo ""; \
		exit 1; \
	fi
	@echo ""
	@echo -e "$(BOLD)Scaffolding from live workspace$(RESET)"
	@echo -e "  Workspace: $(CYAN)$(workspace)$(RESET)"
	@TEMPLATES_DIR="$(PROJECTS_DIR)/_templates"; \
	SLUG="$(slug)"; \
	CMD="fabric-cicd scaffold \"$(workspace)\""; \
	if [ -n "$$SLUG" ]; then \
		CMD="$$CMD --project-slug $$SLUG"; \
		echo -e "  Slug:      $(CYAN)$$SLUG$(RESET)"; \
	fi; \
	if [ "$(feature)" = "true" ]; then \
		CMD="$$CMD --include-feature-template"; \
		echo -e "  Feature:   $(GREEN)yes$(RESET)"; \
	fi; \
	if [ -n "$(pipeline)" ] && [ "$(pipeline)" != "false" ]; then \
		if [ "$(pipeline)" = "true" ]; then \
			echo -e "  $(YELLOW)WARNING: pipeline=true requires a pipeline name. Use pipeline=\"<Name>\"$(RESET)"; \
		else \
			CMD="$$CMD --pipeline-name \"$(pipeline)\""; \
			echo -e "  Pipeline:  $(GREEN)$(pipeline)$(RESET)"; \
		fi; \
	fi; \
	echo -e "  Output:    $(DIM)$$TEMPLATES_DIR/$(RESET)"; \
	echo ""; \
	echo -e "$(BOLD)Running command:$(RESET) $$CMD"; \
		eval $$CMD; \
	EXIT_CODE=$$?; \
	if [ $$EXIT_CODE -eq 0 ]; then \
		echo ""; \
		echo -e "$(GREEN)$(BOLD)Scaffold complete$(RESET)"; \
			echo -e "You can now use this template to scaffold new projects."; \
		echo ""; \
		if [ -n "$$SLUG" ]; then \
			SLUG_DIR="$$SLUG"; \
		else \
			SLUG_DIR=$$(ls -t "$$TEMPLATES_DIR" 2>/dev/null | grep -v standard_data_product | head -1); \
		fi; \
		echo -e "$(BOLD)Next steps:$(RESET)"; \
		echo -e "  1. Review the generated config:"; \
		echo -e "     $(DIM)cat $$TEMPLATES_DIR/$$SLUG_DIR/base_workspace.yaml$(RESET)"; \
		echo -e "  2. Create a project from this template:"; \
		echo -e "     $(DIM)make new-project project=<slug> display=\"<Name>\" template=$$SLUG_DIR$(RESET)"; \
		echo ""; \
	else \
		echo ""; \
		echo -e "$(RED)$(BOLD)Scaffold failed (exit code $$EXIT_CODE)$(RESET)"; \
			echo -e "$(DIM)Command that failed: $$CMD$(RESET)"; \
			echo -e "$(DIM)Check that fabric-cicd is installed and credentials are set in the .env file or environment variables.$(RESET)"; \
		echo ""; \
		exit $$EXIT_CODE; \
	fi

.PHONY: guide
guide: ## Open the step-by-step setup guide
	@if [ -f "docs/07_CONSUMER_REPO_SETUP_GUIDE.md" ]; then \
		echo ""; \
		echo -e "$(BOLD)Opening guide: docs/07_CONSUMER_REPO_SETUP_GUIDE.md$(RESET)"; \
		echo ""; \
		if command -v code &>/dev/null; then \
			code "docs/07_CONSUMER_REPO_SETUP_GUIDE.md"; \
		elif command -v less &>/dev/null; then \
			less "docs/07_CONSUMER_REPO_SETUP_GUIDE.md"; \
		else \
			cat "docs/07_CONSUMER_REPO_SETUP_GUIDE.md"; \
		fi; \
	else \
		echo -e "$(RED)Guide not found at docs/07_CONSUMER_REPO_SETUP_GUIDE.md$(RESET)"; \
	fi

# ═══════════════════════════════════════════════════════════════════════════════
# GIT WORKFLOW
# ═══════════════════════════════════════════════════════════════════════════════
#
# Commands that wrap common Git operations for the consumer repo lifecycle.
# These enforce naming conventions and provide helpful context.
#
# Feature branch convention (CRITICAL — workflows depend on this):
#   feature/<project>/<description>
#   e.g., feature/finance/add-silver-notebook
#
# The feature-workspace-create workflow parses the branch name to extract
# the project slug and find the correct config file. Wrong naming = failed workflow.
#
# ═══════════════════════════════════════════════════════════════════════════════

.PHONY: status
status: ## Show current branch, remote, and working tree status
	@echo ""
	@echo -e "$(BOLD)Git Status$(RESET)"
	@echo ""
	@BRANCH=$$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "(not a git repo)"); \
	echo -e "  Branch:  $(CYAN)$$BRANCH$(RESET)"; \
	REMOTE=$$(git remote get-url origin 2>/dev/null || echo "(no remote)"); \
	echo -e "  Remote:  $(DIM)$$REMOTE$(RESET)"; \
	COMMIT=$$(git log -1 --format='%h %s' 2>/dev/null || echo "(no commits)"); \
	echo -e "  Latest:  $(DIM)$$COMMIT$(RESET)"; \
	echo ""; \
	CHANGED=$$(git status --porcelain 2>/dev/null | wc -l | tr -d ' '); \
	STAGED=$$(git diff --cached --name-only 2>/dev/null | wc -l | tr -d ' '); \
	UNTRACKED=$$(git ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' '); \
	if [ "$$CHANGED" = "0" ]; then \
		echo -e "  $(GREEN)Working tree clean ✓$(RESET)"; \
	else \
		echo -e "  $(YELLOW)$$CHANGED file(s) changed$(RESET) ($$STAGED staged, $$UNTRACKED untracked)"; \
	fi; \
	echo ""; \
	if echo "$$BRANCH" | grep -qE '^feature/'; then \
		PROJ=$$(echo "$$BRANCH" | cut -d/ -f2); \
		DESC=$$(echo "$$BRANCH" | cut -d/ -f3-); \
		echo -e "  $(DIM)Feature branch detected:$(RESET)"; \
		echo -e "    Project: $(CYAN)$$PROJ$(RESET)"; \
		echo -e "    Name:    $(DIM)$$DESC$(RESET)"; \
		if [ -f "config/projects/$$PROJ/feature_workspace.yaml" ]; then \
			echo -e "    Config:  $(GREEN)✓ found$(RESET)"; \
		else \
			echo -e "    Config:  $(RED)✗ config/projects/$$PROJ/ not found$(RESET)"; \
		fi; \
		echo ""; \
	fi

.PHONY: feature
feature: ## Create a feature branch (project=<slug> name=<description>)
	@if [ -z "$(project)" ]; then \
		echo ""; \
		printf "$(RED)ERROR: Missing required parameter 'project'$(RESET)\n"; \
		echo ""; \
		printf "$(BOLD)Usage:$(RESET)\n"; \
		printf "  make feature project=<project_slug> name=\"<description>\"\n"; \
		echo ""; \
		printf "$(BOLD)Example:$(RESET)\n"; \
		printf "  make feature project=finance name=\"add new report\"\n"; \
		echo ""; \
		printf "$(YELLOW)Note: Do not put spaces around the '=' sign (e.g., param= \"...\").$(RESET)\n"; \
		echo ""; \
		printf "$(BOLD)Parameters:$(RESET)\n"; \
		printf "  $(CYAN)project$(RESET)   Project slug (lowercase + underscores, e.g., hr_analytics)\n"; \
		printf "  $(CYAN)name$(RESET)      Feature description (e.g., \"add-silver-notebook\")\n"; \
		echo ""; \
		exit 1; \
	fi
		echo -e "  $(DIM)→ Creates branch: feature/finance/add-silver-notebook$(RESET)"; \
		echo ""; \
		echo -e "$(BOLD)Why this convention?$(RESET)"; \
		echo -e "  The feature-workspace-create workflow parses the branch name to extract"; \
		echo -e "  the project slug and locate config/projects/<project>/feature_workspace.yaml."; \
		echo -e "  Incorrect naming → workflow cannot find the config → deployment fails."; \
		echo ""; \
		exit 1; \
	fi
	@if [ -z "$(name)" ]; then \
		echo ""; \
		printf "$(RED)ERROR: Missing required parameter 'name'$(RESET)\n"; \
		echo ""; \
		printf "$(BOLD)Usage:$(RESET)\n"; \
		printf "  make feature project=<project_slug> name=\"<description>\"\n"; \
		echo ""; \
		printf "$(BOLD)Example:$(RESET)\n"; \
		printf "  make feature project=finance name=\"add new report\"\n"; \
		echo ""; \
		printf "$(YELLOW)Note: Do not put spaces around the '=' sign (e.g., param= \"...\").$(RESET)\n"; \
		echo ""; \
		printf "$(BOLD)Parameters:$(RESET)\n"; \
		printf "  $(CYAN)project$(RESET)   Project slug (lowercase + underscores, e.g., hr_analytics)\n"; \
		printf "  $(CYAN)name$(RESET)      Feature description (e.g., \"add-silver-notebook\")\n"; \
		echo ""; \
		exit 1; \
	fi
	@# ── Validate project exists ──────────────────────────────────────────
	@if [ ! -d "$(PROJECTS_DIR)/$(project)" ]; then \
		echo ""; \
		echo -e "$(RED)ERROR: Project '$(project)' not found at $(PROJECTS_DIR)/$(project)/$(RESET)"; \
		echo -e "$(DIM)Available projects:$(RESET)"; \
		for dir in $(PROJECTS_DIR)/*/; do \
			p=$$(basename "$$dir"); \
			if [ "$$p" != "_templates" ]; then echo -e "  $(CYAN)$$p$(RESET)"; fi; \
		done; \
		echo ""; \
		exit 1; \
	fi
	@# ── Check for uncommitted changes ────────────────────────────────────
	@if [ -n "$$(git status --porcelain 2>/dev/null)" ]; then \
		echo ""; \
		echo -e "$(YELLOW)WARNING: You have uncommitted changes.$(RESET)"; \
		echo -e "$(DIM)They will carry over to the new branch.$(RESET)"; \
		echo ""; \
	fi
	@# ── Create the branch ────────────────────────────────────────────────
	@BRANCH="feature/$(project)/$(name)"; \
	echo ""; \
	echo -e "$(BOLD)$(CYAN)Creating feature branch$(RESET)"; \
	echo ""; \
	echo -e "  Branch:  $(CYAN)$$BRANCH$(RESET)"; \
	echo -e "  Project: $(project)"; \
	echo -e "  Config:  $(PROJECTS_DIR)/$(project)/feature_workspace.yaml"; \
	echo ""; \
	git checkout -b "$$BRANCH"; \
	echo ""; \
	echo -e "$(BOLD)Next steps:$(RESET)"; \
	echo -e "  1. Make your changes (add notebooks, pipelines, etc.)"; \
	echo -e "  2. Commit:  $(DIM)make commit msg=\"feat: <description>\"$(RESET)"; \
	echo -e "  3. Push:    $(DIM)make push$(RESET)"; \
	echo -e "              $(DIM)→ Feature workspace auto-created in Fabric$(RESET)"; \
	echo -e "  4. PR:      $(DIM)make pr title=\"feat: <description>\"$(RESET)"; \
	echo -e "              $(DIM)→ Merge destroys feature workspace + promotes to Test$(RESET)"; \
	echo ""

.PHONY: commit
commit: ## Stage all changes and commit (msg="<message>")
	@if [ -z "$(msg)" ]; then \
		echo ""; \
		printf "$(RED)ERROR: Missing required parameter 'msg'$(RESET)\n"; \
		echo ""; \
		printf "$(BOLD)Usage:$(RESET)\n"; \
		printf "  make commit msg=\"<commit message>\"\n"; \
		echo ""; \
		printf "$(BOLD)Example:$(RESET)\n"; \
		printf "  make commit msg=\"feat: added silver layer notebook\"\n"; \
		echo ""; \
		printf "$(YELLOW)Note: Do not put spaces around the '=' sign (e.g., param= \"...\").$(RESET)\n"; \
		echo ""; \
		printf "$(BOLD)Parameters:$(RESET)\n"; \
		printf "  $(CYAN)msg$(RESET)       Standard commit message (conventional commits preferred)\n"; \
		echo ""; \
		exit 1; \
	fi
		echo -e "  make commit msg=\"chore: onboard hr_analytics project\""; \
		echo -e "  make commit msg=\"docs: update deployment guide\""; \
		echo ""; \
		echo -e "$(BOLD)Convention:$(RESET) $(DIM)<type>: <description>$(RESET)"; \
		echo -e "  feat, fix, chore, docs, refactor, test, ci"; \
		echo ""; \
		exit 1; \
	fi
	@set -e; \
	CHANGED=$$(git status --porcelain 2>/dev/null | wc -l | tr -d ' '); \
	if [ "$$CHANGED" = "0" ]; then \
		echo ""; \
		echo -e "$(YELLOW)Nothing to commit — working tree is clean.$(RESET)"; \
		echo ""; \
		exit 0; \
	fi; \
	echo ""; \
	echo -e "$(BOLD)Committing changes$(RESET)"; \
	echo ""; \
	git add -A; \
	echo -e "  $(DIM)Staged files:$(RESET)"; \
	git diff --cached --name-status | head -20 | while IFS= read -r line; do \
		STATUS=$$(echo "$$line" | cut -f1); \
		FILE=$$(echo "$$line" | cut -f2-); \
		case $$STATUS in \
			A) echo -e "    $(GREEN)+$(RESET) $$FILE" ;; \
			M) echo -e "    $(YELLOW)~$(RESET) $$FILE" ;; \
			D) echo -e "    $(RED)-$(RESET) $$FILE" ;; \
			*) echo -e "    $(DIM)$$STATUS$(RESET) $$FILE" ;; \
		esac; \
	done; \
	TOTAL=$$(git diff --cached --name-only | wc -l | tr -d ' '); \
	if [ $$TOTAL -gt 20 ]; then echo -e "    $(DIM)... and $$((TOTAL-20)) more$(RESET)"; fi; \
	echo ""; \
	git commit -m "$(msg)"; \
	echo ""; \
	echo -e "  $(GREEN)✓ Committed$(RESET)"; \
	echo ""

.PHONY: commit-project
commit-project: ## Stage and commit a new/modified project (project=<name>)
	@if [ -z "$(project)" ]; then \
		echo ""; \
		printf "$(RED)ERROR: Missing required parameter 'project'$(RESET)\n"; \
		echo ""; \
		printf "$(BOLD)Usage:$(RESET)\n"; \
		printf "  make commit-project project=<slug> msg=\"<commit message>\"\n"; \
		echo ""; \
		printf "$(BOLD)Example:$(RESET)\n"; \
		printf "  make commit-project project=finance msg=\"feat: update pipeline\"\n"; \
		echo ""; \
		printf "$(YELLOW)Note: Do not put spaces around the '=' sign (e.g., param= \"...\").$(RESET)\n"; \
		echo ""; \
		printf "$(BOLD)Parameters:$(RESET)\n"; \
		printf "  $(CYAN)project$(RESET)   Project slug to limit commit scope\n"; \
		printf "  $(CYAN)msg$(RESET)       Standard commit message\n"; \
		echo ""; \
		exit 1; \
	fi
		exit 1; \
	fi
	@echo ""
	@echo -e "$(BOLD)Committing project: $(project)$(RESET)"
	@echo ""
	@set -e; \
	git add -A "$(PROJECTS_DIR)/$(project)/" "$(project)/" \
		".github/workflows/setup-base-workspaces.yml" 2>/dev/null || true; \
	STAGED=$$(git diff --cached --name-only 2>/dev/null | wc -l | tr -d ' '); \
	if [ "$$STAGED" = "0" ]; then \
		echo -e "  $(YELLOW)Nothing to commit for project '$(project)'.$(RESET)"; \
		echo -e "  $(DIM)Config, Git sync dir, and workflow are already committed.$(RESET)"; \
		echo ""; \
		exit 0; \
	fi; \
	echo -e "  $(DIM)Staged files:$(RESET)"; \
	git diff --cached --name-status | while IFS= read -r line; do \
		STATUS=$$(echo "$$line" | cut -f1); \
		FILE=$$(echo "$$line" | cut -f2-); \
		case $$STATUS in \
			A) echo -e "    $(GREEN)+$(RESET) $$FILE" ;; \
			M) echo -e "    $(YELLOW)~$(RESET) $$FILE" ;; \
			D) echo -e "    $(RED)-$(RESET) $$FILE" ;; \
			*) echo -e "    $(DIM)$$STATUS$(RESET) $$FILE" ;; \
		esac; \
	done; \
	echo ""; \
	git commit -m "feat: onboard $(project) project" \
		-m "" \
		-m "- Config: $(PROJECTS_DIR)/$(project)/" \
		-m "- Git Sync dir: $(project)/" \
		-m "- Workflow dropdown updated"; \
	echo ""; \
	echo -e "  $(GREEN)✓ Committed$(RESET)"; \
	echo -e "  $(DIM)Push with: make push$(RESET)"; \
	echo ""

.PHONY: push
push: ## Push current branch to remote (with tracking)
	@BRANCH=$$(git rev-parse --abbrev-ref HEAD 2>/dev/null); \
	REMOTE_URL=$$(git remote get-url origin 2>/dev/null); \
	echo ""; \
	echo -e "$(BOLD)Pushing to remote$(RESET)"; \
	echo ""; \
	echo -e "  Branch: $(CYAN)$$BRANCH$(RESET)"; \
	echo -e "  Remote: $(DIM)$$REMOTE_URL$(RESET)"; \
	echo ""; \
	if [ -z "$$REMOTE_URL" ]; then \
		echo -e "$(RED)ERROR: No remote 'origin' configured.$(RESET)"; \
		echo -e "$(DIM)Use 'make push-new remote=<url>' to add a remote and push.$(RESET)"; \
		exit 1; \
	fi; \
	git push -u origin "$$BRANCH"; \
	echo ""; \
	echo -e "  $(GREEN)✓ Pushed$(RESET)"; \
	if echo "$$BRANCH" | grep -qE '^feature/'; then \
		echo ""; \
		echo -e "  $(DIM)Feature branch pushed — the Create Feature Workspace workflow$(RESET)"; \
		echo -e "  $(DIM)should trigger automatically in GitHub Actions.$(RESET)"; \
		echo ""; \
		echo -e "  $(BOLD)When ready, create a PR:$(RESET)"; \
		echo -e "    $(DIM)make pr title=\"feat: <description>\"$(RESET)"; \
	fi; \
	echo ""

.PHONY: push-new
push-new: ## First push — add remote origin and push main (remote=<github_url>)
	@if [ -z "$(remote)" ]; then \
		echo ""; \
		printf "\033[31mERROR: Missing required parameter 'remote'\033[0m\n"; \
		echo ""; \
		printf "\033[1mUsage:\033[0m\n"; \
		printf "  make push-new remote=<github_url>\n"; \
		echo ""; \
		printf "\033[1mExample:\033[0m\n"; \
		printf "  make push-new remote=https://github.com/org/repo.git\n"; \
		echo ""; \
		exit 1; \
	fi
	@echo ""
	@echo -e "$(BOLD)Setting up remote and pushing$(RESET)"
	@echo ""
	@EXISTING=$$(git remote get-url origin 2>/dev/null); \
	if [ -n "$$EXISTING" ]; then \
		echo -e "$(YELLOW)WARNING: Remote 'origin' already set to: $$EXISTING$(RESET)"; \
		echo -e "$(DIM)Updating to: $(remote)$(RESET)"; \
		git remote set-url origin "$(remote)"; \
	else \
		git remote add origin "$(remote)"; \
	fi
	@echo -e "  Remote: $(DIM)$(remote)$(RESET)"
	@git push -u origin main
	@echo ""
	@echo -e "  $(GREEN)✓ Pushed main to origin$(RESET)"
	@echo ""
	@echo -e "$(BOLD)Next steps:$(RESET)"
	@echo -e "  1. Configure GitHub Secrets:  $(DIM)make show-secrets project=<name>$(RESET)"
	@echo -e "  2. Run Setup Base Workspaces workflow in GitHub Actions"
	@echo ""

.PHONY: pr
pr: ## Create a Pull Request to main (title="<title>" [body="<body>"])
	@if ! command -v gh &>/dev/null; then \
		echo ""; \
		echo -e "$(RED)ERROR: GitHub CLI (gh) is not installed.$(RESET)"; \
		echo ""; \
		echo -e "$(BOLD)Install it:$(RESET)"; \
		echo -e "  $(DIM)https://cli.github.com/$(RESET)"; \
		echo -e "  $(DIM)brew install gh   # macOS$(RESET)"; \
		echo -e "  $(DIM)sudo apt install gh   # Ubuntu/Debian$(RESET)"; \
		echo ""; \
		echo -e "$(BOLD)Or create the PR manually:$(RESET)"; \
		echo -e "  Go to GitHub → Pull requests → New pull request"; \
		echo ""; \
		exit 1; \
	fi
	@if [ -z "$(title)" ]; then \
		echo ""; \
		printf "$(RED)ERROR: Missing required parameter 'title'$(RESET)\n"; \
		echo ""; \
		printf "$(BOLD)Usage:$(RESET)\n"; \
		printf "  make pr title=\"<PR title>\"\n"; \
		echo ""; \
		printf "$(BOLD)Example:$(RESET)\n"; \
		printf "  make pr title=\"feat: Add finance reporting view\"\n"; \
		echo ""; \
		printf "$(YELLOW)Note: Do not put spaces around the '=' sign (e.g., param= \"...\").$(RESET)\n"; \
		echo ""; \
		printf "$(BOLD)Parameters:$(RESET)\n"; \
		printf "  $(CYAN)title$(RESET)     Pull request title\n"; \
		echo ""; \
		exit 1; \
	fi
		echo ""; \
		exit 1; \
	fi
	@BRANCH=$$(git rev-parse --abbrev-ref HEAD 2>/dev/null); \
	if [ "$$BRANCH" = "main" ]; then \
		echo ""; \
		echo -e "$(RED)ERROR: You are on the 'main' branch.$(RESET)"; \
		echo -e "$(DIM)Switch to a feature branch first: make feature project=<name> name=<desc>$(RESET)"; \
		echo ""; \
		exit 1; \
	fi
	@echo ""
	@echo -e "$(BOLD)Creating Pull Request$(RESET)"
	@echo ""
	@BRANCH=$$(git rev-parse --abbrev-ref HEAD); \
	echo -e "  Branch: $(CYAN)$$BRANCH$(RESET) → main"; \
	echo ""
	@if [ -n "$(body)" ]; then \
		gh pr create --base main --title "$(title)" --body "$(body)"; \
	else \
		gh pr create --base main --title "$(title)" --fill; \
	fi
	@echo ""
	@echo -e "  $(GREEN)✓ PR created$(RESET)"
	@echo ""
	@echo -e "  $(DIM)When the PR is merged:$(RESET)"
	@echo -e "    → Feature workspace is destroyed (cleanup workflow)$(RESET)"
	@echo -e "    → Dev workspace syncs from main (Git Sync)$(RESET)"
	@echo -e "    → Dev → Test promotion triggers automatically$(RESET)"
	@echo ""

.PHONY: log
log: ## Show recent commit history (compact)
	@echo ""
	@echo -e "$(BOLD)Recent Commits$(RESET)"
	@echo ""
	@git --no-pager log --oneline --graph --decorate -20 2>/dev/null || \
		echo -e "  $(DIM)No commits yet.$(RESET)"
	@echo ""

.PHONY: diff
diff: ## Show uncommitted changes
	@echo ""; \
	CHANGED=$$(git status --porcelain 2>/dev/null | wc -l | tr -d ' '); \
	if [ "$$CHANGED" = "0" ]; then \
		echo -e "  $(GREEN)Working tree clean — no changes.$(RESET)"; \
		echo ""; \
		exit 0; \
	fi; \
	echo -e "$(BOLD)Changed files:$(RESET)"; \
	echo ""; \
	git status --porcelain | while IFS= read -r line; do \
		STATUS=$$(echo "$$line" | cut -c1-2 | tr -d ' '); \
		FILE=$$(echo "$$line" | cut -c4-); \
		case $$STATUS in \
			M)  echo -e "  $(YELLOW)modified$(RESET)  $$FILE" ;; \
			A)  echo -e "  $(GREEN)added$(RESET)     $$FILE" ;; \
			D)  echo -e "  $(RED)deleted$(RESET)   $$FILE" ;; \
			??) echo -e "  $(DIM)untracked$(RESET) $$FILE" ;; \
			*)  echo -e "  $(DIM)$$STATUS$(RESET)       $$FILE" ;; \
		esac; \
	done; \
	echo ""; \
	echo -e "$(DIM)To see full diff: git diff$(RESET)"; \
	echo -e "$(DIM)To commit:        make commit msg=\"<message>\"$(RESET)"; \
	echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# INTERNAL TARGETS & FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

# ── Parameter validation ──────────────────────────────────────────────────────

.PHONY: _validate-new-repo-params
_validate-new-repo-params:
	@if [ -z "$(name)" ]; then \
		echo ""; \
		printf "$(RED)ERROR: Missing required parameter 'name'$(RESET)\n"; \
		echo ""; \
		printf "$(BOLD)Usage:$(RESET)\n"; \
		printf "  make new-repo name=<repo_name> project=<project_slug> display=\"<Display Name>\"\n"; \
		echo ""; \
		printf "$(BOLD)Example:$(RESET)\n"; \
		printf "  make new-repo name=acme-fabric-cicd project=finance display=\"Finance Reporting\"\n"; \
		echo ""; \
		printf "$(YELLOW)Note: Do not put spaces around the '=' sign (e.g., param= \"...\").$(RESET)\n"; \
		echo ""; \
		printf "$(BOLD)Parameters:$(RESET)\n"; \
		printf "  $(CYAN)name$(RESET)      Repository directory name (alphanumeric + hyphens)\n"; \
		printf "  $(CYAN)project$(RESET)   First project slug (lowercase + underscores, e.g., finance)\n"; \
		printf "  $(CYAN)display$(RESET)   Human-readable name used in workspace titles (e.g., \"Finance\")\n"; \
		echo ""; \
		exit 1; \
	fi
	@if [ -z "$(project)" ]; then \
		echo ""; \
		printf "$(RED)ERROR: Missing required parameter 'project'$(RESET)\n"; \
		echo ""; \
		printf "$(BOLD)Usage:$(RESET)\n"; \
		printf "  make new-repo name=<repo_name> project=<project_slug> display=\"<Display Name>\"\n"; \
		echo ""; \
		printf "$(BOLD)Example:$(RESET)\n"; \
		printf "  make new-repo name=acme-fabric-cicd project=finance display=\"Finance Reporting\"\n"; \
		echo ""; \
		printf "$(YELLOW)Note: Do not put spaces around the '=' sign (e.g., param= \"...\").$(RESET)\n"; \
		echo ""; \
		printf "$(BOLD)Parameters:$(RESET)\n"; \
		printf "  $(CYAN)name$(RESET)      Repository directory name (alphanumeric + hyphens)\n"; \
		printf "  $(CYAN)project$(RESET)   First project slug (lowercase + underscores, e.g., finance)\n"; \
		printf "  $(CYAN)display$(RESET)   Human-readable name used in workspace titles (e.g., \"Finance\")\n"; \
		echo ""; \
		exit 1; \
	fi
	@if [ -z "$(display)" ]; then \
		echo ""; \
		printf "$(RED)ERROR: Missing required parameter 'display'$(RESET)\n"; \
		echo ""; \
		printf "$(BOLD)Usage:$(RESET)\n"; \
		printf "  make new-repo name=<repo_name> project=<project_slug> display=\"<Display Name>\"\n"; \
		echo ""; \
		printf "$(BOLD)Example:$(RESET)\n"; \
		printf "  make new-repo name=acme-fabric-cicd project=finance display=\"Finance Reporting\"\n"; \
		echo ""; \
		printf "$(YELLOW)Note: Do not put spaces around the '=' sign (e.g., param= \"...\").$(RESET)\n"; \
		echo ""; \
		printf "$(BOLD)Parameters:$(RESET)\n"; \
		printf "  $(CYAN)name$(RESET)      Repository directory name (alphanumeric + hyphens)\n"; \
		printf "  $(CYAN)project$(RESET)   First project slug (lowercase + underscores, e.g., finance)\n"; \
		printf "  $(CYAN)display$(RESET)   Human-readable name used in workspace titles (e.g., \"Finance\")\n"; \
		echo ""; \
		exit 1; \
	fi

.PHONY: _validate-new-project-params
_validate-new-project-params:
	@if [ -z "$(project)" ]; then \
		echo ""; \
		printf "$(RED)ERROR: Missing required parameter 'project'$(RESET)\n"; \
		echo ""; \
		printf "$(BOLD)Usage:$(RESET)\n"; \
		printf "  make new-project project=<project_slug> display=\"<Display Name>\" [template=<name>]\n"; \
		echo ""; \
		printf "$(BOLD)Example:$(RESET)\n"; \
		printf "  make new-project project=hr_analytics display=\"HR Analytics\" template=my_scaffold\n"; \
		echo ""; \
		printf "$(YELLOW)Note: Do not put spaces around the '=' sign (e.g., param= \"...\").$(RESET)\n"; \
		echo ""; \
		printf "$(BOLD)Parameters:$(RESET)\n"; \
		printf "  $(CYAN)project$(RESET)   Project slug (lowercase + underscores, e.g., hr_analytics)\n            This becomes the config folder name AND the Git sync directory name.\n"; \
		printf "  $(CYAN)display$(RESET)   Human-readable name (e.g., \"HR Analytics\")\n            Used in workspace names like \"HR Analytics [DEV]\", pipeline names, etc.\n"; \
		printf "  $(CYAN)template$(RESET)  Optional. Template name from _templates/ (default: standard_data_product)\n"; \
		echo ""; \
		exit 1; \
	fi
	@if [ -z "$(display)" ]; then \
		echo ""; \
		printf "$(RED)ERROR: Missing required parameter 'display'$(RESET)\n"; \
		echo ""; \
		printf "$(BOLD)Usage:$(RESET)\n"; \
		printf "  make new-project project=<project_slug> display=\"<Display Name>\" [template=<name>]\n"; \
		echo ""; \
		printf "$(BOLD)Example:$(RESET)\n"; \
		printf "  make new-project project=hr_analytics display=\"HR Analytics\" template=my_scaffold\n"; \
		echo ""; \
		printf "$(YELLOW)Note: Do not put spaces around the '=' sign (e.g., param= \"...\").$(RESET)\n"; \
		echo ""; \
		printf "$(BOLD)Parameters:$(RESET)\n"; \
		printf "  $(CYAN)project$(RESET)   Project slug (lowercase + underscores, e.g., hr_analytics)\n            This becomes the config folder name AND the Git sync directory name.\n"; \
		printf "  $(CYAN)display$(RESET)   Human-readable name (e.g., \"HR Analytics\")\n            Used in workspace names like \"HR Analytics [DEV]\", pipeline names, etc.\n"; \
		printf "  $(CYAN)template$(RESET)  Optional. Template name from _templates/ (default: standard_data_product)\n"; \
		echo ""; \
		exit 1; \
	fi

# ── Shared function: Replace CHANGE-ME placeholders ──────────────────────────
# Args: $(1) = repo root path, $(2) = project slug, $(3) = display name
define replace-placeholders
	@REPO_ROOT="$(1)"; \
	PROJECT="$(2)"; \
	DISPLAY="$(3)"; \
	UPPER=$$(echo "$$PROJECT" | tr '[:lower:]' '[:upper:]'); \
	DISPLAY_ESC=$$(printf '%s\n' "$$DISPLAY" | sed 's/[&/|\\]/\\&/g'); \
	BASE="$$REPO_ROOT/$(PROJECTS_DIR)/$$PROJECT/base_workspace.yaml"; \
	FEAT="$$REPO_ROOT/$(PROJECTS_DIR)/$$PROJECT/feature_workspace.yaml"; \
	\
	if [ -f "$$BASE" ]; then \
		sed -i "s|CHANGE-ME \[DEV\]|$$DISPLAY_ESC [DEV]|g" "$$BASE"; \
		sed -i "s|CHANGE-ME \[TEST\]|$$DISPLAY_ESC [TEST]|g" "$$BASE"; \
		sed -i "s|CHANGE-ME \[PROD\]|$$DISPLAY_ESC [PROD]|g" "$$BASE"; \
		sed -i "s|CHANGE-ME - Pipeline|$$DISPLAY_ESC - Pipeline|g" "$$BASE"; \
		sed -i "s|/CHANGE-ME|/$$PROJECT|g" "$$BASE"; \
		sed -i "s|CHANGEME_ADMIN_ID|$${UPPER}_ADMIN_ID|g" "$$BASE"; \
		sed -i "s|CHANGEME_MEMBERS_ID|$${UPPER}_MEMBERS_ID|g" "$$BASE"; \
		echo -e "         $(DIM)✓ base_workspace.yaml — all placeholders replaced$(RESET)"; \
	fi; \
	\
	if [ -f "$$FEAT" ]; then \
		sed -i "s|/CHANGE-ME|/$$PROJECT|g" "$$FEAT"; \
		sed -i "s|CHANGEME_ADMIN_ID|$${UPPER}_ADMIN_ID|g" "$$FEAT"; \
		sed -i "s|CHANGEME_MEMBERS_ID|$${UPPER}_MEMBERS_ID|g" "$$FEAT"; \
		echo -e "         $(DIM)✓ feature_workspace.yaml — all placeholders replaced$(RESET)"; \
	fi
endef

# ── Shared function: Update workflow project dropdown ─────────────────────────
# Adds the project to the `options:` list in setup-base-workspaces.yml
# Args: $(1) = repo root path, $(2) = project slug
define update-workflow-dropdown
	@REPO_ROOT="$(1)"; \
	PROJECT="$(2)"; \
	UPDATED=0; \
	for WF in setup-base-workspaces.yml promote-dev-to-test.yml promote-test-to-prod.yml feature-workspace-create.yml; do \
		WORKFLOW="$$REPO_ROOT/.github/workflows/$$WF"; \
		if [ -f "$$WORKFLOW" ]; then \
			if grep -q "          - $$PROJECT" "$$WORKFLOW"; then \
				: ; \
			else \
				sed -i "/# ➕ Add new projects here/i\\          - $$PROJECT" "$$WORKFLOW"; \
				UPDATED=$$((UPDATED + 1)); \
			fi; \
		fi; \
	done; \
	if [ $$UPDATED -gt 0 ]; then \
		echo -e "         $(DIM)✓ Added '$$PROJECT' to $$UPDATED workflow dropdown(s)$(RESET)"; \
	else \
		echo -e "         $(DIM)✓ '$$PROJECT' already in all workflow dropdowns$(RESET)"; \
	fi
endef
