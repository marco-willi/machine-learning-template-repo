---
name: setup-ml-repo
description: >-
  Set up a new ML repository from the machine-learning-template-repo by asking the user
  step-by-step questions and applying the appropriate file structure, dependencies, and
  devcontainer. Invoke when the user asks to initialize, set up, or configure a new ML
  project repo from the template. Trigger on phrases like "set up the repo", "initialize
  the project", "configure from template", or "set up a new ML project".
---

# Setup ML Repo Skill

> **Invoke when:** User asks to set up or initialize a new ML project from the template repo.

You will ask the user **5 questions one at a time**, wait for each answer, then apply all changes at the end.

The template repo is at: https://github.com/marco-willi/machine-learning-template-repo

---

## Step-by-step questions

### Q1 — Project identity

Ask:
> What is the **project name** (used for the Python package, e.g. `sat_change`) and a short **description**?

Collect: `project_name` (snake_case), `project_description` (free text).

---

### Q2 — Dependency profile

Ask:
> Which **dependency profile** fits this project?
> - **minimal** — data analysis, exploration, no deep learning (pandas, numpy, seaborn, hydra, jupyter)
> - **full ML** — model training, deep learning (adds torch, lightning, transformers, wandb, DVC, etc.)

Collect: `profile` = `minimal` | `full_ml`

---

### Q3 — Package manager

Ask:
> Which **package manager** do you want to use?
> - **setuptools** — standard `pyproject.toml` with pip
> - **poetry** — `pyproject.toml` with Poetry *(only available for full ML profile)*

If user chose `minimal` in Q2, skip this question and default to `setuptools`.

Collect: `pkg_manager` = `setuptools` | `poetry`

---

### Q4 — Dev container

Ask:
> Which **dev container** setup do you need?
> - **CPU** — standard Python 3.14 image (fast to build, no GPU)
> - **GPU** — custom Dockerfile with NVIDIA support, ports for JupyterLab and TensorBoard

Collect: `devcontainer` = `cpu` | `gpu`

---

### Q5 — Compute target

Ask:
> Where will training / heavy compute run?
> - **local** — nothing extra needed
> - **Lambda Labs** — GPU cloud; helper scripts will be copied to `scripts/lambda/`
> - **GCP** — Google Cloud; helper scripts will be copied to `scripts/gcp/`
> - **SLURM** — HPC cluster; `scripts/slurm.sh` will be kept

Collect: `compute` = `local` | `lambda` | `gcp` | `slurm`

---

## File operations

Apply all changes after collecting all answers. Work from the repo root.

### 1. Rename the Python package

```
src/my_project/  →  src/<project_name>/
```

Update all occurrences of `my_project` → `<project_name>` in:
- `pyproject.toml` (name field and package discovery)
- `src/<project_name>/__init__.py`

---

### 2. Activate the correct `pyproject.toml`

| profile | pkg_manager | Action |
|---------|-------------|--------|
| minimal | setuptools | Keep existing `pyproject.toml` as-is |
| full_ml | setuptools | `cp pyproject.toml.gpu pyproject.toml` |
| full_ml | poetry | `cp pyproject.toml.poetry pyproject.toml` |

Then update `pyproject.toml`:
- Set `name` = `<project_name>`
- Set `description` = `<project_description>`

Delete all `pyproject.toml.*` variants (`.gpu`, `.minimal`, `.poetry`).

---

### 3. Activate the correct `.devcontainer`

| devcontainer | Action |
|---|---|
| cpu | Keep `.devcontainer/` as-is (already the minimal/CPU config) |
| gpu | Overwrite `.devcontainer/` with contents of `.devcontainer.gpu/` |

Delete all variant folders: `.devcontainer.gpu/`, `.devcontainer.minimal/`, `.devcontainer.poetry/`

Also update `devcontainer.json` → set `"name"` to the project name.

---

### 4. Handle compute scripts

**Always:** delete `examples/` entirely.

| compute | Action |
|---------|--------|
| local | Delete `scripts/slurm.sh` |
| lambda | Copy `examples/sat-change/scripts/lambda/` → `scripts/lambda/` before deleting `examples/`. Delete `scripts/slurm.sh`. |
| gcp | Copy `examples/sat-change/scripts/gcp/` → `scripts/gcp/` before deleting `examples/`. Delete `scripts/slurm.sh`. |
| slurm | Keep `scripts/slurm.sh`. Delete `examples/`. |

---

### 5. Final cleanup

- Update `README.md`: replace the boilerplate title and description with the project name and description.
- Verify `config/`, `data/`, and `logs/` directories have `.gitkeep` files so they are tracked by git.

---

## After applying changes

Show the user a summary:

```
Project set up:
  Name:         <project_name>
  Description:  <project_description>
  Dependencies: <profile> / <pkg_manager>
  Dev container: <devcontainer>
  Compute:       <compute>

Files changed:
  - src/my_project/ → src/<project_name>/
  - pyproject.toml  ← pyproject.toml.<variant>
  - .devcontainer/  ← .devcontainer.<variant>/
  - Removed: pyproject.toml.*, .devcontainer.gpu/, .devcontainer.minimal/, .devcontainer.poetry/, examples/

Next steps:
  1. Review pyproject.toml dependencies and trim any you don't need.
  2. Run: pip install -e ".[dev]"  (or: poetry install)
  3. Run: pre-commit install
```
