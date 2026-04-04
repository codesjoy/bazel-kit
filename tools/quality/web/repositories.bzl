load("//tools/shared:helpers.bzl", "platform_key", "tool_filename", "write_build_file")
load(":versions.bzl", "QUALITY_WEB_TOOL_DEFINITIONS")

def _tool_version(tool, version):
    tool_info = QUALITY_WEB_TOOL_DEFINITIONS[tool]
    versions = tool_info["versions"]
    if version not in versions:
        fail("unsupported version %s for quality web tool %s" % (version, tool))
    return tool_info, versions[version]

def _binary_tool_repository_impl(repository_ctx):
    tool = repository_ctx.attr.tool
    version = repository_ctx.attr.version
    tool_info, version_info = _tool_version(tool, version)
    platform = platform_key(repository_ctx)
    if platform not in version_info:
        fail("unsupported platform %s for quality web tool %s@%s" % (platform, tool, version))

    platform_info = version_info[platform]
    is_windows = platform.startswith("windows_")
    filename = tool_filename(tool_info["binary_name"], is_windows)

    repository_ctx.download(
        url = platform_info["url"],
        sha256 = platform_info["sha256"],
        output = filename,
        executable = True,
    )
    write_build_file(repository_ctx, filename)

quality_web_binary_tool_repository = repository_rule(
    implementation = _binary_tool_repository_impl,
    attrs = {
        "tool": attr.string(mandatory = True),
        "version": attr.string(mandatory = True),
    },
)
