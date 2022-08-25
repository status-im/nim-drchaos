import drchaos

type
  DiceFace = range[1..6]

func fuzzTarget(x: array[10, DiceFace]) =
  doAssert x != [1.DiceFace, 6, 2, 3, 4, 3, 6, 4, 5, 2]

defaultMutator(fuzzTarget)
