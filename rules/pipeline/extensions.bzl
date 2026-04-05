load("//tools/pipeline/helm:repositories.bzl", "pipeline_helm_repository")
load("//tools/pipeline/helm:versions.bzl", "pipeline_helm_default_version", "pipeline_helm_repo_name")

_VALID_TOOLS = ["helm"]

def _collect_overrides(module_ctx):
    overrides = {}

    for module in module_ctx.modules:
        for override in module.tags.override:
            if override.name not in _VALID_TOOLS:
                fail("unknown pipeline tool override: %s" % override.name)
            if override.name in overrides and overrides[override.name] != override.version:
                fail("duplicate pipeline tool override for %s" % override.name)
            overrides[override.name] = override.version

    return overrides

def _pipeline_tools_impl(module_ctx):
    overrides = _collect_overrides(module_ctx)

    pipeline_helm_repository(
        name = pipeline_helm_repo_name(),
        version = overrides.get("helm", pipeline_helm_default_version()),
    )

    return module_ctx.extension_metadata(
        root_module_direct_deps = [pipeline_helm_repo_name()],
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

pipeline_tools = module_extension(
    implementation = _pipeline_tools_impl,
    tag_classes = {
        "install": _install_tag,
        "override": _override_tag,
    },
)
