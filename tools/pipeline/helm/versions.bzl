PIPELINE_HELM_TOOL = {
    "repo": "pipeline_tool_helm",
    "binary_name": "helm",
    "versions": {
        "v3.20.1": {
            "darwin_amd64": {
                "url": "https://get.helm.sh/helm-v3.20.1-darwin-amd64.tar.gz",
                "sha256": "580515b544d5c966edc6f782c9ae88e21a9e10c786a7d6c5fd4b52613f321076",
                "strip_prefix": "darwin-amd64",
                "binary_path": "helm",
            },
            "darwin_arm64": {
                "url": "https://get.helm.sh/helm-v3.20.1-darwin-arm64.tar.gz",
                "sha256": "75cc96ac3fe8b8b9928eb051e55698e98d1e026967b6bffe4f0f3c538a551b65",
                "strip_prefix": "darwin-arm64",
                "binary_path": "helm",
            },
            "linux_amd64": {
                "url": "https://get.helm.sh/helm-v3.20.1-linux-amd64.tar.gz",
                "sha256": "0165ee4a2db012cc657381001e593e981f42aa5707acdd50658326790c9d0dc3",
                "strip_prefix": "linux-amd64",
                "binary_path": "helm",
            },
            "linux_arm64": {
                "url": "https://get.helm.sh/helm-v3.20.1-linux-arm64.tar.gz",
                "sha256": "56b9d1b0e0efbb739be6e68a37860ace8ec9c7d3e6424e3b55d4c459bc3a0401",
                "strip_prefix": "linux-arm64",
                "binary_path": "helm",
            },
            "windows_amd64": {
                "url": "https://get.helm.sh/helm-v3.20.1-windows-amd64.zip",
                "sha256": "16d5256f4c2cde0745acb922ba88b7759dfced4bf547b99381084211f81c8629",
                "strip_prefix": "windows-amd64",
                "binary_path": "helm.exe",
            },
            "windows_arm64": {
                "url": "https://get.helm.sh/helm-v3.20.1-windows-arm64.zip",
                "sha256": "2aac2b87e92c32d44aa81c6412286d9db7e43b22b4c8ac112b68cf69185429bd",
                "strip_prefix": "windows-arm64",
                "binary_path": "helm.exe",
            },
        },
    },
}

def pipeline_helm_default_version():
    return "v3.20.1"

def pipeline_helm_repo_name():
    return PIPELINE_HELM_TOOL["repo"]
