CHANGELOG_TOOL = {
    "repo": "changelog_tool_git_chglog",
    "binary_name": "git-chglog",
    "default_version": "v0.15.4",
    "versions": {
        "v0.15.4": {
            "url": "https://github.com/git-chglog/git-chglog/archive/refs/tags/v0.15.4.tar.gz",
            "sha256": "2351cb4ca5fde61ddc844d210dc5481c7361cfb99f70f35140a57ef6cb5cb311",
            "strip_prefix": "git-chglog-0.15.4",
            "build_package": "./cmd/git-chglog",
        },
    },
}

def changelog_repo_name():
    return CHANGELOG_TOOL["repo"]

def changelog_default_version():
    return CHANGELOG_TOOL["default_version"]
