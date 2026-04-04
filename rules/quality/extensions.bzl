load("//tools/quality/go:repositories.bzl", "quality_go_binary_tool_repository", "quality_go_go_source_tool_repository")
load("//tools/quality/go:versions.bzl", "QUALITY_GO_DEFAULT_ENABLED_TOOLS", "QUALITY_GO_TOOL_DEFINITIONS", "quality_go_default_version", "quality_go_repo_name")
load("//tools/quality/shell:repositories.bzl", "quality_shell_binary_tool_repository")
load("//tools/quality/shell:versions.bzl", "QUALITY_SHELL_DEFAULT_ENABLED_TOOLS", "QUALITY_SHELL_TOOL_DEFINITIONS", "quality_shell_default_version", "quality_shell_repo_name")

_VALID_DOMAINS = ["go", "shell"]

def _validate_domain(domain, context):
    if domain not in _VALID_DOMAINS:
        fail("unknown quality %s domain: %s" % (context, domain))

def _collect_install_settings(module_ctx):
    enabled_domains = {}
    install_seen = False
    shellcheck_enabled = False

    for module in module_ctx.modules:
        for install in module.tags.install:
            install_seen = True
            for domain in install.domains:
                _validate_domain(domain, "install")
                enabled_domains[domain] = True
            shellcheck_enabled = shellcheck_enabled or install.shellcheck

    if not install_seen:
        for domain in _VALID_DOMAINS:
            enabled_domains[domain] = True

    if shellcheck_enabled and not enabled_domains.get("shell"):
        fail("quality_tools.install(shellcheck = True) requires shell domain in install domains")

    return enabled_domains, shellcheck_enabled

def _collect_overrides(module_ctx):
    overrides = {}

    for module in module_ctx.modules:
        for override in module.tags.override:
            _validate_domain(override.domain, "override")
            definitions = QUALITY_GO_TOOL_DEFINITIONS if override.domain == "go" else QUALITY_SHELL_TOOL_DEFINITIONS
            if override.name not in definitions:
                fail("unknown quality tool override for %s: %s" % (override.domain, override.name))

            domain_overrides = overrides.setdefault(override.domain, {})
            if override.name in domain_overrides and domain_overrides[override.name] != override.version:
                fail("duplicate quality tool override for %s/%s" % (override.domain, override.name))
            domain_overrides[override.name] = override.version

    return overrides

def _declare_go_repos(overrides):
    repos = []
    go_overrides = overrides.get("go", {})

    for tool in QUALITY_GO_DEFAULT_ENABLED_TOOLS:
        version = go_overrides.get(tool, quality_go_default_version(tool))
        if QUALITY_GO_TOOL_DEFINITIONS[tool]["kind"] == "go_source":
            quality_go_go_source_tool_repository(
                name = quality_go_repo_name(tool),
                tool = tool,
                version = version,
            )
        else:
            quality_go_binary_tool_repository(
                name = quality_go_repo_name(tool),
                tool = tool,
                version = version,
            )
        repos.append(quality_go_repo_name(tool))

    return repos

def _declare_shell_repos(overrides, shellcheck_enabled):
    repos = []
    shell_overrides = overrides.get("shell", {})

    for tool in QUALITY_SHELL_DEFAULT_ENABLED_TOOLS:
        quality_shell_binary_tool_repository(
            name = quality_shell_repo_name(tool),
            tool = tool,
            version = shell_overrides.get(tool, quality_shell_default_version(tool)),
        )
        repos.append(quality_shell_repo_name(tool))

    quality_shell_binary_tool_repository(
        name = quality_shell_repo_name("shellcheck"),
        tool = "shellcheck",
        version = shell_overrides.get("shellcheck", quality_shell_default_version("shellcheck")),
        enabled = shellcheck_enabled,
    )
    repos.append(quality_shell_repo_name("shellcheck"))

    return repos

def _quality_tools_impl(module_ctx):
    enabled_domains, shellcheck_enabled = _collect_install_settings(module_ctx)
    overrides = _collect_overrides(module_ctx)

    repos = []
    if enabled_domains.get("go"):
        repos.extend(_declare_go_repos(overrides))
    if enabled_domains.get("shell"):
        repos.extend(_declare_shell_repos(overrides, shellcheck_enabled))

    return module_ctx.extension_metadata(
        root_module_direct_deps = repos,
        root_module_direct_dev_deps = [],
        reproducible = True,
    )

_install_tag = tag_class(
    attrs = {
        "domains": attr.string_list(default = ["go", "shell"]),
        "shellcheck": attr.bool(default = False),
    },
)

_override_tag = tag_class(
    attrs = {
        "domain": attr.string(mandatory = True),
        "name": attr.string(mandatory = True),
        "version": attr.string(mandatory = True),
    },
)

quality_tools = module_extension(
    implementation = _quality_tools_impl,
    tag_classes = {
        "install": _install_tag,
        "override": _override_tag,
    },
)
