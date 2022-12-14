# Example excerpt from the "Mastering Nim" book
type
  Tag = enum
    text, html, head, body, table, tr, th, td
  TagWithKids = range[html..high(Tag)]
  HtmlNode = ref object
    case tag: Tag
    of text: s: string
    else: kids: seq[HtmlNode]

proc newTextNode(s: sink string): HtmlNode =
  HtmlNode(tag: text, s: s)

proc newTree(tag: TagWithKids; kids: varargs[HtmlNode]): HtmlNode =
  HtmlNode(tag: tag, kids: @kids)

func `==`(a, b: HtmlNode): bool =
  if a.isNil:
    if b.isNil: return true
    return false
  elif b.isNil or a.tag != b.tag:
    return false
  else:
    case a.tag
    of text: return a.s == b.s
    else: return a.kids == b.kids

proc add(parent: HtmlNode; kid: sink HtmlNode) = parent.kids.add kid

from std/xmltree import addEscaped

proc toString(n: HtmlNode; result: var string) =
  case n.tag
  of text:
    result.addEscaped n.s
  else:
    result.add "<" & $n.tag
    if n.kids.len == 0:
      result.add " />"
    else:
      result.add ">\n"
      for k in items(n.kids): toString(k, result)
      result.add "\n</" & $n.tag & ">"

proc `$`(n: HtmlNode): string =
  result = newStringOfCap(1000)
  toString n, result

when isMainModule:
  import drchaos

  proc default(_: typedesc[HtmlNode]): HtmlNode =
    HtmlNode(tag: text, s: "")

  proc fuzzTarget(x: HtmlNode) =
    when defined(dumpFuzzInput): debugEcho(x)
    # Here you could feed `$x` to htmlparser.parseHtml and make sure it doesn't crash.
    #var errors: seq[string] = @[]
    #let tree = parseHtml(newStringStream($x), "unknown_html_doc", errors)
    #doAssert errors.len == 0
    doAssert $x != "<head>\n\n</head>"
    # WARNING: When converting the AST to a string representation, this fuzzer seems to get stuck.
    # It might mean that mutators work best when operating directly on the targeted input type.

  defaultMutator(fuzzTarget)
