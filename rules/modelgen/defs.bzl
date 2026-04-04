load("//rules/modelgen/private:launcher.bzl", "codesjoy_modelgen_runner")

def codesjoy_modelgen(name, dsn, out_dir, schema = "", tables = [], override = None, gen_aipsql = True, timestamp_mode = "unix_sec", dry_run = False, force = False, package_name = "", **kwargs):
    codesjoy_modelgen_runner(
        name = name,
        dsn = dsn,
        out_dir = out_dir,
        schema = schema,
        tables = tables,
        override = override,
        gen_aipsql = gen_aipsql,
        timestamp_mode = timestamp_mode,
        dry_run = dry_run,
        force = force,
        package_name = package_name,
        **kwargs
    )
