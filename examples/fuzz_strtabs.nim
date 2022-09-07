import drchaos/mutator, std/[strtabs, random]

proc mutate(data: var StringTableRef; sizeIncreaseHint: int; enforceChanges: bool; r: var Rand) =
  var value: seq[tuple[key, value: string]]
  for p in pairs(data):
    value.add p
  repeatMutateInplace(mutateSeq(value, tmp, 2, sizeIncreaseHint, r))
  clear(data)
  for key, val in value.items:
    data[key] = val

proc mutate(value: var string; sizeIncreaseHint: int; enforceChanges: bool; r: var Rand) =
  repeatMutate(mutateUtf8String(move value, 4, sizeIncreaseHint, r))

proc default(_: typedesc[StringTableRef]): StringTableRef =
  newStringTable(modeCaseSensitive)

func fuzzTarget(x: StringTableRef) =
  doAssert x != {"key1": "val1", "key2": "val2"}.newStringTable

defaultMutator(fuzzTarget)
