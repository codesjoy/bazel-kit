load("//tools/shared:go_source_tool_repository.bzl", "build_go_source_tool")
load(":versions.bzl", "COPYRIGHT_TOOL", "copyright_default_version")

def _copyright_version(version):
    versions = COPYRIGHT_TOOL["versions"]
    if version not in versions:
        fail("unsupported addlicense version %s" % version)
    return versions[version]

def _copyright_repository_impl(repository_ctx):
    build_go_source_tool(
        repository_ctx,
        COPYRIGHT_TOOL,
        _copyright_version(repository_ctx.attr.version),
        "copyright-tool",
    )

copyright_repository = repository_rule(
    implementation = _copyright_repository_impl,
    attrs = {
        "version": attr.string(default = copyright_default_version()),
    },
)
