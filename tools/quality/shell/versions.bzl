QUALITY_SHELL_DEFAULT_ENABLED_TOOLS = [
    "shfmt",
]

QUALITY_SHELL_TOOL_DEFINITIONS = {
    "shfmt": {
        "kind": "direct_binary",
        "repo": "quality_tool_shfmt",
        "binary_name": "shfmt",
        "default_version": "v3.13.0",
        "versions": {
            "v3.13.0": {
                "darwin_amd64": {
                    "url": "https://github.com/mvdan/sh/releases/download/v3.13.0/shfmt_v3.13.0_darwin_amd64",
                    "sha256": "b6890a0009abf71d36d7c536ad56e3132c547ceb77cd5d5ee62b3469ab4e9417",
                },
                "darwin_arm64": {
                    "url": "https://github.com/mvdan/sh/releases/download/v3.13.0/shfmt_v3.13.0_darwin_arm64",
                    "sha256": "650970603b5946dc6041836ddcfa7a19d99b5da885e4687f64575508e99cf718",
                },
                "linux_amd64": {
                    "url": "https://github.com/mvdan/sh/releases/download/v3.13.0/shfmt_v3.13.0_linux_amd64",
                    "sha256": "70aa99784703a8d6569bbf0b1e43e1a91906a4166bf1a79de42050a6d0de7551",
                },
                "linux_arm64": {
                    "url": "https://github.com/mvdan/sh/releases/download/v3.13.0/shfmt_v3.13.0_linux_arm64",
                    "sha256": "2091a31afd47742051a77bf7cfd175533ab07e924c20ef3151cd108fa1cab5b0",
                },
                "windows_amd64": {
                    "url": "https://github.com/mvdan/sh/releases/download/v3.13.0/shfmt_v3.13.0_windows_amd64.exe",
                    "sha256": "62241aaf6b0ca236f8625d8892784b73fa67ad40bc677a1ad1a64ae395f6a7d5",
                },
            },
        },
    },
    "shellcheck": {
        "kind": "archive_binary",
        "repo": "quality_tool_shellcheck",
        "binary_name": "shellcheck",
        "default_version": "v0.11.0",
        "versions": {
            "v0.11.0": {
                "darwin_amd64": {
                    "url": "https://github.com/koalaman/shellcheck/releases/download/v0.11.0/shellcheck-v0.11.0.darwin.x86_64.tar.gz",
                    "sha256": "c2c15e08df0e8fbc374c335b230a7ee958c313fa5714817a59aa59f1aa594f51",
                    "strip_prefix": "shellcheck-v0.11.0",
                    "binary_path": "shellcheck",
                },
                "darwin_arm64": {
                    "url": "https://github.com/koalaman/shellcheck/releases/download/v0.11.0/shellcheck-v0.11.0.darwin.aarch64.tar.gz",
                    "sha256": "339b930feb1ea764467013cc1f72d09cd6b869ebf1013296ba9055ab2ffbd26f",
                    "strip_prefix": "shellcheck-v0.11.0",
                    "binary_path": "shellcheck",
                },
                "linux_amd64": {
                    "url": "https://github.com/koalaman/shellcheck/releases/download/v0.11.0/shellcheck-v0.11.0.linux.x86_64.tar.gz",
                    "sha256": "b7af85e41cc99489dcc21d66c6d5f3685138f06d34651e6d34b42ec6d54fe6f6",
                    "strip_prefix": "shellcheck-v0.11.0",
                    "binary_path": "shellcheck",
                },
                "linux_arm64": {
                    "url": "https://github.com/koalaman/shellcheck/releases/download/v0.11.0/shellcheck-v0.11.0.linux.aarch64.tar.gz",
                    "sha256": "68a8133197a50beb8803f8d42f9908d1af1c5540d4bb05fdfca8c1fa47decefc",
                    "strip_prefix": "shellcheck-v0.11.0",
                    "binary_path": "shellcheck",
                },
                "windows_amd64": {
                    "url": "https://github.com/koalaman/shellcheck/releases/download/v0.11.0/shellcheck-v0.11.0.zip",
                    "sha256": "8a4e35ab0b331c85d73567b12f2a444df187f483e5079ceffa6bda1faa2e740e",
                    "strip_prefix": "shellcheck-v0.11.0",
                    "binary_path": "shellcheck.exe",
                },
            },
        },
    },
}

def quality_shell_repo_name(tool):
    return QUALITY_SHELL_TOOL_DEFINITIONS[tool]["repo"]

def quality_shell_default_version(tool):
    return QUALITY_SHELL_TOOL_DEFINITIONS[tool]["default_version"]
