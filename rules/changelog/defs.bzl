load("//rules/changelog/private:launcher.bzl", "changelog_runner")

def _common_attrs(
        name,
        kind,
        changelog_file = "CHANGELOG.md",
        config = ".chglog/config.yml",
        template = ".chglog/CHANGELOG.tpl.md",
        query = "",
        from_ref = "",
        to_ref = "",
        next_tag = "unreleased",
        path_filters = [],
        sort = "date",
        profile = "balanced",
        cadence = "monthly",
        use_baseline = True,
        archive_enable = True,
        state_file = ".chglog/state.env",
        archive_dir = ".chglog/archive",
        now = "",
        strict_state = False,
        **kwargs):
    changelog_runner(
        name = name,
        kind = kind,
        changelog_file = changelog_file,
        config = config,
        template = template,
        query = query,
        from_ref = from_ref,
        to_ref = to_ref,
        next_tag = next_tag,
        path_filters = path_filters,
        sort = sort,
        profile = profile,
        cadence = cadence,
        use_baseline = use_baseline,
        archive_enable = archive_enable,
        state_file = state_file,
        archive_dir = archive_dir,
        now = now,
        strict_state = strict_state,
        **kwargs
    )

def changelog_init(name, config = ".chglog/config.yml", template = ".chglog/CHANGELOG.tpl.md", state_file = ".chglog/state.env", archive_dir = ".chglog/archive", **kwargs):
    changelog_runner(
        name = name,
        kind = "init",
        config = config,
        template = template,
        state_file = state_file,
        archive_dir = archive_dir,
        **kwargs
    )

def changelog_generate(name, **kwargs):
    _common_attrs(name = name, kind = "generate", **kwargs)

def changelog_preview(name, **kwargs):
    _common_attrs(name = name, kind = "preview", **kwargs)

def changelog_verify(name, **kwargs):
    _common_attrs(name = name, kind = "verify", **kwargs)

def changelog_state_print(name, **kwargs):
    _common_attrs(name = name, kind = "state_print", **kwargs)

def changelog_state_reset(name, **kwargs):
    _common_attrs(name = name, kind = "state_reset", **kwargs)
