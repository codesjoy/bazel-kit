QUALITY_WEB_DEFAULT_ENABLED_TOOLS = [
    "biome",
]

QUALITY_WEB_TOOL_DEFINITIONS = {
    "biome": {
        "repo": "quality_tool_biome",
        "binary_name": "biome",
        "default_version": "v2.4.10",
        "versions": {
            "v2.4.10": {
                "darwin_amd64": {
                    "url": "https://github.com/biomejs/biome/releases/download/%40biomejs/biome%402.4.10/biome-darwin-x64",
                    "sha256": "8269b5ef30bbc1fcf0cff5695bdc3733d417744ae638df70e7dabc3b82590fca",
                },
                "darwin_arm64": {
                    "url": "https://github.com/biomejs/biome/releases/download/%40biomejs/biome%402.4.10/biome-darwin-arm64",
                    "sha256": "c6782336dff872beec7d34e1b801c533bd296b5dcf2a30d3cf6335bca975e984",
                },
                "linux_amd64": {
                    "url": "https://github.com/biomejs/biome/releases/download/%40biomejs/biome%402.4.10/biome-linux-x64",
                    "sha256": "fb9423a99ea4be5036f4ee95667fcc5a67e8ff72bd6d23e392033a70fb755d90",
                },
                "linux_arm64": {
                    "url": "https://github.com/biomejs/biome/releases/download/%40biomejs/biome%402.4.10/biome-linux-arm64",
                    "sha256": "4ce5f5750abdce244087e42d73a177c0c1b930f23320c52bf3e973bbc18489de",
                },
                "windows_amd64": {
                    "url": "https://github.com/biomejs/biome/releases/download/%40biomejs/biome%402.4.10/biome-win32-x64.exe",
                    "sha256": "a2bdc915914114c09a6f38ea092af2e450953bf3ace76bc143f2ab4d5a17b238",
                },
                "windows_arm64": {
                    "url": "https://github.com/biomejs/biome/releases/download/%40biomejs/biome%402.4.10/biome-win32-arm64.exe",
                    "sha256": "4285a020237cdb93e6c42cf8af12b3bb2614ecccaeec283dc89f4e092577a3b7",
                },
            },
        },
    },
}

def quality_web_repo_name(tool):
    return QUALITY_WEB_TOOL_DEFINITIONS[tool]["repo"]

def quality_web_default_version(tool):
    return QUALITY_WEB_TOOL_DEFINITIONS[tool]["default_version"]
