import drchaos/mutator, std/random

const
  MaxFaces = 6

type
  DiceFace = distinct int #range[1..6]

proc `==`(a, b: DiceFace): bool {.borrow.}

proc mutate(value: var DiceFace; sizeIncreaseHint: int; enforceChanges: bool; r: var Rand) =
  repeatMutate(DiceFace(mutateEnum(value.int, MaxFaces, r)+1))

func fuzzTarget(x: array[10, DiceFace]) =
  doAssert x != array[10, DiceFace]([1, 6, 2, 3, 4, 3, 6, 4, 5, 2])

defaultMutator(fuzzTarget)
