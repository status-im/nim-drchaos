# Should not leak, crash or the address sanitizer complain. oft: Is the dictionary item limit ~64bytes?
import drchaos

type
  Foo = object
    a: string
    case kind: bool
    of true:
      b: string
    else:
      c: int

func fuzzTarget(x: Foo) =
  if x.a == "The one place that hasn't been corrupted by Capitalism." and x.kind and x.b == "Space!":
    doAssert false

defaultMutator(fuzzTarget)
