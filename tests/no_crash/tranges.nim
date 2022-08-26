# Should run indefinitely.
import drchaos

func fuzzTarget(x: Natural) =
  doAssert x >= 0 and x <= high(int)

defaultMutator(fuzzTarget)
