# Commit Pre-Check
This repository makes use of [pre-commit](https://pre-commit.com) to guard against accidental secret commits. When you attempt a commit, Pre-Commit will check for secrets and block the commit if one is found. It is currently using [GitGuardian](https://dashboard.gitguardian.com) [ggshield](https://www.gitguardian.com/ggshield) for secret validation. Requires a GitGuardian account, which does offer a free tier for home use.

## Requirements
Requires installation of the following programs:
* ggshield
* pre-commit

In my case, this is handled by [NixOS](https://github.com/kenlasko/nixos). Otherwise, install via:
```bash
sudo apt install python3-venv -y
pip install pre-commit
pip install pipx
pipx install ggshield
```

## Configuration
1. Create a file called `.pre-commit-config.yaml` and place in the root of your repository
2. Populate the file according to your desired platform (ggshield shown):
```yaml
repos:
  - repo: https://github.com/GitGuardian/ggshield
    rev: v1.37.0
    hooks:
      - id: ggshield
```
3. Run the following command:
```bash
pre-commit install
```
4. For ggshield, login to your GitGuardian account. Only required once.
```bash
# Local or WSL machine
ggshield auth login

# Remote SSH session
ggshield auth login --method token
```

## Handy Commands
Scan a repository before onboarding:
```bash
ggshield secret scan path <PathName> --recursive --use-gitignore
```