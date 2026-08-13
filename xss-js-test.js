// Normal JS
function hello() { return "world"; }

// Template literal with HTML
const x = `</pre></div><img src=x onerror=alert('js-template')>`;

// Tagged template
const y = html`<xmp><script>alert('js-tagged')</script></xmp>`;

// Regex with HTML-like content
const z = /(<\/pre>|<\/div>|<img[^>]*onerror)/g;
