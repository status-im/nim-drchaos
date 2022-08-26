# Runs infinitely. Run with a time limit and make sure it doesn't crash.
import drchaos

type
  Color = enum
    Red, Green, Blue
  OtherColor = enum
    Cyan, Magenta=2, Yellow=4, Black=8

func fuzzTarget(x: Color) =
  doAssert x.ord in low(Color).ord..high(Color).ord
  #doAssert x in [Cyan, Magenta, Yellow, Black]

defaultMutator(fuzzTarget)
