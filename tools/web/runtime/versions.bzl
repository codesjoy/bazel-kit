WEB_NODE_TOOL = {
    "repo": "web_tool_node",
    "binary_name": "node",
    "default_version": "v24.14.1",
    "versions": {
        "v24.14.1": {
            "darwin_amd64": {
                "url": "https://nodejs.org/dist/v24.14.1/node-v24.14.1-darwin-x64.tar.xz",
                "sha256": "a87a37a10c2faf65742c7d5812f5bab878eee52b0dffdf578f49b7a808d96ddd",
                "strip_prefix": "node-v24.14.1-darwin-x64",
                "binary_path": "bin/node",
            },
            "darwin_arm64": {
                "url": "https://nodejs.org/dist/v24.14.1/node-v24.14.1-darwin-arm64.tar.xz",
                "sha256": "0e2e679d76743d6d9225e61327a1ddc324e4a89a80891c78c337208601d98f77",
                "strip_prefix": "node-v24.14.1-darwin-arm64",
                "binary_path": "bin/node",
            },
            "linux_amd64": {
                "url": "https://nodejs.org/dist/v24.14.1/node-v24.14.1-linux-x64.tar.xz",
                "sha256": "84d38715d449447117d05c3e71acd78daa49d5b1bfa8aacf610303920c3322be",
                "strip_prefix": "node-v24.14.1-linux-x64",
                "binary_path": "bin/node",
            },
            "linux_arm64": {
                "url": "https://nodejs.org/dist/v24.14.1/node-v24.14.1-linux-arm64.tar.xz",
                "sha256": "71e427e28b78846f201d4d5ecc30cb13d1508ca099ef3871889a1256c7d6f67e",
                "strip_prefix": "node-v24.14.1-linux-arm64",
                "binary_path": "bin/node",
            },
            "windows_amd64": {
                "url": "https://nodejs.org/dist/v24.14.1/node-v24.14.1-win-x64.zip",
                "sha256": "6e50ce5498c0cebc20fd39ab3ff5df836ed2f8a31aa093cecad8497cff126d70",
                "strip_prefix": "node-v24.14.1-win-x64",
                "binary_path": "node.exe",
            },
            "windows_arm64": {
                "url": "https://nodejs.org/dist/v24.14.1/node-v24.14.1-win-arm64.zip",
                "sha256": "a7b7c68490e4a8cde1921fe5a0cfb3001d53f9c839e416903e4f28e727b62f60",
                "strip_prefix": "node-v24.14.1-win-arm64",
                "binary_path": "node.exe",
            },
        },
    },
}

WEB_PNPM_TOOL = {
    "repo": "web_tool_pnpm",
    "entrypoint_path": "package/dist/pnpm.cjs",
    "default_version": "v10.33.0",
    "versions": {
        "v10.33.0": {
            "url": "https://registry.npmjs.org/pnpm/-/pnpm-10.33.0.tgz",
            "sha256": "bfcc1bcbad279b13a516c446a75b3c58b6904b45d57a1951411015e50b751a80",
        },
    },
}

def web_node_repo_name():
    return WEB_NODE_TOOL["repo"]

def web_node_default_version():
    return WEB_NODE_TOOL["default_version"]

def web_pnpm_repo_name():
    return WEB_PNPM_TOOL["repo"]

def web_pnpm_default_version():
    return WEB_PNPM_TOOL["default_version"]
