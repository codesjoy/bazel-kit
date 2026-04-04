MODELGEN_PKG_SOURCE = {
    "default_commit": "9bfa697c14eeb20cfd5b7193e459525459e08406",
    "url": "https://codeload.github.com/codesjoy/pkg/tar.gz/9bfa697c14eeb20cfd5b7193e459525459e08406",
    "sha256": "f0e0ce906fc04f2ae8263d5e6caefb7bb58f46600d91426be87163ae4132f01c",
    "strip_prefix": "pkg-9bfa697c14eeb20cfd5b7193e459525459e08406",
}

MODELGEN_TOOL = {
    "repo": "modelgen_tool_codesjoy_modelgen",
    "binary_name": "codesjoy-modelgen",
    "subdir": "tools/codesjoy-modelgen",
}

def modelgen_repo_name():
    return MODELGEN_TOOL["repo"]

def modelgen_default_commit():
    return MODELGEN_PKG_SOURCE["default_commit"]
