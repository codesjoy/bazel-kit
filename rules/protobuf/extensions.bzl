load("//tools/protobuf:repositories.bzl", "protobuf_buf_repository")
load("//tools/protobuf:versions.bzl", "PROTOBUF_BUF_TOOL", "protobuf_buf_default_version", "protobuf_buf_repo_name")

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
    protobuf_buf_repository(
        name = protobuf_buf_repo_name(),
        version = version,
    )

    return module_ctx.extension_metadata(
        root_module_direct_deps = [protobuf_buf_repo_name()],
        root_module_direct_dev_deps = [],
        reproducible = True,
    )

_install_tag = tag_class(attrs = {})

_override_tag = tag_class(
    attrs = {
        "version": attr.string(mandatory = True),
    },
)

protobuf_tools = module_extension(
    implementation = _protobuf_tools_impl,
    tag_classes = {
        "install": _install_tag,
        "override": _override_tag,
    },
)
