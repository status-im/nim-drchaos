# WARNING: This mutator crashes for OrderedTable and it's too slow with Table.
# TODO: split into files and make it compile again.
import random
include std/tables

proc firstPositionHidden*[A, B](t: OrderedTable[A, B]): int =
  ## Undocumented API for iteration.
  if t.counter > 0:
    result = t.first
    while result >= 0 and not isFilled(t.data[result].hcode):
      result = t.data[result].next
  else:
    result = -1

proc nextPositionHidden*[A, B](t: OrderedTable[A, B]; current: int): int =
  ## Undocumented API for iteration.
  result = t.data[current].next
  while result >= 0 and not isFilled(t.data[result].hcode):
    result = t.data[result].next

proc nextPositionHidden*[A, B](t: Table[A, B]; current: int): int =
  ## Undocumented API for iteration.
  result = current
  while result >= 0 and not isFilled(t.data[result].hcode):
    inc result
    if result > t.data.high: result = -1

proc positionOfHidden*[A, B](t: OrderedTable[A, B]; index: int): int =
  var index = index
  result = firstPositionHidden(t)
  while result >= 0 and index > 0:
    result = t.nextPositionHidden(result)
    dec index

proc positionOfHidden*[A, B](t: Table[A, B]; index: int): int =
  var index = index
  result = if t.counter > 0: 0 else: -1
  while result >= 0 and index > 0:
    result = t.nextPositionHidden(result)
    dec index

proc keyAtHidden*[A, B](t: (Table[A, B]|OrderedTable[A, B]); current: int): lent A {.inline.} =
  ## Undocumented API for iteration.
  result = t.data[current].key

proc keyAtHidden*[A, B](t: var (Table[A, B]|OrderedTable[A, B]); current: int): var A {.inline.} =
  ## Undocumented API for iteration.
  result = t.data[current].key

proc newInput*[T](sizeIncreaseHint: int; r: var Rand): T = discard
proc runMutator*[T](x: var T; sizeIncreaseHint: int; enforceChanges: bool; r: var Rand) = discard

proc mutateTab*[A, B](value: var (Table[A, B]|OrderedTable[A, B]); previous: OrderedTable[A, B];
    userMax, sizeIncreaseHint: int; r: var Rand): bool =
  let previousSize = previous.byteSize
  while value.len > 0 and r.rand(bool):
    let pos = positionOfHidden(value, rand(r, value.len-1))
    assert pos >= 0
    value.del(value.keyAtHidden(pos))
  var currentSize = value.byteSize
  template remainingSize: untyped = sizeIncreaseHint-currentSize+previousSize
  while value.len < userMax and remainingSize > 0 and r.rand(bool):
    let key = newInput[A](remainingSize, r)
    value[key] = newInput[B](remainingSize-key.byteSize, r)
    currentSize = value.byteSize
  if value != previous:
    return true
  elif value.len == 0:
    let key = newInput[A](remainingSize, r)
    value[key] = newInput[B](remainingSize-key.byteSize, r)
  else:
    let pos = positionOfHidden(value, rand(r, value.len-1))
    assert pos >= 0
    runMutator(value.keyAtHidden(pos), remainingSize, true, r)
  result = value != previous
