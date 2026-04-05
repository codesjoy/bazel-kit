MIGRATE_TOOL = {
    "repo": "migrate_tool_migrate",
    "binary_name": "migrate",
    "default_version": "v4.19.1",
    "versions": {
        "v4.19.1": {
            "url": "https://github.com/golang-migrate/migrate/archive/refs/tags/v4.19.1.tar.gz",
            "sha256": "677bf03c19d684dc5bef47e981ec1b4564482cbf5f9b190cb48e110183fd6d25",
            "strip_prefix": "migrate-4.19.1",
            "build_package": "./cmd/migrate",
            "build_tags": ["postgres"],
        },
    },
}

def migrate_repo_name():
    return MIGRATE_TOOL["repo"]

def migrate_default_version():
    return MIGRATE_TOOL["default_version"]
