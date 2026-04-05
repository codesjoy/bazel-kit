WIRE_TOOL = {
    "repo": "wire_tool_wire",
    "binary_name": "wire",
    "default_version": "v0.7.0",
    "versions": {
        "v0.7.0": {
            "url": "https://github.com/google/wire/archive/refs/tags/v0.7.0.tar.gz",
            "sha256": "06d07189bf3c2e5e1fd3d90c10e3dacf23dbf26334cd9812bfd76753b2523a97",
            "strip_prefix": "wire-0.7.0",
            "build_package": "./cmd/wire",
        },
    },
}

def wire_repo_name():
    return WIRE_TOOL["repo"]

def wire_default_version():
    return WIRE_TOOL["default_version"]
