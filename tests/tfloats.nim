import drchaos

func fuzzTarget(x: float32) =
  doAssert x <= 100

defaultMutator(fuzzTarget)
