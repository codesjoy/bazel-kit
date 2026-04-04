load("//tools/modelgen:repositories.bzl", "codesjoy_modelgen_repository")
load("//tools/modelgen:versions.bzl", "MODELGEN_PKG_SOURCE", "modelgen_default_commit", "modelgen_repo_name")

def _collect_pkg_commit(module_ctx):
    override_commit = None
    for module in module_ctx.modules:
        for override in module.tags.pkg_override:
            if override.commit != MODELGEN_PKG_SOURCE["default_commit"]:
                fail("unsupported modelgen pkg override commit: %s" % override.commit)
            if override_commit and override_commit != override.commit:
                fail("duplicate modelgen pkg override")
            override_commit = override.commit
    return override_commit

def _modelgen_tools_impl(module_ctx):
    install_seen = False
    for module in module_ctx.modules:
        if module.tags.install:
            install_seen = True

    if not install_seen:
        return module_ctx.extension_metadata(
            root_module_direct_deps = [],
            root_module_direct_dev_deps = [],
            reproducible = True,
        )

    codesjoy_modelgen_repository(
        name = modelgen_repo_name(),
        commit = _collect_pkg_commit(module_ctx) or modelgen_default_commit(),
    )

    return module_ctx.extension_metadata(
        root_module_direct_deps = [modelgen_repo_name()],
        root_module_direct_dev_deps = [],
        reproducible = True,
    )

_install_tag = tag_class(attrs = {})

_pkg_override_tag = tag_class(
    attrs = {
        "commit": attr.string(mandatory = True),
    },
)

modelgen_tools = module_extension(
    implementation = _modelgen_tools_impl,
    tag_classes = {
        "install": _install_tag,
        "pkg_override": _pkg_override_tag,
    },
)
