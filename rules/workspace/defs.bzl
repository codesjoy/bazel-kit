load("//rules/workspace/private:launcher.bzl", "workspace_sync_runner")

def workspace_sync(name, modules = [], go_work = None, gazelle_target = None, run_bazel_mod_tidy = True, **kwargs):
    workspace_sync_runner(
        name = name,
        modules = modules,
        go_work = go_work,
        gazelle_target = gazelle_target,
        run_bazel_mod_tidy = run_bazel_mod_tidy,
        **kwargs
    )

