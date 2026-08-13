# Normal ruby
def hello
  puts "world"
end

# Heredoc with HTML payloads
html = <<~HTML
  </pre></div><img src=x onerror=alert('ruby-heredoc')>
HTML

# String with raw-text element
y = "<xmp><script>alert('ruby-xmp')</script></xmp>"

# Unterminated string edge case
z = '</span></td></tr></table></pre></div><svg onload=alert("ruby-unterm")>'
