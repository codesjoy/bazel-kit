load("//rules/quality/private:shell_launcher.bzl", "quality_shell_runner")

def shell_lint(name, scripts, **kwargs):
    quality_shell_runner(
        name = name,
        kind = "lint",
        scripts = scripts,
        **kwargs
    )

def shell_scripts_lint(name, roots = [], scripts = [], shellcheck_required = False, **kwargs):
    quality_shell_runner(
        name = name,
        kind = "scripts_lint",
        roots = roots,
        scripts = scripts,
        shellcheck_required = shellcheck_required,
        **kwargs
    )
