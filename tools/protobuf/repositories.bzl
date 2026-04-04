load("//tools/shared:helpers.bzl", "is_windows_os", "merge_env", "platform_key", "tool_filename", "write_build_file")
load(":versions.bzl", "PROTOBUF_BUF_TOOL", "PROTOBUF_PKG_SOURCE", "PROTOBUF_PLUGIN_TOOL_DEFINITIONS", "protobuf_buf_default_version", "protobuf_default_pkg_commit")

def _version_info(version):
    versions = PROTOBUF_BUF_TOOL["versions"]
    if version not in versions:
        fail("unsupported protobuf tool version %s" % version)
    return versions[version]

def _protobuf_buf_repository_impl(repository_ctx):
    version = repository_ctx.attr.version
    version_info = _version_info(version)
    platform = platform_key(repository_ctx)
    if platform not in version_info:
        fail("unsupported platform %s for protobuf tool buf@%s" % (platform, version))

    platform_info = version_info[platform]
    is_windows = platform.startswith("windows_")
    filename = tool_filename(PROTOBUF_BUF_TOOL["binary_name"], is_windows)

    repository_ctx.download(
        url = platform_info["url"],
        sha256 = platform_info["sha256"],
        output = filename,
        executable = True,
    )
    write_build_file(repository_ctx, filename)

protobuf_buf_repository = repository_rule(
    implementation = _protobuf_buf_repository_impl,
    attrs = {
        "version": attr.string(default = protobuf_buf_default_version()),
    },
)

def _pkg_source_info(commit):
    if commit != PROTOBUF_PKG_SOURCE["default_commit"]:
        fail("unsupported protobuf pkg source commit %s" % commit)
    return PROTOBUF_PKG_SOURCE

def _plugin_info(plugin):
    if plugin not in PROTOBUF_PLUGIN_TOOL_DEFINITIONS:
        fail("unknown protobuf plugin %s" % plugin)
    return PROTOBUF_PLUGIN_TOOL_DEFINITIONS[plugin]

def _protobuf_plugin_repository_impl(repository_ctx):
    source_info = _pkg_source_info(repository_ctx.attr.commit)
    tool_info = _plugin_info(repository_ctx.attr.plugin)
    filename = tool_filename(tool_info["binary_name"], is_windows_os(repository_ctx.os.name))

    repository_ctx.download_and_extract(
        url = source_info["url"],
        sha256 = source_info["sha256"],
        stripPrefix = source_info["strip_prefix"],
        type = "tar.gz",
    )

    go = repository_ctx.which("go")
    if go == None:
        fail("go is required to build protobuf plugin %s" % repository_ctx.attr.plugin)

    output_path = str(repository_ctx.path(filename))
    env = merge_env(repository_ctx, {
        "CGO_ENABLED": "0",
        "GOCACHE": str(repository_ctx.path("protobuf-plugin-go-build-cache")),
        "GOMODCACHE": str(repository_ctx.path("protobuf-plugin-go-mod-cache")),
        "GOWORK": "off",
    })
    result = repository_ctx.execute(
        [str(go), "build", "-o", output_path, "."],
        working_directory = str(repository_ctx.path(tool_info["subdir"])),
        environment = env,
    )
    if result.return_code != 0:
        fail("building protobuf plugin %s failed:\n%s%s" % (
            repository_ctx.attr.plugin,
            result.stdout,
            result.stderr,
        ))

    write_build_file(repository_ctx, filename)

protobuf_plugin_repository = repository_rule(
    implementation = _protobuf_plugin_repository_impl,
    attrs = {
        "plugin": attr.string(mandatory = True),
        "commit": attr.string(default = protobuf_default_pkg_commit()),
    },
)
