import std/random

proc storeCode(buf: var openArray[char]; e: int, code: uint32, size: int, prefix: uint8) =
  var size = size - 1
  var e = e
  var code = code
  while size > 0:
    dec e
    buf[e] = char(0x80 or (code and 0x3f))
    code = code shr 6
    dec size
  dec e
  buf[e] = char(prefix or code)

proc fixCode(buf: var openArray[char], b, e: int, r: var Rand): int =
  let start = b
  assert b < e
  let e = min(e, b + 4)
  var b = b
  var c = uint32(buf[b])
  inc b
  while b < e and (uint32(buf[b]) and 0xc0) == 0x80:
    c = c shl 6 + (uint32(buf[b]) and 0x3f)
    inc b
  let size = b - start
  case size
  of 1:
    c = c and 0x7f
    storeCode(buf, b, c, size, 0)
  of 2:
    c = c and 0x7ff
    if c < 0x80:
      c = r.rand(0x80'u32..0x7ff'u32)
    storeCode(buf, b, c, size, 0xc0)
  of 3:
    c = c and 0xffff
    # [0xD800, 0xE000) are reserved for UTF-16 surrogate halves.
    if c < 0x800 or (c >= 0xd800 and c < 0xe000):
      const halves = 0xe000 - 0xd800
      c = r.rand(0x800'u32..0xffff'u32 - halves)
      if c >= 0xd800: c = c + halves
    storeCode(buf, b, c, size, 0xe0)
  of 4:
    c = c and 0x1fffff
    if c < 0x10000 or c > 0x10ffff:
      c = r.rand(0x10000'u32..0x10ffff'u32)
    storeCode(buf, b, c, size, 0xf0)
  else:
    assert(false, "Unexpected size of UTF-8 sequence")
  return b

proc fixUtf8*(str: var string; r: var Rand) =
  if str == "": return
  var b = 0
  let e = str.len
  while b < e:
    b = fixCode(str, b, e, r)

when isMainModule:
  import unicode
  template isValid(s: string): bool =
    validateUtf8(s) == -1

  block:
    assert "".isValid
    assert "abc".isValid
    assert "\xc2\xa2".isValid
    assert "\xe2\x82\xac".isValid
    assert "\xf0\x90\x8d\x88".isValid
    assert not "\xff\xff\xff\xff".isValid
    assert not "\xff\x8f".isValid
    assert not "\x3f\xbf".isValid

  block:
    var str = newString(rand(0..255))
    for run in 1..10000:
      for i in 0..<str.len: str[i] = rand(char)
      var fixed = str
      fixUtf8(fixed, randState)
      if str.isValid: assert fixed == str
      else: assert fixed.isValid
