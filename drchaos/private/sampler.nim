import std/random

type
  Sampler*[T] = object
    selected: T
    totalWeight: int

proc pick*[T](s: var Sampler[T], r: var Rand; weight: Natural): bool =
  if weight == 0: return false
  s.totalWeight += weight
  weight == s.totalWeight or r.rand(1..s.totalWeight) <= weight

proc attempt*[T](s: var Sampler[T], r: var Rand; weight: Natural; item: sink T) =
  if pick(s, r, weight): s.selected = item

proc selected*[T](s: Sampler[T]): lent T = s.selected
proc isEmpty*[T](s: Sampler[T]): bool {.inline.} = s.totalWeight == 0

when isMainModule:
  import math

  const
    Runs = 1000000
    Tests = [
      @[1],
      @[1, 1, 1],
      @[1, 1, 0],
      @[1, 10, 100],
      @[100, 1, 10],
      @[1, 10000, 10000],
      @[1, 3, 7, 100, 105],
      @[93519, 52999, 354, 37837, 55285,
        31787, 89096, 55695, 1587, 18233, 77557, 67632, 59348, 51250, 17417, 96856, 78568,
        44296, 70170, 41328, 9206, 90187, 54086, 35602, 53167, 33791, 60118, 52962, 10327,
        80513, 49526, 18326, 83662, 49644, 70903, 4910, 36309, 19196, 42982, 53316, 14773,
        86607, 60835]
    ]

  proc `=~`(x, y: float): bool = abs(x - y) < 0.01
  proc test(seed: int, weights: seq[int]) =
    var counts = newSeq[int](weights.len)
    var rand = initRand(seed)
    for i in 0 ..< Runs:
      var sampler: Sampler[int]
      for j in 0 ..< weights.len: test(sampler, rand, weights[j], j)
      inc counts[sampler.selected]
    let sum = sum(weights)
    for j in 0 ..< weights.len:
      var expected = weights[j].float
      expected = expected / sum.float
      var actual = counts[j].float
      actual = actual / Runs.float
      assert expected =~ actual

  for i in 0..<Tests.len: test(1, Tests[i])
  for i in 0..<Tests.len: test(4, Tests[i])
  for i in 0..<Tests.len: test(7, Tests[i])
