load("//tools/copyright:repositories.bzl", "copyright_repository")
load("//tools/copyright:versions.bzl", "copyright_default_version", "copyright_repo_name")

def _collect_override(module_ctx):
    version = ""
    for module in module_ctx.modules:
        for override in module.tags.override:
            if version and version != override.version:
                fail("duplicate copyright tool override")
            version = override.version
    return version

def _copyright_tools_impl(module_ctx):
    copyright_repository(
        name = copyright_repo_name(),
        version = _collect_override(module_ctx) or copyright_default_version(),
    )
    return module_ctx.extension_metadata(
        root_module_direct_deps = [copyright_repo_name()],
        root_module_direct_dev_deps = [],
        reproducible = True,
    )

copyright_tools = module_extension(
    implementation = _copyright_tools_impl,
    tag_classes = {
        "install": tag_class(attrs = {}),
        "override": tag_class(attrs = {"version": attr.string(mandatory = True)}),
    },
)
