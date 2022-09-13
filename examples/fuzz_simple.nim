import drchaos

type
  SampleStruct[T, U] = object
    x: T
    y: U

  SampleEnum = enum
    A, B, C

  SampleCase = object
    case kind: SampleEnum
    of A: z: string
    of B: discard
    of C: x, y: bool

func `==`(a, b: SampleCase): bool =
  if a.kind != b.kind: return false
  case a.kind
  of A: return a.z == b.z
  of B: return true
  of C: return a.x == b.x and a.y == b.y

func fuzzTarget(xs: seq[SampleStruct[uint8, SampleCase]]) =
  if xs.len > 3 and
      xs[0].x == 100 and xs[0].y.kind == C and (xs[0].y.x == false and xs[0].y.y == true) and
      xs[1].x == 55 and xs[1].y.kind == C and (xs[1].y.x == true and xs[1].y.y == false) and
      xs[2].x == 87 and xs[2].y.kind == C and (xs[2].y.x == false and xs[2].y.y == false) and
      xs[3].x == 24 and xs[3].y.kind == C and (xs[3].y.x == true and xs[3].y.y == true):
    doAssert false

defaultMutator(fuzzTarget)
