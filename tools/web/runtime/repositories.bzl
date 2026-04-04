load("//tools/shared:helpers.bzl", "platform_key", "tool_filename", "write_build_file")
load(":versions.bzl", "WEB_NODE_TOOL", "WEB_PNPM_TOOL", "web_node_default_version", "web_pnpm_default_version")

def _node_version(version):
    versions = WEB_NODE_TOOL["versions"]
    if version not in versions:
        fail("unsupported web node version %s" % version)
    return versions[version]

def _pnpm_version(version):
    versions = WEB_PNPM_TOOL["versions"]
    if version not in versions:
        fail("unsupported web pnpm version %s" % version)
    return versions[version]

def _write_pnpm_build_file(repository_ctx):
    repository_ctx.file("BUILD.bazel", """
package(default_visibility = ["//visibility:public"])

exports_files(["package/dist/pnpm.cjs"])

filegroup(
    name = "tool",
    srcs = glob(["package/dist/**"], exclude_directories = 1),
    visibility = ["//visibility:public"],
)
""")

def _web_node_repository_impl(repository_ctx):
    version = repository_ctx.attr.version
    version_info = _node_version(version)
    platform = platform_key(repository_ctx)
    if platform not in version_info:
        fail("unsupported platform %s for web node@%s" % (platform, version))

    platform_info = version_info[platform]
    is_windows = platform.startswith("windows_")
    filename = tool_filename(WEB_NODE_TOOL["binary_name"], is_windows)

    repository_ctx.download_and_extract(
        url = platform_info["url"],
        sha256 = platform_info["sha256"],
        stripPrefix = platform_info["strip_prefix"],
    )
    if platform_info["binary_path"] != filename:
        repository_ctx.symlink(platform_info["binary_path"], filename)

    write_build_file(repository_ctx, filename)

def _web_pnpm_repository_impl(repository_ctx):
    version = repository_ctx.attr.version
    version_info = _pnpm_version(version)

    repository_ctx.download_and_extract(
        url = version_info["url"],
        sha256 = version_info["sha256"],
    )
    _write_pnpm_build_file(repository_ctx)

web_node_repository = repository_rule(
    implementation = _web_node_repository_impl,
    attrs = {
        "version": attr.string(default = web_node_default_version()),
    },
)

web_pnpm_repository = repository_rule(
    implementation = _web_pnpm_repository_impl,
    attrs = {
        "version": attr.string(default = web_pnpm_default_version()),
    },
)
