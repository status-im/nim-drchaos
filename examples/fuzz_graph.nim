# This example produces valid graphs, not garbage, without using graph library functions.
import std/[packedsets, deques]
when defined(runFuzzTests):
  const
    MaxNodes = 8 # User defined, statically limits number of nodes.
    MaxEdges = 2 # Limits number of edges

  type
    NodeIdx = distinct int

  proc `$`(x: NodeIdx): string {.borrow.}
  proc `==`(a, b: NodeIdx): bool {.borrow.}
else:
  type
    NodeIdx = int

type
  Graph*[T] = object
    nodes: seq[Node[T]]

  Node[T] = object
    data: T
    edges: seq[NodeIdx]

proc len*[T](x: Graph[T]): int {.inline.} = x.nodes.len

proc `[]`*[T](x: Graph[T]; idx: Natural): lent T {.inline.} = x.nodes[idx].data
proc `[]`*[T](x: var Graph[T]; idx: Natural): var T {.inline.} = x.nodes[idx].data

proc addNode*[T](x: var Graph[T]; data: sink T) {.nodestroy.} =
  x.nodes.add Node[T](data: data, edges: @[])

proc deleteNode*[T](x: var Graph[T]; idx: Natural) =
  if idx < x.nodes.len:
    x.nodes.delete(idx)
    for n in x.nodes.mitems:
      if (let position = n.edges.find(idx.NodeIdx); position != -1):
        n.edges.delete(position)

proc addEdge*[T](x: var Graph[T]; `from`, to: Natural) =
  if `from` < x.nodes.len and to < x.nodes.len:
    x.nodes[`from`].edges.add(to.NodeIdx)

proc deleteEdge*[T](x: var Graph[T]; `from`, to: Natural) =
  if `from` < x.nodes.len and to < x.nodes.len:
    template fromNode: untyped = x.nodes[`from`]
    if (let toNodeIdx = fromNode.edges.find(to.NodeIdx); toNodeIdx != -1):
      template toNode: untyped = fromNode.edges[toNodeIdx]
      fromNode.edges.delete(toNodeIdx)
      x.deleteNode(toNode.int) # sneaky bug

proc breadthFirstSearch[T](x: Graph[T]; `from`: Natural): seq[NodeIdx] =
  var queue: Deque[NodeIdx]
  queue.addLast(`from`.NodeIdx)

  result = @[`from`.NodeIdx]
  var visited: PackedSet[NodeIdx]
  visited.incl `from`.NodeIdx

  while queue.len > 0:
    let idx = queue.popFirst()
    template node: untyped = x.nodes[idx.int]
    for toNode in node.edges:
      if toNode notin visited:
        queue.addLast(toNode)
        visited.incl toNode
        result.add(toNode)

when defined(runFuzzTests) and isMainModule:
  import std/random, drchaos/[mutator, common]

  {.experimental: "strictFuncs".}

  proc mutate(value: var NodeIdx; sizeIncreaseHint: int; enforceChanges: bool; r: var Rand) =
    repeatMutate(mutateEnum(value.int, MaxNodes, r).NodeIdx)

  proc mutate[T](value: var seq[Node[T]]; sizeIncreaseHint: int; enforceChanges: bool; r: var Rand) =
    repeatMutateInplace(mutateSeq(value, tmp, MaxNodes, sizeIncreaseHint, r))

  proc mutate(value: var seq[NodeIdx]; sizeIncreaseHint: int; enforceChanges: bool; r: var Rand) =
    repeatMutateInplace(mutateSeq(value, tmp, MaxEdges, sizeIncreaseHint, r))

  proc postProcess[T: SomeNumber](x: var seq[Node[T]]; r: var Rand) =
    for n in x.mitems:
      var i = 0
      while i <= n.edges.high:
        if n.edges[i].int >= x.len:
          delete(n.edges, i)
        else: inc i

  func fuzzTarget(x: Graph[int8]) =
    when defined(dumpFuzzInput): debugEcho(x)
    if x.len > 0:
      let nodesExplored = breadthFirstSearch(x, `from` = 0)
      assert nodesExplored[0] == 0.NodeIdx

  defaultMutator(fuzzTarget)
