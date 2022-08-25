import drchaos

func fuzzTarget(x: string) =
  doAssert x != "The one place that hasn't been corrupted by Capitalism."

defaultMutator(fuzzTarget)
