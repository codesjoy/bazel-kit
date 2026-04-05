load("//tools/shared:go_source_tool_repository.bzl", "build_go_source_tool")
load(":versions.bzl", "MIGRATE_TOOL", "migrate_default_version")

def _migrate_version(version):
    versions = MIGRATE_TOOL["versions"]
    if version not in versions:
        fail("unsupported migrate version %s" % version)
    return versions[version]

def _migrate_repository_impl(repository_ctx):
    build_go_source_tool(
        repository_ctx,
        MIGRATE_TOOL,
        _migrate_version(repository_ctx.attr.version),
        "migrate-tool",
    )

migrate_repository = repository_rule(
    implementation = _migrate_repository_impl,
    attrs = {
        "version": attr.string(default = migrate_default_version()),
    },
)
