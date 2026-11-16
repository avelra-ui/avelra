## URL policy tests for the public os.openUrl surface.

import std/unittest

import domain/url_policy

suite "URL policy":
  test "allows http and https with a host":
    check isAllowedUrl("https://avelra.dev/docs/")
    check isAllowedUrl("http://127.0.0.1:8080/")
    check isAllowedUrl("HTTPS://AVELRA.DEV/")

  test "allows mailto with a recipient":
    check isAllowedUrl("mailto:user@example.com")
    check isAllowedUrl("mailto:user@example.com?subject=Hi&body=Hello")

  test "preserves valid query and fragment characters":
    check isAllowedUrl("https://avelra.dev/?a=1&b=2#section")
    check isAllowedUrl("https://avelra.dev/path%20with%20space?q=%26")

  test "rejects non-public schemes":
    check not isAllowedUrl("file:///etc/passwd")
    check not isAllowedUrl("javascript:alert(1)")
    check not isAllowedUrl("data:text/html,hello")
    check not isAllowedUrl("vbscript:msgbox(1)")
    check not isAllowedUrl("myapp://open")

  test "rejects missing hosts and addresses":
    check not isAllowedUrl("http://")
    check not isAllowedUrl("https://")
    check not isAllowedUrl("mailto:")
    check not isAllowedUrl("mailto:user")

  test "rejects control characters":
    check not isAllowedUrl("https://avelra.dev/\0evil")
    check not isAllowedUrl("https://avelra.dev/\revil")
    check not isAllowedUrl("https://avelra.dev/\nevil")
    check not isAllowedUrl("https://avelra.dev/\x7f")

  test "does not trim input":
    check not isAllowedUrl(" https://avelra.dev/")
    check not isAllowedUrl("https://avelra.dev/ ")
