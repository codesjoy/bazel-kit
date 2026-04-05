load("//rules/devx/private:launcher.bzl", "devx_runner")

def devx_workflow(
        name,
        run_targets = [],
        test_targets = [],
        coverage_targets = [],
        coverage_threshold = 0,
        coverage_output_dir = "_output/coverage",
        bazel_args = [],
        **kwargs):
    devx_runner(
        name = name,
        kind = "workflow",
        run_targets = run_targets,
        test_targets = test_targets,
        coverage_targets = coverage_targets,
        coverage_threshold = coverage_threshold,
        coverage_output_dir = coverage_output_dir,
        bazel_args = bazel_args,
        **kwargs
    )

def devx_doctor(
        name,
        required_commands = [],
        verify_run_targets = [],
        verify_test_targets = [],
        require_git_repo = True,
        **kwargs):
    devx_runner(
        name = name,
        kind = "doctor",
        required_commands = required_commands,
        verify_run_targets = verify_run_targets,
        verify_test_targets = verify_test_targets,
        require_git_repo = require_git_repo,
        **kwargs
    )

def hooks_install(name, **kwargs):
    devx_runner(name = name, kind = "hooks_install", **kwargs)

def hooks_verify(name, **kwargs):
    devx_runner(name = name, kind = "hooks_verify", **kwargs)

def hooks_run(name, **kwargs):
    devx_runner(name = name, kind = "hooks_run", **kwargs)

def hooks_run_all(name, **kwargs):
    devx_runner(name = name, kind = "hooks_run_all", **kwargs)

def hooks_clean(name, **kwargs):
    devx_runner(name = name, kind = "hooks_clean", **kwargs)
