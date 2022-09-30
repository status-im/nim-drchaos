import drchaos/mutator, std/random

type
  DiceFace = distinct int

const
  df1 = 0.DiceFace
  df2 = 2.DiceFace
  df3 = 4.DiceFace
  df4 = 8.DiceFace
  df5 = 16.DiceFace
  df6 = 32.DiceFace

proc `==`(a, b: DiceFace): bool {.borrow.}

proc mutate(value: var DiceFace; sizeIncreaseHint: int; enforceChanges: bool; r: var Rand) =
  repeatMutate(r.sample([df1, df2, df3, df4, df5, df6]))

func fuzzTarget(x: array[10, DiceFace]) =
  doAssert x != [df1, df6, df2, df3, df4, df3, df6, df4, df5, df2]

defaultMutator(fuzzTarget)
