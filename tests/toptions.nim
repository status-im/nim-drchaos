import drchaos, std/options

func fuzzTarget(x: Option[string]) =
  doAssert not x.isSome or x.get != "Space!"

defaultMutator(fuzzTarget)
