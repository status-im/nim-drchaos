import drchaos

func fuzzTarget(x: seq[bool]) =
  doAssert x != @[true, false, true, true, false, true]

defaultMutator(fuzzTarget)
