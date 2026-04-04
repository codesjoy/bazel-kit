load("//tools/shared:helpers.bzl", "platform_key", "tool_filename", "write_build_file")
load(":versions.bzl", "PROTOBUF_BUF_TOOL", "protobuf_buf_default_version")

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
