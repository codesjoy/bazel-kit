load("//tools/shared:helpers.bzl", "platform_key", "tool_filename", "write_build_file", "write_disabled_tool")
load(":versions.bzl", "QUALITY_SHELL_TOOL_DEFINITIONS")

def _tool_version(tool, version):
    tool_info = QUALITY_SHELL_TOOL_DEFINITIONS[tool]
    versions = tool_info["versions"]
    if version not in versions:
        fail("unsupported version %s for quality shell tool %s" % (version, tool))
    return tool_info, versions[version]

def _binary_tool_repository_impl(repository_ctx):
    tool = repository_ctx.attr.tool
    version = repository_ctx.attr.version

    if tool == "shellcheck" and not repository_ctx.attr.enabled:
        write_disabled_tool(
            repository_ctx,
            "shellcheck.cmd" if platform_key(repository_ctx).startswith("windows_") else "shellcheck",
            "shellcheck not configured, skipping shellcheck validation",
        )
        return

    tool_info, version_info = _tool_version(tool, version)
    platform = platform_key(repository_ctx)
    if platform not in version_info:
        fail("unsupported platform %s for quality shell tool %s@%s" % (platform, tool, version))

    platform_info = version_info[platform]
    is_windows = platform.startswith("windows_")
    filename = tool_filename(tool_info["binary_name"], is_windows)

    if tool_info["kind"] == "direct_binary":
        repository_ctx.download(
            url = platform_info["url"],
            sha256 = platform_info["sha256"],
            output = filename,
            executable = True,
        )
    else:
        repository_ctx.download_and_extract(
            url = platform_info["url"],
            sha256 = platform_info["sha256"],
            stripPrefix = platform_info["strip_prefix"],
        )
        if platform_info["binary_path"] != filename:
            repository_ctx.symlink(platform_info["binary_path"], filename)

    write_build_file(repository_ctx, filename)

quality_shell_binary_tool_repository = repository_rule(
    implementation = _binary_tool_repository_impl,
    attrs = {
        "tool": attr.string(mandatory = True),
        "version": attr.string(mandatory = True),
        "enabled": attr.bool(default = True),
    },
)
