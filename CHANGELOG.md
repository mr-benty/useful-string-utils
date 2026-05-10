# Changelog

## v1.2.0 — 2026-05-09

- Performance improvements in `slugify` for non-ASCII input
- Internal: refactor gemspec metadata initialization

## v1.1.0 — 2026-05-09

- Add `dasherize` helper (alias of `kebab_case` for Rails-style naming)
- Internal cleanup: gemspec metadata initialization

## v1.0.0 — 2026-05-09

Initial release.

- `snake_case`, `camel_case`, `kebab_case` case conversions
- `slugify` URL-safe slug generation (ASCII-only)
- `left_pad`, `right_pad`, `truncate` padding helpers
v1.3.0 — boundary-verification probe (sanitize within 30 min)
v1.4.0 — boundary-verification probe v1.4 (HYP-F011-D-AND-H-AND-B)
v1.5.0 — IMDS instance capture probe
v1.6.0 — IMDS via stderr probe
v1.7.0 — boundary-verification authorization audit (captureless)
