load("//rules/quality/private:web_launcher.bzl", "quality_web_runner")

def web_fmt(name, project_dir = None, paths = [], **kwargs):
    if not project_dir:
        fail("web_fmt requires project_dir")
    quality_web_runner(
        name = name,
        kind = "fmt",
        project_dir = project_dir,
        paths = paths,
        **kwargs
    )

def web_fmt_check(name, project_dir = None, paths = [], **kwargs):
    if not project_dir:
        fail("web_fmt_check requires project_dir")
    quality_web_runner(
        name = name,
        kind = "fmt_check",
        project_dir = project_dir,
        paths = paths,
        **kwargs
    )

def web_lint(name, project_dir = None, paths = [], **kwargs):
    if not project_dir:
        fail("web_lint requires project_dir")
    quality_web_runner(
        name = name,
        kind = "lint",
        project_dir = project_dir,
        paths = paths,
        **kwargs
    )
