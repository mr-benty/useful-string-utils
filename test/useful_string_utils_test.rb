# frozen_string_literal: true

require "minitest/autorun"
require "useful_string_utils"

class UsefulStringUtilsTest < Minitest::Test
  def test_snake_case
    assert_equal "hello_world",   UsefulStringUtils.snake_case("HelloWorld")
    assert_equal "http_server",   UsefulStringUtils.snake_case("HTTPServer")
    assert_equal "hello_world",   UsefulStringUtils.snake_case("hello-world")
  end

  def test_camel_case
    assert_equal "HelloWorld", UsefulStringUtils.camel_case("hello_world")
    assert_equal "HelloWorld", UsefulStringUtils.camel_case("hello-world")
  end

  def test_kebab_case
    assert_equal "hello-world", UsefulStringUtils.kebab_case("HelloWorld")
    assert_equal "hello-world", UsefulStringUtils.kebab_case("hello_world")
  end

  def test_slugify
    assert_equal "cafe-au-lait", UsefulStringUtils.slugify("Café au lait!")
  end

  def test_left_pad
    assert_equal "00042",  UsefulStringUtils.left_pad("42", 5, "0")
    assert_equal "  hi",   UsefulStringUtils.left_pad("hi", 4)
    assert_equal "hello",  UsefulStringUtils.left_pad("hello", 3, "0")
  end

  def test_right_pad
    assert_equal "foo...", UsefulStringUtils.right_pad("foo", 6, ".")
  end

  def test_truncate
    assert_equal "Hello...", UsefulStringUtils.truncate("Hello world", 8)
  end
end
