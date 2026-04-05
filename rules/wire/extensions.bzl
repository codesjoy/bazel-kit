load("//tools/wire:repositories.bzl", "wire_repository")
load("//tools/wire:versions.bzl", "wire_default_version", "wire_repo_name")

def _collect_override(module_ctx):
    version = ""
    for module in module_ctx.modules:
        for override in module.tags.override:
            if version and version != override.version:
                fail("duplicate wire tool override")
            version = override.version
    return version

def _wire_tools_impl(module_ctx):
    wire_repository(
        name = wire_repo_name(),
        version = _collect_override(module_ctx) or wire_default_version(),
    )
    return module_ctx.extension_metadata(
        root_module_direct_deps = [wire_repo_name()],
        root_module_direct_dev_deps = [],
        reproducible = True,
    )

wire_tools = module_extension(
    implementation = _wire_tools_impl,
    tag_classes = {
        "install": tag_class(attrs = {}),
        "override": tag_class(attrs = {"version": attr.string(mandatory = True)}),
    },
)
