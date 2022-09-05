# Code excerpt from https://github.com/andreaferretti/linear-algebra
type
  Matrix32*[M, N: static[int]] = object
    order: OrderType
    data: ref array[N * M, float32]

  OrderType* {.size: sizeof(int).} = enum
    rowMajor = 101, colMajor = 102

template elem(m, i, j: untyped): untyped =
  if m.order == colMajor: m.data[j * m.M + i]
  else: m.data[i * m.N + j]

template slowEqPrivate(m, n: untyped) =
  if m.M != n.M or m.N != n.N:
    return false
  for i in 0 ..< m.M:
    for j in 0 ..< m.N:
      if elem(m, i, j) != elem(n, i, j):
        return false
  return true

proc slowEq[M, N: static[int]](m, n: Matrix32[M, N]): bool = slowEqPrivate(m, n)

proc `==`*(m, n: Matrix32): bool =
  if m.order == n.order: m.data[] == n.data[]
  elif m.order == colMajor: slowEq(m, n)
  else: slowEq(n, m)

template constantSMatrixPrivate(M, N, x, order, result: untyped) =
  new result.data
  result.order = order
  for i in 0 ..< (M * N):
    result.data[i] = x

proc constantSMatrix(M, N: static[int], x: float32, order: OrderType = colMajor): Matrix32[M, N] =
  constantSMatrixPrivate(M, N, x, order, result)

proc zeros*(M, N: static[int], A: typedesc[float32], order: OrderType = colMajor): Matrix32[M, N] =
  constantSMatrix(M, N, 0'f32, order)

proc eye*(N: static[int], A: typedesc[float32], order: OrderType = colMajor): Matrix32[N, N] =
  result = zeros(N, N, float32, order)
  for i in 0 ..< N:
    result.data[i + N * i] = 1'f32

import drchaos

proc default[M, N: static[int]](_: typedesc[Matrix32[M, N]]): Matrix32[M, N] =
  zeros(M, N, float32)

proc default(_: typedesc[OrderType]): OrderType =
  colMajor

proc default[M, N: static[int]](_: typedesc[ref array[N * M, float32]]): ref array[N * M, float32] =
  new result

func fuzzTarget(x: Matrix32[2, 2]) =
  doAssert x != eye(2, float32)

defaultMutator(fuzzTarget)
