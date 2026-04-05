load("//tools/shared:helpers.bzl", "is_windows_os", "merge_env", "tool_filename", "write_build_file")

def build_go_source_tool(repository_ctx, tool_info, version_info, cache_prefix):
    filename = tool_filename(tool_info["binary_name"], is_windows_os(repository_ctx.os.name))

    repository_ctx.download_and_extract(
        url = version_info["url"],
        sha256 = version_info["sha256"],
        stripPrefix = version_info["strip_prefix"],
    )

    go = repository_ctx.which("go")
    if go == None:
        fail("go is required to build %s" % tool_info["binary_name"])

    output_path = str(repository_ctx.path(filename))
    args = [str(go), "build", "-o", output_path]
    build_tags = version_info.get("build_tags", [])
    if build_tags:
        args.extend(["-tags", " ".join(build_tags)])
    args.append(version_info["build_package"])

    env = merge_env(repository_ctx, {
        "CGO_ENABLED": "0",
        "GOCACHE": str(repository_ctx.path(cache_prefix + "-go-build-cache")),
        "GOMODCACHE": str(repository_ctx.path(cache_prefix + "-go-mod-cache")),
        "GOWORK": "off",
    })
    result = repository_ctx.execute(
        args,
        working_directory = str(repository_ctx.path(".")),
        environment = env,
    )
    if result.return_code != 0:
        fail("building %s failed:\n%s%s" % (
            tool_info["binary_name"],
            result.stdout,
            result.stderr,
        ))

    write_build_file(repository_ctx, filename)
