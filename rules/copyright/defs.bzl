load("//rules/copyright/private:launcher.bzl", "copyright_runner")

def copyright_add(name, boilerplate, roots = ["."], patterns = ["*.go", "*.sh"], year = "", **kwargs):
    copyright_runner(
        name = name,
        kind = "add",
        boilerplate = boilerplate,
        roots = roots,
        patterns = patterns,
        year = year,
        **kwargs
    )

def copyright_verify(name, boilerplate, roots = ["."], patterns = ["*.go", "*.sh"], year = "", **kwargs):
    copyright_runner(
        name = name,
        kind = "verify",
        boilerplate = boilerplate,
        roots = roots,
        patterns = patterns,
        year = year,
        **kwargs
    )
