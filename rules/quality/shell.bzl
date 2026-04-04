load("//rules/quality/private:shell_launcher.bzl", "quality_shell_runner")

def shell_lint(name, scripts, **kwargs):
    quality_shell_runner(
        name = name,
        scripts = scripts,
        **kwargs
    )
