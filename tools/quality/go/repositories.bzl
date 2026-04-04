load("//tools/shared:helpers.bzl", "is_windows_os", "merge_env", "platform_key", "tool_filename", "write_build_file")
load(":versions.bzl", "QUALITY_GO_TOOL_DEFINITIONS")

def _tool_version(tool, version):
    tool_info = QUALITY_GO_TOOL_DEFINITIONS[tool]
    versions = tool_info["versions"]
    if version not in versions:
        fail("unsupported version %s for quality go tool %s" % (version, tool))
    return tool_info, versions[version]

def _binary_tool_repository_impl(repository_ctx):
    tool = repository_ctx.attr.tool
    version = repository_ctx.attr.version
    tool_info, version_info = _tool_version(tool, version)
    platform = platform_key(repository_ctx)
    if platform not in version_info:
        fail("unsupported platform %s for quality go tool %s@%s" % (platform, tool, version))

    platform_info = version_info[platform]
    is_windows = platform.startswith("windows_")
    filename = tool_filename(tool_info["binary_name"], is_windows)

    repository_ctx.download_and_extract(
        url = platform_info["url"],
        sha256 = platform_info["sha256"],
        stripPrefix = platform_info["strip_prefix"],
    )
    if platform_info["binary_path"] != filename:
        repository_ctx.symlink(platform_info["binary_path"], filename)

    write_build_file(repository_ctx, filename)

def _go_source_tool_repository_impl(repository_ctx):
    tool = repository_ctx.attr.tool
    version = repository_ctx.attr.version
    tool_info, version_info = _tool_version(tool, version)
    filename = tool_filename(tool_info["binary_name"], is_windows_os(repository_ctx.os.name))

    repository_ctx.download_and_extract(
        url = version_info["url"],
        sha256 = version_info["sha256"],
        stripPrefix = version_info["strip_prefix"],
    )

    go = repository_ctx.which("go")
    if go == None:
        fail("go is required to build quality go tool %s from source" % tool)

    output_path = str(repository_ctx.path(filename))
    env = merge_env(repository_ctx, {
        "CGO_ENABLED": "0",
        "GOCACHE": str(repository_ctx.path("quality-go-build-cache")),
        "GOMODCACHE": str(repository_ctx.path("quality-go-mod-cache")),
        "GOWORK": "off",
    })
    result = repository_ctx.execute(
        [str(go), "build", "-o", output_path, version_info["build_package"]],
        working_directory = str(repository_ctx.path(".")),
        environment = env,
    )
    if result.return_code != 0:
        fail("building quality go tool %s@%s failed:\n%s%s" % (
            tool,
            version,
            result.stdout,
            result.stderr,
        ))

    write_build_file(repository_ctx, filename)

quality_go_binary_tool_repository = repository_rule(
    implementation = _binary_tool_repository_impl,
    attrs = {
        "tool": attr.string(mandatory = True),
        "version": attr.string(mandatory = True),
    },
)

quality_go_go_source_tool_repository = repository_rule(
    implementation = _go_source_tool_repository_impl,
    attrs = {
        "tool": attr.string(mandatory = True),
        "version": attr.string(mandatory = True),
    },
)
