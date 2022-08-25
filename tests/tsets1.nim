import drchaos

type
  OtherColor = enum
    Cyan, Magenta=2, Yellow=4, Black=8

func fuzzTarget(x: set[OtherColor]) =
  doAssert x != {Yellow}

defaultMutator(fuzzTarget)
