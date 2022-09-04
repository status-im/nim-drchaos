import drchaos/[common, mutator], std/random

type
  Matrix32[M, N: static[int]] = object
    data: ptr UncheckedArray[float32]

template createData(size): untyped =
  when compileOption("threads"):
    cast[ptr UncheckedArray[float32]](allocShared(size * sizeof(float32)))
  else:
    cast[ptr UncheckedArray[float32]](alloc(size * sizeof(float32)))

proc `=destroy`[M, N: static[int]](m: var Matrix32[M, N]) =
  if m.data != nil:
    when compileOption("threads"):
      deallocShared(m.data)
    else:
      dealloc(m.data)

proc `=copy`[M, N: static[int]](a: var Matrix32[M, N]; b: Matrix32[M, N]) =
  if a.data != b.data:
    `=destroy`(a)
    wasMoved(a)
    if b.data != nil:
      a.data = createData(M * N)
      copyMem(a.data, b.data, M * N * sizeof(float32))

proc matrix32[M, N: static[int]](s: float32): Matrix32[M, N] =
  ## Construct an m-by-n constant Matrix32.
  result.data = createData(M * N)
  for i in 0 ..< (M * N):
    result.data[i] = s

proc default[M, N: static[int]](_: typedesc[Matrix32[M, N]]): Matrix32[M, N] =
  matrix32[M, N](0'f32)

proc ones(M, N: static[int]): Matrix32[M, N] = matrix32[M, N](1'f32)

proc `==`[M, N: static[int]](a, b: Matrix32[M, N]): bool =
  if a.data == nil or b.data == nil: return false
  if a.data != b.data:
    for i in 0 ..< (M * N):
      if a.data[i] != b.data[i]:
        return false
  return true

proc byteSize[M, N: static[int]](x: Matrix32[M, N]): int {.inline.} =
  result = M * N * sizeof(float32)

proc fromData[M, N: static[int]](data: openArray[byte]; pos: var int; output: var Matrix32[M, N]) =
  output.data = createData(M * N)
  let bLen = output.byteSize
  if readData(data, pos, output.data, bLen) != bLen:
    raiseDecoding()

proc toData[M, N: static[int]](data: var openArray[byte]; pos: var int; input: Matrix32[M, N]) =
  writeData(data, pos, input.data, input.byteSize)

template `+!`(p: pointer, s: int): untyped =
  cast[pointer](cast[ByteAddress](p) +% s)

proc mutateMatrix32[M, N: static[int]](value: sink Matrix32[M, N]; r: var Rand): Matrix32[M, N] =
  result = value
  if result.data == nil: result = default(Matrix32[M, N])
  let size = mutate(cast[ptr UncheckedArray[byte]](result.data), result.byteSize, result.byteSize)
  zeroMem(result.data +! size, result.byteSize - size)

proc mutate[M, N: static[int]](value: var Matrix32[M, N]; sizeIncreaseHint: int; enforceChanges: bool; r: var Rand) =
  repeatMutate(mutateMatrix32(move value, r))

func fuzzTarget(x: Matrix32[3, 2]) =
  let data = ones(3, 2)
  doAssert x != data

defaultMutator(fuzzTarget)
