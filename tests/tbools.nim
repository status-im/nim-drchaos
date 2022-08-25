import drchaos

func fuzzTarget(x: bool) =
  if x == true: doAssert false

defaultMutator(fuzzTarget)
