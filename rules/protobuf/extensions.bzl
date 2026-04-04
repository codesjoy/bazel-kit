load("//tools/protobuf:repositories.bzl", "protobuf_buf_repository", "protobuf_plugin_repository")
load("//tools/protobuf:versions.bzl", "PROTOBUF_BUF_TOOL", "PROTOBUF_PLUGIN_TOOL_DEFINITIONS", "protobuf_buf_default_version", "protobuf_buf_repo_name", "protobuf_default_pkg_commit", "protobuf_plugin_repo_name")

def _collect_version_override(module_ctx):
    override_version = None
    for module in module_ctx.modules:
        for override in module.tags.override:
            if override.version not in PROTOBUF_BUF_TOOL["versions"]:
                fail("unknown protobuf tool override version: %s" % override.version)
            if override_version and override_version != override.version:
                fail("duplicate protobuf tool override for buf")
            override_version = override.version
    return override_version

def _collect_pkg_commit(module_ctx):
    override_commit = None
    for module in module_ctx.modules:
        for override in module.tags.pkg_override:
            if override.commit != protobuf_default_pkg_commit():
                fail("unsupported protobuf pkg override commit: %s" % override.commit)
            if override_commit and override_commit != override.commit:
                fail("duplicate protobuf pkg override")
            override_commit = override.commit
    return override_commit

def _collect_plugins(module_ctx):
    plugins = {}
    for module in module_ctx.modules:
        for install in module.tags.install:
            for plugin in install.plugins:
                if plugin not in PROTOBUF_PLUGIN_TOOL_DEFINITIONS:
                    fail("unknown protobuf plugin: %s" % plugin)
                plugins[plugin] = True
    return sorted(plugins.keys())

def _protobuf_tools_impl(module_ctx):
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

    version = _collect_version_override(module_ctx) or protobuf_buf_default_version()
    plugins = _collect_plugins(module_ctx)
    pkg_commit = _collect_pkg_commit(module_ctx) or protobuf_default_pkg_commit()
    protobuf_buf_repository(
        name = protobuf_buf_repo_name(),
        version = version,
    )

    repos = [protobuf_buf_repo_name()]
    for plugin in plugins:
        protobuf_plugin_repository(
            name = protobuf_plugin_repo_name(plugin),
            plugin = plugin,
            commit = pkg_commit,
        )
        repos.append(protobuf_plugin_repo_name(plugin))

    return module_ctx.extension_metadata(
        root_module_direct_deps = repos,
        root_module_direct_dev_deps = [],
        reproducible = True,
    )

_install_tag = tag_class(
    attrs = {
        "plugins": attr.string_list(default = []),
    },
)

_override_tag = tag_class(
    attrs = {
        "version": attr.string(mandatory = True),
    },
)

_pkg_override_tag = tag_class(
    attrs = {
        "commit": attr.string(mandatory = True),
    },
)

protobuf_tools = module_extension(
    implementation = _protobuf_tools_impl,
    tag_classes = {
        "install": _install_tag,
        "override": _override_tag,
        "pkg_override": _pkg_override_tag,
    },
)
