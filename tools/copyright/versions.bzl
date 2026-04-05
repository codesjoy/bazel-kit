COPYRIGHT_TOOL = {
    "repo": "copyright_tool_addlicense",
    "binary_name": "addlicense",
    "default_version": "v1.2.0",
    "versions": {
        "v1.2.0": {
            "url": "https://github.com/google/addlicense/archive/refs/tags/v1.2.0.tar.gz",
            "sha256": "d2e05668e6f3da9b119931c2fdadfa6dd19a8fc441218eb3f2aec4aa24ae3f90",
            "strip_prefix": "addlicense-1.2.0",
            "build_package": ".",
        },
    },
}

def copyright_repo_name():
    return COPYRIGHT_TOOL["repo"]

def copyright_default_version():
    return COPYRIGHT_TOOL["default_version"]
