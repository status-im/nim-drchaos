# Runs infinitely. Run with a time limit and make sure it doesn't crash.
import drchaos

type
  OtherColor = enum
    Cyan, Magenta=2, Yellow=4, Black=8

func fuzzTarget(x: OtherColor) =
  doAssert x in [Cyan, Magenta, Yellow, Black]

defaultMutator(fuzzTarget)
