load("//tools/web/runtime:repositories.bzl", "web_node_repository", "web_pnpm_repository")
load("//tools/web/runtime:versions.bzl", "WEB_NODE_TOOL", "WEB_PNPM_TOOL", "web_node_default_version", "web_node_repo_name", "web_pnpm_default_version", "web_pnpm_repo_name")

_VALID_TOOLS = {
    "node": WEB_NODE_TOOL,
    "pnpm": WEB_PNPM_TOOL,
}

def _collect_overrides(module_ctx):
    overrides = {}

    for module in module_ctx.modules:
        for override in module.tags.override:
            if override.name not in _VALID_TOOLS:
                fail("unknown web tool override: %s" % override.name)
            if override.name in overrides and overrides[override.name] != override.version:
                fail("duplicate web tool override for %s" % override.name)
            overrides[override.name] = override.version

    return overrides

def _web_tools_impl(module_ctx):
    overrides = _collect_overrides(module_ctx)

    web_node_repository(
        name = web_node_repo_name(),
        version = overrides.get("node", web_node_default_version()),
    )
    web_pnpm_repository(
        name = web_pnpm_repo_name(),
        version = overrides.get("pnpm", web_pnpm_default_version()),
    )

    repos = [
        web_node_repo_name(),
        web_pnpm_repo_name(),
    ]

    return module_ctx.extension_metadata(
        root_module_direct_deps = repos,
        root_module_direct_dev_deps = [],
        reproducible = True,
    )

_install_tag = tag_class(attrs = {})

_override_tag = tag_class(
    attrs = {
        "name": attr.string(mandatory = True),
        "version": attr.string(mandatory = True),
    },
)

web_tools = module_extension(
    implementation = _web_tools_impl,
    tag_classes = {
        "install": _install_tag,
        "override": _override_tag,
    },
)
