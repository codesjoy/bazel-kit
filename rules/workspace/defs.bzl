load("//rules/workspace/private:launcher.bzl", "workspace_runner")

def workspace_sync(name, modules = [], go_work = None, gazelle_target = None, run_bazel_mod_tidy = True, **kwargs):
    workspace_runner(
        name = name,
        kind = "sync",
        modules = modules,
        go_work = go_work,
        gazelle_target = gazelle_target,
        run_bazel_mod_tidy = run_bazel_mod_tidy,
        **kwargs
    )

def go_mod_tidy(name, modules = [], **kwargs):
    workspace_runner(
        name = name,
        kind = "go_mod_tidy",
        modules = modules,
        **kwargs
    )

def go_mod_download(name, modules = [], **kwargs):
    workspace_runner(
        name = name,
        kind = "go_mod_download",
        modules = modules,
        **kwargs
    )

def go_mod_verify(name, modules = [], **kwargs):
    workspace_runner(
        name = name,
        kind = "go_mod_verify",
        modules = modules,
        **kwargs
    )

def workspace_drift_check(name, modules = [], go_work = None, **kwargs):
    workspace_runner(
        name = name,
        kind = "drift_check",
        modules = modules,
        go_work = go_work,
        **kwargs
    )

def workspace_modules_print(name, modules = [], **kwargs):
    workspace_runner(
        name = name,
        kind = "modules_print",
        modules = modules,
        **kwargs
    )

def go_clean(name, modules = [], output_dir = "_output", **kwargs):
    workspace_runner(
        name = name,
        kind = "go_clean",
        modules = modules,
        output_dir = output_dir,
        **kwargs
    )
