load("//rules/protobuf/private:launcher.bzl", "protobuf_buf_runner")

def buf_format(name, config, files = [], **kwargs):
    protobuf_buf_runner(
        name = name,
        kind = "format",
        config = config,
        files = files,
        **kwargs
    )

def buf_format_check(name, config, files = [], **kwargs):
    protobuf_buf_runner(
        name = name,
        kind = "format_check",
        config = config,
        files = files,
        **kwargs
    )

def buf_lint(name, config, **kwargs):
    protobuf_buf_runner(
        name = name,
        kind = "lint",
        config = config,
        **kwargs
    )

def buf_breaking(name, config, against = None, against_git_remote = "origin", against_git_branch = "main", **kwargs):
    protobuf_buf_runner(
        name = name,
        kind = "breaking",
        config = config,
        against = against or "",
        against_git_remote = against_git_remote,
        against_git_branch = against_git_branch,
        **kwargs
    )

def buf_generate(name, config, template, **kwargs):
    protobuf_buf_runner(
        name = name,
        kind = "generate",
        config = config,
        template = template,
        **kwargs
    )

def buf_dep_update(name, config, **kwargs):
    protobuf_buf_runner(
        name = name,
        kind = "dep_update",
        config = config,
        **kwargs
    )
