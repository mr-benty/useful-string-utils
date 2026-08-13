# Normal code first (positive control — proves highlighting works)
def hello():
    return "world"

# Payload 1: wrapper terminator
x = "</pre></div><img src=x onerror=alert(1)>"

# Payload 2: raw-text element
y = "<xmp><script>alert(2)</script></xmp>"

# Payload 3: unterminated string with HTML
z = '''</span></pre></div><svg onload=alert(3)>'''

# Payload 4: HTML entity bypass
w = "\x3cscript\x3ealert(4)\x3c/script\x3e"
