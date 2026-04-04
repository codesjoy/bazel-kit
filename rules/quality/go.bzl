load("//rules/quality/private:go_launcher.bzl", "quality_go_runner")

def go_fmt(name, files = [], local_prefix = None, **kwargs):
    if not local_prefix:
        fail("go_fmt requires local_prefix")
    quality_go_runner(
        name = name,
        kind = "fmt",
        files = files,
        local_prefix = local_prefix,
        **kwargs
    )

def go_fmt_check(name, files = [], local_prefix = None, **kwargs):
    if not local_prefix:
        fail("go_fmt_check requires local_prefix")
    quality_go_runner(
        name = name,
        kind = "fmt_check",
        files = files,
        local_prefix = local_prefix,
        **kwargs
    )

def go_lint(name, modules = [], config = None, **kwargs):
    if not config:
        fail("go_lint requires config")
    quality_go_runner(
        name = name,
        kind = "lint",
        modules = modules,
        config = config,
        **kwargs
    )
