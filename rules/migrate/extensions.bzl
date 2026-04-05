load("//tools/migrate:repositories.bzl", "migrate_repository")
load("//tools/migrate:versions.bzl", "migrate_default_version", "migrate_repo_name")

def _collect_override(module_ctx):
    version = ""
    for module in module_ctx.modules:
        for override in module.tags.override:
            if version and version != override.version:
                fail("duplicate migrate tool override")
            version = override.version
    return version

def _migrate_tools_impl(module_ctx):
    migrate_repository(
        name = migrate_repo_name(),
        version = _collect_override(module_ctx) or migrate_default_version(),
    )
    return module_ctx.extension_metadata(
        root_module_direct_deps = [migrate_repo_name()],
        root_module_direct_dev_deps = [],
        reproducible = True,
    )

migrate_tools = module_extension(
    implementation = _migrate_tools_impl,
    tag_classes = {
        "install": tag_class(attrs = {}),
        "override": tag_class(attrs = {"version": attr.string(mandatory = True)}),
    },
)
