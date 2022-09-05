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

import drchaos

proc default(_: typedesc[HtmlNode]): HtmlNode =
  HtmlNode(tag: th)

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

func fuzzTarget(x: HtmlNode) =
  let data = HtmlNode(tag: head, kids: @[
    HtmlNode(tag: text, s: "mychild"),
    HtmlNode(tag: body)
  ])
  doAssert $x != $data

defaultMutator(fuzzTarget)
