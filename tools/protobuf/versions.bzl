PROTOBUF_BUF_TOOL = {
    "repo": "protobuf_tool_buf",
    "binary_name": "buf",
    "default_version": "v1.67.0",
    "versions": {
        "v1.67.0": {
            "darwin_amd64": {
                "url": "https://github.com/bufbuild/buf/releases/download/v1.67.0/buf-Darwin-x86_64",
                "sha256": "606ac7cb5c2a76d5c3ada6f2a59de12a1705d975e731fb765be6a6ccf0d1e5b2",
            },
            "darwin_arm64": {
                "url": "https://github.com/bufbuild/buf/releases/download/v1.67.0/buf-Darwin-arm64",
                "sha256": "7b561964f8238e2acadae666c3e2a11b0a6d4dd716f12882dfedcd93c2a28e1e",
            },
            "linux_amd64": {
                "url": "https://github.com/bufbuild/buf/releases/download/v1.67.0/buf-Linux-x86_64",
                "sha256": "590b67b0cbde29b287e9772a71f46b569c2204e09a42c1c50dc425237a485e2a",
            },
            "linux_arm64": {
                "url": "https://github.com/bufbuild/buf/releases/download/v1.67.0/buf-Linux-aarch64",
                "sha256": "a4bbbb9f299bf7f313bb997d449e262ef29f2f4e001de5d682504d772da1c154",
            },
            "windows_amd64": {
                "url": "https://github.com/bufbuild/buf/releases/download/v1.67.0/buf-Windows-x86_64.exe",
                "sha256": "1547834681e21a695f21cbcbc1646c64156c507cb73b2a99a118c5ff0621e21d",
            },
            "windows_arm64": {
                "url": "https://github.com/bufbuild/buf/releases/download/v1.67.0/buf-Windows-arm64.exe",
                "sha256": "751756e1a4c5d22311acf9ddbd6c4437443d9310ef936779ea8905ad5a83832b",
            },
        },
    },
}

def protobuf_buf_repo_name():
    return PROTOBUF_BUF_TOOL["repo"]

def protobuf_buf_default_version():
    return PROTOBUF_BUF_TOOL["default_version"]

