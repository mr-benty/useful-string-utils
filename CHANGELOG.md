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
