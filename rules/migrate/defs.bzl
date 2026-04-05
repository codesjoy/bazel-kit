load("//rules/migrate/private:launcher.bzl", "migrate_runner")

def _validate_dsn(dsn, dsn_env):
    if bool(dsn) == bool(dsn_env):
        fail("exactly one of dsn or dsn_env is required")

def migrate_up(name, migrations_dir, dsn = "", dsn_env = "DATABASE_DSN", table = "schema_migrations", **kwargs):
    _validate_dsn(dsn, dsn_env)
    migrate_runner(
        name = name,
        kind = "up",
        dsn = dsn,
        dsn_env = dsn_env,
        migrations_dir = migrations_dir,
        table = table,
        **kwargs
    )

def migrate_down(name, migrations_dir, dsn = "", dsn_env = "DATABASE_DSN", table = "schema_migrations", down_steps = 1, **kwargs):
    _validate_dsn(dsn, dsn_env)
    migrate_runner(
        name = name,
        kind = "down",
        dsn = dsn,
        dsn_env = dsn_env,
        migrations_dir = migrations_dir,
        table = table,
        down_steps = down_steps,
        **kwargs
    )

def migrate_version(name, migrations_dir, dsn = "", dsn_env = "DATABASE_DSN", table = "schema_migrations", **kwargs):
    _validate_dsn(dsn, dsn_env)
    migrate_runner(
        name = name,
        kind = "version",
        dsn = dsn,
        dsn_env = dsn_env,
        migrations_dir = migrations_dir,
        table = table,
        **kwargs
    )

def migrate_force(name, migrations_dir, force_version, dsn = "", dsn_env = "DATABASE_DSN", table = "schema_migrations", **kwargs):
    _validate_dsn(dsn, dsn_env)
    migrate_runner(
        name = name,
        kind = "force",
        dsn = dsn,
        dsn_env = dsn_env,
        migrations_dir = migrations_dir,
        table = table,
        force_version = force_version,
        **kwargs
    )
