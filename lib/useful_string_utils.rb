# frozen_string_literal: true

require_relative "useful_string_utils/version"

# Lightweight string utilities for Ruby.
#
# Adds a few helpers that are commonly written by hand in Ruby projects:
# - Case conversions (snake_case <-> CamelCase <-> kebab-case)
# - Padding helpers
# - Slug generation
#
# Example:
#   require "useful_string_utils"
#
#   UsefulStringUtils.snake_case("HelloWorld")    # => "hello_world"
#   UsefulStringUtils.camel_case("hello_world")   # => "HelloWorld"
#   UsefulStringUtils.kebab_case("HelloWorld")    # => "hello-world"
#   UsefulStringUtils.slugify("Café au lait!")    # => "cafe-au-lait"
#   UsefulStringUtils.left_pad("42", 5, "0")      # => "00042"
module UsefulStringUtils
  module_function

  # Convert a CamelCase or kebab-case string into snake_case.
  #
  #   snake_case("HelloWorld")     # => "hello_world"
  #   snake_case("HTTPServer")     # => "http_server"
  #   snake_case("hello-world")    # => "hello_world"
  def snake_case(str)
    str.to_s
       .gsub(/::/, "/")
       .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
       .gsub(/([a-z\d])([A-Z])/, '\1_\2')
       .tr("-", "_")
       .downcase
  end

  # Convert a snake_case or kebab-case string to CamelCase.
  #
  #   camel_case("hello_world")  # => "HelloWorld"
  #   camel_case("hello-world")  # => "HelloWorld"
  def camel_case(str)
    str.to_s.split(/[_-]/).map(&:capitalize).join
  end

  # Convert any case to kebab-case.
  #
  #   kebab_case("HelloWorld")   # => "hello-world"
  #   kebab_case("hello_world")  # => "hello-world"
  def kebab_case(str)
    snake_case(str).tr("_", "-")
  end

  # Make a URL-friendly slug.
  #
  #   slugify("Café au lait!")  # => "cafe-au-lait"
  def slugify(str)
    str.to_s
       .unicode_normalize(:nfkd)
       .encode("ascii", invalid: :replace, undef: :replace, replace: "")
       .downcase
       .gsub(/[^a-z0-9]+/, "-")
       .gsub(/^-+|-+$/, "")
  end

  # Left-pad a string to length n with pad_char.
  #
  #   left_pad("42", 5, "0")  # => "00042"
  def left_pad(str, n, pad_char = " ")
    s = str.to_s
    return s if s.length >= n
    (pad_char.to_s * (n - s.length)) + s
  end

  # Right-pad.
  #
  #   right_pad("foo", 6, ".")  # => "foo..."
  def right_pad(str, n, pad_char = " ")
    s = str.to_s
    return s if s.length >= n
    s + (pad_char.to_s * (n - s.length))
  end

  # Truncate to max length, with ellipsis if truncated.
  #
  #   truncate("Hello world", 8)         # => "Hello..."
  #   truncate("Hello world", 8, "…")    # => "Hello w…"
  def truncate(str, max, ellipsis = "...")
    s = str.to_s
    return s if s.length <= max
    s[0, max - ellipsis.length] + ellipsis
  end
end
