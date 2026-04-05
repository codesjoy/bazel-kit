# changelog

`changelog` wraps `git-chglog` behind Bazel launchers while keeping the repo-owned `.chglog/` state and template contract.

## Bzlmod Setup

```starlark
changelog_tools = use_extension("@codesjoy_bazel_kit//rules/changelog:extensions.bzl", "changelog_tools")
changelog_tools.install()

use_repo(
    changelog_tools,
    "changelog_tool_git_chglog",
)
```

## Public API

```starlark
load("@codesjoy_bazel_kit//rules/changelog:defs.bzl", "changelog_generate", "changelog_init", "changelog_preview", "changelog_state_print", "changelog_state_reset", "changelog_verify")
```

- `changelog_init`
- `changelog_generate`
- `changelog_preview`
- `changelog_verify`
- `changelog_state_print`
- `changelog_state_reset`

Config attrs map directly to the `CHANGELOG_*` contract used by the launcher helper: changelog file, config/template paths, explicit range/query selection, profile/cadence toggles, state file, archive directory, and strict-state behavior.

The launcher executes a repo-owned cross-platform helper against `BUILD_WORKSPACE_DIRECTORY`.

## Example

See [`examples/changelog`](../examples/changelog).
