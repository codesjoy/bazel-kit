load("//rules/wire/private:launcher.bzl", "wire_runner")

def wire_gen(name, modules = [], target_pkgs = ["./cmd/server"], gocache_dir = "_output/wire-go-build-cache", **kwargs):
    wire_runner(
        name = name,
        kind = "gen",
        modules = modules,
        target_pkgs = target_pkgs,
        gocache_dir = gocache_dir,
        **kwargs
    )

def wire_diff(name, modules = [], target_pkgs = ["./cmd/server"], gocache_dir = "_output/wire-go-build-cache", **kwargs):
    wire_runner(
        name = name,
        kind = "diff",
        modules = modules,
        target_pkgs = target_pkgs,
        gocache_dir = gocache_dir,
        **kwargs
    )

def wire_check(name, modules = [], target_pkgs = ["./cmd/server"], gocache_dir = "_output/wire-go-build-cache", **kwargs):
    wire_runner(
        name = name,
        kind = "check",
        modules = modules,
        target_pkgs = target_pkgs,
        gocache_dir = gocache_dir,
        **kwargs
    )
