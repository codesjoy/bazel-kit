def normalize_os(name):
    lower = name.lower()
    if "windows" in lower:
        return "windows"
    if "mac" in lower or "darwin" in lower or "os x" in lower:
        return "darwin"
    if "linux" in lower:
        return "linux"
    fail("unsupported operating system: %s" % name)

def is_windows_os(name):
    return normalize_os(name) == "windows"

def normalize_arch(name):
    lower = name.lower()
    if lower in ["x86_64", "amd64"]:
        return "amd64"
    if lower in ["aarch64", "arm64"]:
        return "arm64"
    fail("unsupported architecture: %s" % name)

def platform_key(repository_ctx):
    arch = getattr(repository_ctx.os, "arch", "")
    if not arch:
        fail("unable to detect host architecture")
    return "%s_%s" % (normalize_os(repository_ctx.os.name), normalize_arch(arch))

def tool_filename(binary_name, is_windows):
    return binary_name + (".exe" if is_windows else "")

def write_build_file(repository_ctx, filename):
    repository_ctx.file("BUILD.bazel", """
package(default_visibility = ["//visibility:public"])

exports_files(["{filename}"])

filegroup(
    name = "tool",
    srcs = ["{filename}"],
    visibility = ["//visibility:public"],
)
""".format(filename = filename))

def write_disabled_tool(repository_ctx, filename, message):
    is_windows = is_windows_os(repository_ctx.os.name)
    content = """@echo off
echo WARN  {message} 1>&2
exit /b 0
""".format(message = message) if is_windows else """#!/usr/bin/env bash
printf 'WARN  {message}\\n' >&2
exit 0
""".format(message = message)
    repository_ctx.file(filename, content, executable = True)
    write_build_file(repository_ctx, filename)

def merge_env(repository_ctx, extra):
    env = dict(repository_ctx.os.environ)
    for key, value in extra.items():
        env[key] = value
    return env

