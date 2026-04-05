load("//tools/changelog:repositories.bzl", "changelog_repository")
load("//tools/changelog:versions.bzl", "changelog_default_version", "changelog_repo_name")

def _collect_override(module_ctx):
    version = ""
    for module in module_ctx.modules:
        for override in module.tags.override:
            if version and version != override.version:
                fail("duplicate changelog tool override")
            version = override.version
    return version

def _changelog_tools_impl(module_ctx):
    changelog_repository(
        name = changelog_repo_name(),
        version = _collect_override(module_ctx) or changelog_default_version(),
    )
    return module_ctx.extension_metadata(
        root_module_direct_deps = [changelog_repo_name()],
        root_module_direct_dev_deps = [],
        reproducible = True,
    )

changelog_tools = module_extension(
    implementation = _changelog_tools_impl,
    tag_classes = {
        "install": tag_class(attrs = {}),
        "override": tag_class(attrs = {"version": attr.string(mandatory = True)}),
    },
)
