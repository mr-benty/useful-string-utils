# useful-string-utils

[![Ruby](https://img.shields.io/badge/ruby-%3E%3D2.7-red.svg)](https://www.ruby-lang.org/)
[![License: MIT](https://img.shields.io/badge/license-MIT-yellow.svg)](LICENSE)

Small zero-dependency string utilities for Ruby. The handful of helpers I keep rewriting from scratch in every project — case conversions, padding, slug generation.

## Installation

In your `Gemfile`:

```ruby
gem "useful-string-utils", github: "mr-benty/useful-string-utils"
```

Or pin to a tag:

```ruby
gem "useful-string-utils", github: "mr-benty/useful-string-utils", tag: "v1.0.0"
```

## Usage

```ruby
require "useful_string_utils"

UsefulStringUtils.snake_case("HelloWorld")      # => "hello_world"
UsefulStringUtils.snake_case("HTTPServer")      # => "http_server"
UsefulStringUtils.camel_case("hello_world")     # => "HelloWorld"
UsefulStringUtils.kebab_case("HelloWorld")      # => "hello-world"

UsefulStringUtils.slugify("Café au lait!")      # => "cafe-au-lait"
UsefulStringUtils.left_pad("42", 5, "0")        # => "00042"
UsefulStringUtils.right_pad("foo", 6, ".")      # => "foo..."
UsefulStringUtils.truncate("Hello world", 8)    # => "Hello..."
```

## API

| Function | Purpose |
|---|---|
| `snake_case(str)` | Convert any case to snake_case |
| `camel_case(str)` | Convert snake_case / kebab-case to CamelCase |
| `kebab_case(str)` | Convert any case to kebab-case |
| `slugify(str)` | URL-friendly slug, ASCII-only |
| `left_pad(str, n, pad)` | Left-pad to length n |
| `right_pad(str, n, pad)` | Right-pad to length n |
| `truncate(str, max, ellipsis)` | Truncate with ellipsis |

## Testing

```sh
ruby -Ilib -Itest test/useful_string_utils_test.rb
```

## License

MIT — see [LICENSE](LICENSE).
