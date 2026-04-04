load("//rules/web/private:launcher.bzl", "web_runner")

def _require_project_dir(rule_name, project_dir):
    if not project_dir:
        fail("%s requires project_dir" % rule_name)

def web_init(name, project_dir = None, package_name = None, **kwargs):
    _require_project_dir("web_init", project_dir)
    if not package_name:
        fail("web_init requires package_name")
    web_runner(
        name = name,
        kind = "init",
        project_dir = project_dir,
        package_name = package_name,
        **kwargs
    )

def web_install(name, project_dir = None, **kwargs):
    _require_project_dir("web_install", project_dir)
    web_runner(
        name = name,
        kind = "install",
        project_dir = project_dir,
        **kwargs
    )

def web_dev(name, project_dir = None, **kwargs):
    _require_project_dir("web_dev", project_dir)
    web_runner(
        name = name,
        kind = "dev",
        project_dir = project_dir,
        **kwargs
    )

def web_build(name, project_dir = None, **kwargs):
    _require_project_dir("web_build", project_dir)
    web_runner(
        name = name,
        kind = "build",
        project_dir = project_dir,
        **kwargs
    )

def web_preview(name, project_dir = None, **kwargs):
    _require_project_dir("web_preview", project_dir)
    web_runner(
        name = name,
        kind = "preview",
        project_dir = project_dir,
        **kwargs
    )

def web_typecheck(name, project_dir = None, **kwargs):
    _require_project_dir("web_typecheck", project_dir)
    web_runner(
        name = name,
        kind = "typecheck",
        project_dir = project_dir,
        **kwargs
    )

def web_test(name, project_dir = None, **kwargs):
    _require_project_dir("web_test", project_dir)
    web_runner(
        name = name,
        kind = "test",
        project_dir = project_dir,
        **kwargs
    )

def web_browser_install(name, project_dir = None, **kwargs):
    _require_project_dir("web_browser_install", project_dir)
    web_runner(
        name = name,
        kind = "browser_install",
        project_dir = project_dir,
        **kwargs
    )

def web_e2e(name, project_dir = None, **kwargs):
    _require_project_dir("web_e2e", project_dir)
    web_runner(
        name = name,
        kind = "e2e",
        project_dir = project_dir,
        **kwargs
    )
