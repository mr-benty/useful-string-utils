
def hunter_probe_symbol():
    """A known symbol for blackbird indexing verification."""
    return 42

def another_test_func(x, y):
    return hunter_probe_symbol() + x + y

class ProbeClass:
    def method_one(self):
        return hunter_probe_symbol()
