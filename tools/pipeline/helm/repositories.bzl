load("//tools/shared:helpers.bzl", "platform_key", "tool_filename", "write_build_file")
load(":versions.bzl", "PIPELINE_HELM_TOOL", "pipeline_helm_default_version")

def _helm_version(version):
    versions = PIPELINE_HELM_TOOL["versions"]
    if version not in versions:
        fail("unsupported pipeline helm version %s" % version)
    return versions[version]

def _pipeline_helm_repository_impl(repository_ctx):
    version = repository_ctx.attr.version
    version_info = _helm_version(version)
    platform = platform_key(repository_ctx)
    if platform not in version_info:
        fail("unsupported platform %s for pipeline helm@%s" % (platform, version))

    platform_info = version_info[platform]
    is_windows = platform.startswith("windows_")
    filename = tool_filename(PIPELINE_HELM_TOOL["binary_name"], is_windows)

    repository_ctx.download_and_extract(
        url = platform_info["url"],
        sha256 = platform_info["sha256"],
        stripPrefix = platform_info["strip_prefix"],
    )
    if platform_info["binary_path"] != filename:
        repository_ctx.symlink(platform_info["binary_path"], filename)

    write_build_file(repository_ctx, filename)

pipeline_helm_repository = repository_rule(
    implementation = _pipeline_helm_repository_impl,
    attrs = {
        "version": attr.string(default = pipeline_helm_default_version()),
    },
)
