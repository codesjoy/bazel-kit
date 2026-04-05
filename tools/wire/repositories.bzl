load("//tools/shared:go_source_tool_repository.bzl", "build_go_source_tool")
load(":versions.bzl", "WIRE_TOOL", "wire_default_version")

def _wire_version(version):
    versions = WIRE_TOOL["versions"]
    if version not in versions:
        fail("unsupported wire version %s" % version)
    return versions[version]

def _wire_repository_impl(repository_ctx):
    build_go_source_tool(
        repository_ctx,
        WIRE_TOOL,
        _wire_version(repository_ctx.attr.version),
        "wire-tool",
    )

wire_repository = repository_rule(
    implementation = _wire_repository_impl,
    attrs = {
        "version": attr.string(default = wire_default_version()),
    },
)
