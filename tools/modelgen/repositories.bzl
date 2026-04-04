load("//tools/shared:helpers.bzl", "is_windows_os", "merge_env", "tool_filename", "write_build_file")
load(":versions.bzl", "MODELGEN_PKG_SOURCE", "MODELGEN_TOOL", "modelgen_default_commit")

def _pkg_source_info(commit):
    if commit != MODELGEN_PKG_SOURCE["default_commit"]:
        fail("unsupported modelgen pkg source commit %s" % commit)
    return MODELGEN_PKG_SOURCE

def _codesjoy_modelgen_repository_impl(repository_ctx):
    source_info = _pkg_source_info(repository_ctx.attr.commit)
    tool_info = MODELGEN_TOOL
    filename = tool_filename(tool_info["binary_name"], is_windows_os(repository_ctx.os.name))

    repository_ctx.download_and_extract(
        url = source_info["url"],
        sha256 = source_info["sha256"],
        stripPrefix = source_info["strip_prefix"],
        type = "tar.gz",
    )

    go = repository_ctx.which("go")
    if go == None:
        fail("go is required to build modelgen tool %s" % tool_info["binary_name"])

    output_path = str(repository_ctx.path(filename))
    env = merge_env(repository_ctx, {
        "CGO_ENABLED": "0",
        "GOCACHE": str(repository_ctx.path("modelgen-go-build-cache")),
        "GOMODCACHE": str(repository_ctx.path("modelgen-go-mod-cache")),
        "GOWORK": "off",
    })
    result = repository_ctx.execute(
        [str(go), "build", "-o", output_path, "."],
        working_directory = str(repository_ctx.path(tool_info["subdir"])),
        environment = env,
    )
    if result.return_code != 0:
        fail("building modelgen tool %s failed:\n%s%s" % (
            tool_info["binary_name"],
            result.stdout,
            result.stderr,
        ))

    write_build_file(repository_ctx, filename)

codesjoy_modelgen_repository = repository_rule(
    implementation = _codesjoy_modelgen_repository_impl,
    attrs = {
        "commit": attr.string(default = modelgen_default_commit()),
    },
)
