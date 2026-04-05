load("//tools/shared:go_source_tool_repository.bzl", "build_go_source_tool")
load(":versions.bzl", "CHANGELOG_TOOL", "changelog_default_version")

def _changelog_version(version):
    versions = CHANGELOG_TOOL["versions"]
    if version not in versions:
        fail("unsupported changelog tool version %s" % version)
    return versions[version]

def _changelog_repository_impl(repository_ctx):
    build_go_source_tool(
        repository_ctx,
        CHANGELOG_TOOL,
        _changelog_version(repository_ctx.attr.version),
        "changelog-tool",
    )

changelog_repository = repository_rule(
    implementation = _changelog_repository_impl,
    attrs = {
        "version": attr.string(default = changelog_default_version()),
    },
)
