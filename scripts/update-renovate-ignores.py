#!/usr/bin/env python3
"""Sync Renovate ignore annotations from Kubernetes manifests into renovate.json.

Renovate cannot read comments in files parsed by its built-in managers
(kubernetes, helm-values, kustomize), so this script provides that workflow:
annotate the pinned version directly in the manifest and run this script
(automatically via pre-commit) to regenerate a managed package rule in
renovate.json that disables updates for those images.

Supported annotations:

  helm-values (baseline chart values.yaml):
      image:
        repository: 11notes/radarr
        tag: 6.2.0            # renovate: ignore
        registry: ghcr.io

  kubernetes manifest:
      image: ghcr.io/foo/bar:v1.2.3   # renovate: ignore

  kustomize image override:
      images:
        - name: ghcr.io/foo/bar
          newTag: v1.2.3      # renovate: ignore

  explicit dependency name (works anywhere in any YAML file):
      # renovate: ignore=ghcr.io/foo/bar

The generated rule is appended to packageRules with a fixed description and is
fully owned by this script: do not edit it by hand. Removing the annotation
from the manifest and re-running the script removes the dependency from the
rule again.
"""

import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
RENOVATE_JSON = REPO_ROOT / "renovate.json"
SCAN_DIRS = ["manifests", "argocd", "argocd-appsets", "helm"]
SKIP_DIRS = {"archive"}

MARKER_RE = re.compile(r"#\s*renovate:\s*ignore(?:=(?P<dep>\S+))?\s*$", re.IGNORECASE)
RULE_DESCRIPTION = (
    "Managed by scripts/update-renovate-ignores.py - do not edit. "
    "Add or remove '# renovate: ignore' annotations in manifests instead."
)


def strip_value(raw):
    """Return a YAML scalar value without quotes or trailing comment."""
    value = raw.split("#", 1)[0].strip()
    return value.strip("'\"")


def indent_of(line):
    stripped = line.lstrip(" ")
    return len(line) - len(stripped)


def image_ref_to_dep(ref):
    """Strip the tag/digest from an image reference, keeping the registry."""
    ref = ref.split("@", 1)[0]
    head, sep, tail = ref.rpartition(":")
    if sep and "/" not in tail:
        ref = head
    return ref


def sibling_values(lines, index, keys):
    """Collect values of sibling keys in the same YAML block as lines[index].

    Walks up and down from the annotated line while indentation stays at the
    same level (allowing for a '- ' list-item marker on the first line of a
    block), stopping when the block ends.
    """
    base_indent = indent_of(lines[index])
    found = {}

    def inspect(line, first_of_item=False):
        content = line.lstrip(" ")
        if first_of_item and content.startswith("- "):
            content = content[2:]
        for key in keys:
            match = re.match(rf"{key}\s*:\s*(.+)$", content)
            if match:
                found.setdefault(key, strip_value(match.group(1)))

    # Walk upward until the block's indentation decreases.
    for i in range(index - 1, -1, -1):
        line = lines[i]
        if not line.strip():
            break
        indent = indent_of(line)
        list_item = line.lstrip(" ").startswith("- ") and indent == base_indent - 2
        if indent < base_indent and not list_item:
            break
        if indent == base_indent or list_item:
            inspect(line, first_of_item=list_item)
        if list_item:
            break
    # Walk downward.
    for i in range(index + 1, len(lines)):
        line = lines[i]
        if not line.strip():
            break
        indent = indent_of(line)
        if indent < base_indent or line.lstrip(" ").startswith("- "):
            break
        if indent == base_indent:
            inspect(line)
    return found


def deps_from_line(lines, index, path):
    """Determine the Renovate dependency name(s) for an annotated line."""
    line = lines[index]
    marker = MARKER_RE.search(line)
    if marker.group("dep"):
        return {marker.group("dep")}

    code = line[: marker.start()].strip()

    match = re.match(r"(?:-\s+)?image\s*:\s*(\S+)", code)
    if match:
        return {image_ref_to_dep(strip_value(match.group(1)))}

    match = re.match(r"newTag\s*:", code)
    if match:
        siblings = sibling_values(lines, index, ["newName", "name"])
        name = siblings.get("newName") or siblings.get("name")
        if name:
            return {image_ref_to_dep(name)}

    match = re.match(r"(?:tag|version)\s*:", code)
    if match:
        siblings = sibling_values(lines, index, ["repository", "registry"])
        repository = siblings.get("repository")
        if repository:
            deps = {repository}
            registry = siblings.get("registry")
            if registry and not repository.startswith(registry):
                deps.add(f"{registry}/{repository}")
            return deps

    print(
        f"WARNING: {path}:{index + 1}: could not determine the image for this "
        "'# renovate: ignore' annotation. Use the explicit form "
        "'# renovate: ignore=<image>' instead.",
        file=sys.stderr,
    )
    return set()


def collect_ignored_deps():
    deps = set()
    problems = False
    for scan_dir in SCAN_DIRS:
        base = REPO_ROOT / scan_dir
        if not base.is_dir():
            continue
        for path in sorted(base.rglob("*.y*ml")):
            if SKIP_DIRS.intersection(part.lower() for part in path.parts):
                continue
            lines = path.read_text(encoding="utf-8").splitlines()
            for index, line in enumerate(lines):
                if not MARKER_RE.search(line):
                    continue
                found = deps_from_line(lines, index, path.relative_to(REPO_ROOT))
                if found:
                    print(f"  {path.relative_to(REPO_ROOT)}:{index + 1} -> {', '.join(sorted(found))}")
                    deps.update(found)
                else:
                    problems = True
    return deps, problems


def sync_renovate_config(deps):
    """Replace the managed rule in renovate.json. Returns True if it changed."""
    config = json.loads(RENOVATE_JSON.read_text(encoding="utf-8"))
    rules = config.setdefault("packageRules", [])
    managed = [rule for rule in rules if rule.get("description") == RULE_DESCRIPTION]
    others = [rule for rule in rules if rule.get("description") != RULE_DESCRIPTION]

    new_rule = None
    if deps:
        new_rule = {
            "description": RULE_DESCRIPTION,
            "matchPackageNames": sorted(deps),
            "enabled": False,
        }

    if managed == ([new_rule] if new_rule else []):
        return False

    # The managed rule goes last so it takes precedence over earlier rules.
    config["packageRules"] = others + ([new_rule] if new_rule else [])
    if not config["packageRules"]:
        del config["packageRules"]
    RENOVATE_JSON.write_text(json.dumps(config, indent=2) + "\n", encoding="utf-8")
    return True


def main():
    print("Scanning for '# renovate: ignore' annotations...")
    deps, problems = collect_ignored_deps()
    if not deps:
        print("  none found")
    changed = sync_renovate_config(deps)
    if changed:
        print(f"renovate.json updated ({len(deps)} ignored package(s)).")
    else:
        print("renovate.json already up to date.")
    # pre-commit fails the hook on its own when renovate.json is modified,
    # so a change does not need a non-zero exit here.
    if problems:
        sys.exit(1)


if __name__ == "__main__":
    main()
