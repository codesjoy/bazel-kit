QUALITY_GO_DEFAULT_ENABLED_TOOLS = [
    "gofumpt",
    "goimports",
    "golines",
    "golangci-lint",
]

QUALITY_GO_TOOL_DEFINITIONS = {
    "gofumpt": {
        "kind": "go_source",
        "repo": "quality_tool_gofumpt",
        "binary_name": "gofumpt",
        "default_version": "v0.9.2",
        "versions": {
            "v0.9.2": {
                "url": "https://github.com/mvdan/gofumpt/archive/refs/tags/v0.9.2.tar.gz",
                "sha256": "acff9518cf4ad3550ca910b9254fc8a706494d6a105fe2e92948fedc52a42a5b",
                "strip_prefix": "gofumpt-0.9.2",
                "build_package": ".",
            },
        },
    },
    "goimports": {
        "kind": "go_source",
        "repo": "quality_tool_goimports",
        "binary_name": "goimports",
        "default_version": "v0.43.0",
        "versions": {
            "v0.43.0": {
                "url": "https://github.com/golang/tools/archive/refs/tags/v0.43.0.tar.gz",
                "sha256": "e35710736fcaeeb4fd9cd0279af97270af119a7dd7e9877c00608799c799de77",
                "strip_prefix": "tools-0.43.0",
                "build_package": "./cmd/goimports",
            },
        },
    },
    "golines": {
        "kind": "go_source",
        "repo": "quality_tool_golines",
        "binary_name": "golines",
        "default_version": "v0.13.0",
        "versions": {
            "v0.13.0": {
                "url": "https://github.com/segmentio/golines/archive/refs/tags/v0.13.0.tar.gz",
                "sha256": "ec1933e0fb73cf0517fd007d325603007aa65ce430267a70fc78cfea43d9716e",
                "strip_prefix": "golines-0.13.0",
                "build_package": ".",
            },
        },
    },
    "golangci-lint": {
        "kind": "archive_binary",
        "repo": "quality_tool_golangci_lint",
        "binary_name": "golangci-lint",
        "default_version": "v2.11.4",
        "versions": {
            "v2.11.4": {
                "darwin_amd64": {
                    "url": "https://github.com/golangci/golangci-lint/releases/download/v2.11.4/golangci-lint-2.11.4-darwin-amd64.tar.gz",
                    "sha256": "c900d4048db75d1edfd550fd11cf6a9b3008e7caa8e119fcddbc700412d63e60",
                    "strip_prefix": "golangci-lint-2.11.4-darwin-amd64",
                    "binary_path": "golangci-lint",
                },
                "darwin_arm64": {
                    "url": "https://github.com/golangci/golangci-lint/releases/download/v2.11.4/golangci-lint-2.11.4-darwin-arm64.tar.gz",
                    "sha256": "02db2a2dae8b26812e53b0688a6f617e3ef1f489790e829ea22862cf76945675",
                    "strip_prefix": "golangci-lint-2.11.4-darwin-arm64",
                    "binary_path": "golangci-lint",
                },
                "linux_amd64": {
                    "url": "https://github.com/golangci/golangci-lint/releases/download/v2.11.4/golangci-lint-2.11.4-linux-amd64.tar.gz",
                    "sha256": "200c5b7503f67b59a6743ccf32133026c174e272b930ee79aa2aa6f37aca7ef1",
                    "strip_prefix": "golangci-lint-2.11.4-linux-amd64",
                    "binary_path": "golangci-lint",
                },
                "linux_arm64": {
                    "url": "https://github.com/golangci/golangci-lint/releases/download/v2.11.4/golangci-lint-2.11.4-linux-arm64.tar.gz",
                    "sha256": "3bcfa2e6f3d32b2bf5cd75eaa876447507025e0303698633f722a05331988db4",
                    "strip_prefix": "golangci-lint-2.11.4-linux-arm64",
                    "binary_path": "golangci-lint",
                },
                "windows_amd64": {
                    "url": "https://github.com/golangci/golangci-lint/releases/download/v2.11.4/golangci-lint-2.11.4-windows-amd64.zip",
                    "sha256": "4932cfca5e75bf60fe1c576edf459e5e809e6644664a068185d64b84af3fad9e",
                    "strip_prefix": "golangci-lint-2.11.4-windows-amd64",
                    "binary_path": "golangci-lint.exe",
                },
            },
        },
    },
}

def quality_go_repo_name(tool):
    return QUALITY_GO_TOOL_DEFINITIONS[tool]["repo"]

def quality_go_default_version(tool):
    return QUALITY_GO_TOOL_DEFINITIONS[tool]["default_version"]
