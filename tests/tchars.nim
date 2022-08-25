import drchaos

func fuzzTarget(x: char) =
  if x == 'a': doAssert false

defaultMutator(fuzzTarget)
