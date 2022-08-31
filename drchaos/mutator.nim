import std/[random, macros, setutils, enumutils, typetraits, options]
import common, private/[sampler, utf8fix]

when (NimMajor, NimMinor, NimPatch) < (1, 7, 1):
  proc rand*[T: Ordinal](r: var Rand; t: typedesc[T]): T =
    when T is range or T is enum:
      result = rand(r, low(T)..high(T))
    elif T is bool:
      result = cast[int64](r.next) < 0
    else:
      result = cast[T](r.next shr (sizeof(uint64) - sizeof(T))*8)

when not defined(fuzzerStandalone):
  proc mutate(data: ptr UncheckedArray[byte], len, maxLen: int): int {.
      importc: "LLVMFuzzerMutate".}

template `+!`(p: pointer, s: int): untyped =
  cast[pointer](cast[ByteAddress](p) +% s)

const
  RandomToDefaultRatio = 100 # The chance of returning an uninitalized type.
  DefaultMutateWeight = 1_000_000 # The default weight of items sampled by the reservoir sampler.
  MaxInitializeDepth = 200 # The post-processor prunes nested non-copyMem types.

type
  ByteSized* = int8|uint8|byte|bool|char # Run LibFuzzer's mutate for sequences of these types.
  PostProcessTypes* = (object|tuple|ref|seq|string|array|set|distinct) ## The post-processor runs only on these types.

proc runMutator*[T: SomeNumber](x: var T; sizeIncreaseHint: int; enforceChanges: bool; r: var Rand)
proc runMutator*[T](x: var seq[T]; sizeIncreaseHint: int; enforceChanges: bool; r: var Rand)
proc runMutator*(x: var bool; sizeIncreaseHint: int; enforceChanges: bool; r: var Rand)
proc runMutator*(x: var char; sizeIncreaseHint: int; enforceChanges: bool; r: var Rand)
proc runMutator*[T: enum](x: var T; sizeIncreaseHint: int; enforceChanges: bool; r: var Rand)
proc runMutator*[T](x: var set[T]; sizeIncreaseHint: int; enforceChanges: bool; r: var Rand)
proc runMutator*(x: var string; sizeIncreaseHint: int; enforceChanges: bool; r: var Rand)
proc runMutator*[T: tuple|object](x: var T; sizeIncreaseHint: int; enforceChanges: bool; r: var Rand)
proc runMutator*[T](x: var ref T; sizeIncreaseHint: int; enforceChanges: bool; r: var Rand)
proc runMutator*[S, T](x: var array[S, T]; sizeIncreaseHint: int; enforceChanges: bool; r: var Rand)

when defined(fuzzerStandalone):
  proc flipBit*(bytes: ptr UncheckedArray[byte]; len: int; r: var Rand) =
    ## Flips random bit in the buffer.
    let bit = rand(r, len * 8 - 1)
    bytes[bit div 8] = bytes[bit div 8] xor (1'u8 shl (bit mod 8))

  proc flipBit*[T](value: T; r: var Rand): T =
    ## Flips random bit in the value.
    result = value
    flipBit(cast[ptr UncheckedArray[byte]](addr result), sizeof(T), r)

  proc mutateValue*[T](value: T; r: var Rand): T =
    flipBit(value, r)
else:
  proc mutateValue*[T](value: T; r: var Rand): T =
    result = value
    let size = mutate(cast[ptr UncheckedArray[byte]](addr result), sizeof(T), sizeof(T))
    zeroMem(result.addr +! size, sizeof(T) - size)

proc mutateEnum*(index, itemCount: int; r: var Rand): int =
  if itemCount <= 1: 0
  else: (index + 1 + r.rand(itemCount - 1)) mod itemCount

proc newInput*[T](sizeIncreaseHint: Natural; r: var Rand): T =
  ## Creates new input with a chance of returning default(T).
  runMutator(result, sizeIncreaseHint, false, r)

proc mutateSeq*[T](value: var seq[T]; previous: seq[T]; userMax, sizeIncreaseHint: int;
    r: var Rand): bool =
  let previousSize = previous.byteSize
  while value.len > 0 and r.rand(bool):
    value.delete(rand(r, value.high))
  var currentSize = value.byteSize
  template remainingSize: untyped = sizeIncreaseHint-currentSize+previousSize
  while value.len < userMax and remainingSize > 0 and r.rand(bool):
    let index = rand(r, value.len)
    value.insert(newInput[T](remainingSize, r), index)
    currentSize = value.byteSize
  if value != previous:
    result = true
  elif value.len == 0:
    value.add(newInput[T](remainingSize, r))
    result = true
  else:
    let index = rand(r, value.high)
    runMutator(value[index], remainingSize, true, r)
    result = value != previous # runMutator item may still fail to generate a new mutation.

when defined(fuzzerStandalone):
  proc delete(x: var string, i: Natural) {.noSideEffect.} =
    let xl = x.len
    for j in i.int..xl-2: x[j] = x[j+1]
    setLen(x, xl-1)

  proc insert(x: var string, item: char, i = 0.Natural) {.noSideEffect.} =
    let xl = x.len
    setLen(x, xl+1)
    var j = xl-1
    while j >= i:
      x[j+1] = x[j]
      dec(j)
    x[i] = item

  proc mutateString(value: sink string; userMax, sizeIncreaseHint: int; r: var Rand): string =
    result = value
    while result.len != 0 and r.rand(bool):
      result.delete(rand(r, result.high))
    while sizeIncreaseHint > 0 and result.len < sizeIncreaseHint and r.rand(bool):
      let index = rand(r, result.len)
      result.insert(r.rand(char), index)
    if result != value:
      return result
    if result.len == 0:
      result.add(r.rand(char))
      return result
    else:
      flipBit(cast[ptr UncheckedArray[uint8]](addr result[0]), result.len, r)

  proc mutateByteSizedSeq*[T: ByteSized](value: sink seq[T]; userMax, sizeIncreaseHint: int;
      r: var Rand): seq[T] =
    result = value
    while result.len != 0 and r.rand(bool):
      result.delete(rand(r, result.high))
    while sizeIncreaseHint > 0 and result.len < sizeIncreaseHint and r.rand(bool):
      let index = rand(r, result.len)
      result.insert(r.rand(T), index)
    if result != value:
      return result
    if result.len == 0:
      result.add(r.rand(T))
      return result
    else:
      flipBit(cast[ptr UncheckedArray[uint8]](addr result[0]), result.len, r)
      when T is bool:
        # Fix bool values so UBSan stops complaining.
        for i in 0..<result.len: result[i] = cast[seq[byte]](result)[i] != 0.byte
      elif T is range:
        for i in 0..<result.len: result[i] = clamp(result[i], low(T), high(T))
else:
  proc mutateByteSizedSeq*[T: ByteSized](value: sink seq[T]; userMax, sizeIncreaseHint: int;
      r: var Rand): seq[T] =
    if r.rand(0..20) == 0:
      result = @[]
    else:
      let oldSize = value.len
      result = value
      result.setLen(max(1, oldSize + r.rand(sizeIncreaseHint)))
      result.setLen(mutate(cast[ptr UncheckedArray[byte]](addr result[0]), oldSize, result.len))
      when T is bool:
        # Fix bool values so UBSan stops complaining.
        for i in 0..<result.len: result[i] = cast[seq[byte]](result)[i] != 0.byte
      elif T is range:
        for i in 0..<result.len: result[i] = clamp(result[i], low(T), high(T))

  proc mutateString*(value: sink string; userMax, sizeIncreaseHint: int; r: var Rand): string =
    if r.rand(0..20) == 0:
      result = ""
    else:
      let oldSize = value.len
      result = value
      result.setLen(max(1, oldSize + r.rand(sizeIncreaseHint)))
      result.setLen(mutate(cast[ptr UncheckedArray[byte]](addr result[0]), oldSize, result.len))

proc mutateUtf8String*(value: sink string; userMax, sizeIncreaseHint: int; r: var Rand): string {.inline.} =
  result = mutateString(value, userMax, sizeIncreaseHint, r)
  fixUtf8(result, r)

proc mutateArray*[S, T](value: array[S, T]; r: var Rand): array[S, T] {.inline.} =
  result = mutateValue(value, r)
  when T is bool:
    for i in low(result)..high(result): result[i] = cast[array[S, byte]](result)[i] != 0.byte
  elif T is range:
    for i in low(result)..high(result): result[i] = clamp(result[i], low(T), high(T))

template repeatMutate*(call: untyped) =
  if not enforceChanges and rand(r, RandomToDefaultRatio - 1) == 0:
    discard
  else:
    var tmp = value
    for i in 1..10:
      value = call
      if not enforceChanges or value != tmp: return

template repeatMutateInplace*(call: untyped) =
  if not enforceChanges and rand(r, RandomToDefaultRatio - 1) == 0:
    discard
  else:
    var tmp {.inject.} = value
    for i in 1..10:
      let notEqual = call
      if not enforceChanges or notEqual: return

proc mutate*(value: var bool; sizeIncreaseHint: int; enforceChanges: bool; r: var Rand) =
  value = not value

proc mutate*(value: var char; sizeIncreaseHint: int; enforceChanges: bool; r: var Rand) =
  repeatMutate(mutateValue(value, r))

proc mutate*[T: range](value: var T; sizeIncreaseHint: int; enforceChanges: bool; r: var Rand) =
  repeatMutate(clamp(mutateValue(value, r), low(T), high(T)))

proc mutate*[T](value: var set[T]; sizeIncreaseHint: int; enforceChanges: bool; r: var Rand) =
  repeatMutate(mutateValue(value, r) * fullSet(T))

macro enumFullRange(a: typed): untyped =
  nnkBracket.newTree(a.getType[1][1..^1])

proc mutate*[T: HoleyEnum](value: var T; sizeIncreaseHint: int; enforceChanges: bool; r: var Rand) =
  repeatMutate(enumFullRange(T)[mutateEnum(value.symbolRank, enumLen(T), r)])

proc mutate*[T: OrdinalEnum](value: var T; sizeIncreaseHint: int; enforceChanges: bool; r: var Rand) =
  repeatMutate(T(mutateEnum(value.symbolRank, enumLen(T), r)+low(T).ord))

proc mutate*[T: SomeNumber](value: var T; sizeIncreaseHint: int; enforceChanges: bool; r: var Rand) =
  repeatMutate(mutateValue(value, r))

proc mutate*[T: not ByteSized](value: var seq[T]; sizeIncreaseHint: int; enforceChanges: bool; r: var Rand) =
  repeatMutateInplace(mutateSeq(value, tmp, high(int), sizeIncreaseHint, r))

proc mutate*[T: ByteSized](value: var seq[T]; sizeIncreaseHint: int; enforceChanges: bool; r: var Rand) =
  repeatMutate(mutateByteSizedSeq(move value, high(int), sizeIncreaseHint, r))

proc mutate*(value: var string; sizeIncreaseHint: int; enforceChanges: bool; r: var Rand) =
  when defined(fuzzerUtf8Strings):
    repeatMutate(mutateUtf8String(move value, high(int), sizeIncreaseHint, r))
  else:
    repeatMutate(mutateString(move value, high(int), sizeIncreaseHint, r))

proc mutate*[S; T: SomeNumber|bool|char](value: var array[S, T]; sizeIncreaseHint: int;
    enforceChanges: bool; r: var Rand) =
  repeatMutate(mutateArray(value, r))

proc mutate*[T](value: var Option[T]; sizeIncreaseHint: int; enforceChanges: bool; r: var Rand) =
  if not enforceChanges and rand(r, RandomToDefaultRatio - 1) == 0:
    discard
  else:
    if not isSome(value):
      value = some(default(T))
    runMutator(value.get, sizeIncreaseHint, enforceChanges, r)

template sampleAttempt(call: untyped) =
  inc res
  call

proc sample[T: distinct](x: T; s: var Sampler; r: var Rand; res: var int) =
  when compiles(mutate(x, 0, false, r)):
    sampleAttempt(attempt(s, r, DefaultMutateWeight, res))
  else:
    sample(x.distinctBase, s, r, res)

proc sample(x: bool; s: var Sampler; r: var Rand; res: var int) =
  sampleAttempt(attempt(s, r, DefaultMutateWeight, res))

proc sample(x: char; s: var Sampler; r: var Rand; res: var int) =
  sampleAttempt(attempt(s, r, DefaultMutateWeight, res))

proc sample[T: enum](x: T; s: var Sampler; r: var Rand; res: var int) =
  sampleAttempt(attempt(s, r, DefaultMutateWeight, res))

proc sample[T](x: set[T]; s: var Sampler; r: var Rand; res: var int) =
  sampleAttempt(attempt(s, r, DefaultMutateWeight, res))

proc sample[T: SomeNumber](x: T; s: var Sampler; r: var Rand; res: var int) =
  sampleAttempt(attempt(s, r, DefaultMutateWeight, res))

proc sample[T](x: seq[T]; s: var Sampler; r: var Rand; res: var int) =
  sampleAttempt(attempt(s, r, DefaultMutateWeight, res))

proc sample(x: string; s: var Sampler; r: var Rand; res: var int) =
  sampleAttempt(attempt(s, r, DefaultMutateWeight, res))

proc sample[T: tuple|object](x: T; s: var Sampler; r: var Rand; res: var int) =
  when compiles(mutate(x, 0, false, r)):
    sampleAttempt(attempt(s, r, DefaultMutateWeight, res))
  else:
    for v in fields(x):
      sample(v, s, r, res)

proc sample[T](x: ref T; s: var Sampler; r: var Rand; res: var int) =
  when compiles(mutate(x, 0, false, r)):
    sampleAttempt(attempt(s, r, DefaultMutateWeight, res))
  else:
    if x != nil: sample(x[], s, r, res)

proc sample[S, T](x: array[S, T]; s: var Sampler; r: var Rand; res: var int) =
  when compiles(mutate(x, 0, false, r)):
    sampleAttempt(attempt(s, r, DefaultMutateWeight, res))
  else:
    for i in low(x)..high(x):
      sample(x[i], s, r, res)

template pickMutate(call: untyped) =
  if res > 0:
    dec res
    if res == 0:
      call

proc pick[T: distinct](x: var T; sizeIncreaseHint: int; enforceChanges: bool;
    r: var Rand; res: var int) =
  when compiles(mutate(x, sizeIncreaseHint, enforceChanges, r)):
    pickMutate(mutate(x, sizeIncreaseHint, enforceChanges, r))
  else:
    pick(x.distinctBase, sizeIncreaseHint, enforceChanges, r, res)

proc pick(x: var bool; sizeIncreaseHint: int; enforceChanges: bool;
    r: var Rand; res: var int) =
  pickMutate(mutate(x, sizeIncreaseHint, enforceChanges, r))

proc pick(x: var char; sizeIncreaseHint: int; enforceChanges: bool;
    r: var Rand; res: var int) =
  pickMutate(mutate(x, sizeIncreaseHint, enforceChanges, r))

proc pick[T: enum](x: var T; sizeIncreaseHint: int; enforceChanges: bool;
    r: var Rand; res: var int) =
  pickMutate(mutate(x, sizeIncreaseHint, enforceChanges, r))

proc pick[T](x: var set[T]; sizeIncreaseHint: int; enforceChanges: bool;
    r: var Rand; res: var int) =
  pickMutate(mutate(x, sizeIncreaseHint, enforceChanges, r))

proc pick[T: SomeNumber](x: var T; sizeIncreaseHint: int; enforceChanges: bool;
    r: var Rand; res: var int) =
  pickMutate(mutate(x, sizeIncreaseHint, enforceChanges, r))

proc pick[T](x: var seq[T]; sizeIncreaseHint: int; enforceChanges: bool; r: var Rand;
    res: var int) =
  pickMutate(mutate(x, sizeIncreaseHint, enforceChanges, r))

proc pick(x: var string; sizeIncreaseHint: int; enforceChanges: bool; r: var Rand;
    res: var int) =
  pickMutate(mutate(x, sizeIncreaseHint, enforceChanges, r))

proc pick[T: tuple](x: var T; sizeIncreaseHint: int; enforceChanges: bool;
    r: var Rand; res: var int) =
  when compiles(mutate(x, sizeIncreaseHint, enforceChanges, r)):
    pickMutate(mutate(x, sizeIncreaseHint, enforceChanges, r))
  else:
    for v in fields(x):
      pick(v, sizeIncreaseHint, enforceChanges, r, res)

proc pick[T: object](x: var T; sizeIncreaseHint: int; enforceChanges: bool;
    r: var Rand; res: var int) =
  when compiles(mutate(x, sizeIncreaseHint, enforceChanges, r)):
    pickMutate(mutate(x, sizeIncreaseHint, enforceChanges, r))
  else:
    template pickImpl(x: untyped) =
      pick(x, sizeIncreaseHint, enforceChanges, r, res)
    assignObjectImpl(x, pickImpl)

proc pick[T](x: var ref T; sizeIncreaseHint: int; enforceChanges: bool;
    r: var Rand; res: var int) =
  when compiles(mutate(x, sizeIncreaseHint, enforceChanges, r)):
    pickMutate(mutate(x, sizeIncreaseHint, enforceChanges, r))
  else:
    if x != nil: pick(x[], sizeIncreaseHint, enforceChanges, r, res)

proc pick[S, T](x: var array[S, T]; sizeIncreaseHint: int; enforceChanges: bool;
    r: var Rand; res: var int) =
  when compiles(mutate(x, sizeIncreaseHint, enforceChanges, r)):
    pickMutate(mutate(x, sizeIncreaseHint, enforceChanges, r))
  else:
    for i in low(x)..high(x):
      pick(x[i], sizeIncreaseHint, enforceChanges, r, res)

proc runMutator*[T: distinct](x: var T; sizeIncreaseHint: int; enforceChanges: bool; r: var Rand) =
  when compiles(mutate(x, sizeIncreaseHint, enforceChanges, r)):
    mutate(x, sizeIncreaseHint, enforceChanges, r)
  else:
    runMutator(x.distinctBase, sizeIncreaseHint, enforceChanges, r)

proc runMutator*[T: SomeNumber](x: var T; sizeIncreaseHint: int; enforceChanges: bool; r: var Rand) =
  mutate(x, sizeIncreaseHint, enforceChanges, r)

proc runMutator*[T](x: var seq[T]; sizeIncreaseHint: int; enforceChanges: bool; r: var Rand) =
  mutate(x, sizeIncreaseHint, enforceChanges, r)

proc runMutator*(x: var string; sizeIncreaseHint: int; enforceChanges: bool; r: var Rand) =
  mutate(x, sizeIncreaseHint, enforceChanges, r)

proc runMutator*(x: var bool; sizeIncreaseHint: int; enforceChanges: bool; r: var Rand) =
  mutate(x, sizeIncreaseHint, enforceChanges, r)

proc runMutator*(x: var char; sizeIncreaseHint: int; enforceChanges: bool; r: var Rand) =
  mutate(x, sizeIncreaseHint, enforceChanges, r)

proc runMutator*[T: enum](x: var T; sizeIncreaseHint: int; enforceChanges: bool; r: var Rand) =
  mutate(x, sizeIncreaseHint, enforceChanges, r)

proc runMutator*[T](x: var set[T]; sizeIncreaseHint: int; enforceChanges: bool; r: var Rand) =
  mutate(x, sizeIncreaseHint, enforceChanges, r)

proc runMutator*[T: tuple|object](x: var T; sizeIncreaseHint: int; enforceChanges: bool; r: var Rand) =
  when compiles(mutate(x, sizeIncreaseHint, enforceChanges, r)):
    mutate(x, sizeIncreaseHint, enforceChanges, r)
  else:
    if not enforceChanges and rand(r, RandomToDefaultRatio - 1) == 0:
      discard
    else:
      var res = 0
      var s: Sampler[int]
      sample(x, s, r, res)
      res = s.selected
      pick(x, sizeIncreaseHint, enforceChanges, r, res)

proc runMutator*[T](x: var ref T; sizeIncreaseHint: int; enforceChanges: bool; r: var Rand) =
  when compiles(mutate(x, sizeIncreaseHint, enforceChanges, r)):
    mutate(x, sizeIncreaseHint, enforceChanges, r)
  else:
    if not enforceChanges and rand(r, RandomToDefaultRatio - 1) == 0:
      discard
    else:
      if x == nil: new(x)
      runMutator(x[], sizeIncreaseHint, enforceChanges, r)

proc runMutator*[S, T](x: var array[S, T]; sizeIncreaseHint: int; enforceChanges: bool; r: var Rand) =
  when compiles(mutate(x, sizeIncreaseHint, enforceChanges, r)):
    mutate(x, sizeIncreaseHint, enforceChanges, r)
  else:
    if not enforceChanges and rand(r, RandomToDefaultRatio - 1) == 0:
      discard
    else:
      var res = 0
      var s: Sampler[int]
      sample(x, s, r, res)
      res = s.selected
      pick(x, sizeIncreaseHint, enforceChanges, r, res)

proc runPostProcessor*(x: var string, depth: int; r: var Rand)
proc runPostProcessor*[T](x: var seq[T], depth: int; r: var Rand)
proc runPostProcessor*[T](x: var set[T], depth: int; r: var Rand)
proc runPostProcessor*[T: tuple](x: var T, depth: int; r: var Rand)
proc runPostProcessor*[T: object](x: var T, depth: int; r: var Rand)
proc runPostProcessor*[T](x: var ref T, depth: int; r: var Rand)
proc runPostProcessor*[S, T](x: var array[S, T], depth: int; r: var Rand)

proc runPostProcessor*[T: distinct](x: var T, depth: int; r: var Rand) =
  # Allow post-processor functions for all distinct types.
  when compiles(postProcess(x, r)):
    if depth < 0:
      when not supportsCopyMem(T): reset(x)
    else:
      postProcess(x, r)
  else:
    when x.distinctBase is PostProcessTypes:
      runPostProcessor(x.distinctBase, depth-1, r)

proc runPostProcessor*(x: var string, depth: int; r: var Rand) =
  if depth < 0:
    reset(x)
  else:
    when compiles(postProcess(x, r)):
      postProcess(x, r)

proc runPostProcessor*[T](x: var seq[T], depth: int; r: var Rand) =
  if depth < 0:
    reset(x)
  else:
    when compiles(postProcess(x, r)):
      postProcess(x, r)
    else:
      when T is PostProcessTypes:
        for i in 0..<x.len:
          runPostProcessor(x[i], depth-1, r)

proc runPostProcessor*[T](x: var set[T], depth: int; r: var Rand) =
  when compiles(postProcess(x, r)):
    if depth >= 0:
      postProcess(x, r)

proc runPostProcessor*[T: tuple](x: var T, depth: int; r: var Rand) =
  if depth < 0:
    when not supportsCopyMem(T): reset(x)
  else:
    when compiles(postProcess(x, r)):
      postProcess(x, r)
    else:
      for v in fields(x):
        when typeof(v) is PostProcessTypes:
          runPostProcessor(v, depth-1, r)

proc runPostProcessor*[T: object](x: var T, depth: int; r: var Rand) =
  if depth < 0:
    when not supportsCopyMem(T): reset(x)
  else:
    when compiles(postProcess(x, r)):
      postProcess(x, r)
    # When there is a user-provided mutator, don't touch private fields.
    elif compiles(mutate(x, 0, false, r)):
      # Guess how to traverse a data structure, if it's even one.
      when compiles(for v in mitems(x): discard):
        # Run the post-processor only for compatible types as there is an overhead.
        when typeof(for v in mitems(x): v) is PostProcessTypes:
          for v in mitems(x):
            runPostProcessor(v, depth-1, r)
      elif compiles(for k, v in mpairs(x): discard):
        when typeof(for k, v in mpairs(x): v) is PostProcessTypes:
          for k, v in mpairs(x):
            runPostProcessor(v, depth-1, r)
    else:
      template runPostProcessorImpl(x: untyped) =
        when typeof(x) is PostProcessTypes:
          runPostProcessor(x, depth-1, r)
      assignObjectImpl(x, runPostProcessorImpl)

proc runPostProcessor*[T](x: var ref T, depth: int; r: var Rand) =
  if depth < 0:
    reset(x)
  else:
    when compiles(postProcess(x, r)):
      postProcess(x, r)
    else:
      when T is PostProcessTypes:
        if x != nil: runPostProcessor(x[], depth-1, r)

proc runPostProcessor*[S, T](x: var array[S, T], depth: int; r: var Rand) =
  if depth < 0:
    when not supportsCopyMem(T): reset(x)
  else:
    when compiles(postProcess(x, r)):
      postProcess(x, r)
    else:
      when T is PostProcessTypes:
        for i in low(x)..high(x):
          runPostProcessor(x[i], depth-1, r)

proc myMutator*[T](x: var T; sizeIncreaseHint: Natural; r: var Rand) {.nimcall.} =
  runMutator(x, sizeIncreaseHint, true, r)
  when T is PostProcessTypes:
    runPostProcessor(x, MaxInitializeDepth, r)

template initializeImpl*() =
  proc NimMain() {.importc: "NimMain".}

  proc LLVMFuzzerInitialize(): cint {.exportc.} =
    NimMain()

template mutatorImpl*(target, mutator, typ: untyped) =
  {.pragma: nocov, codegenDecl: "__attribute__((no_sanitize(\"coverage\"))) $# $#$#".}
  {.pragma: nosan, codegenDecl: "__attribute__((disable_sanitizer_instrumentation)) $# $#$#".}

  type
    FuzzTarget = proc (x: typ) {.nimcall, noSideEffect.}
    FuzzMutator = proc (x: var typ; sizeIncreaseHint: Natural, r: var Rand) {.nimcall.}

  var
    buffer: seq[byte] = @[0xf1'u8]
    cached: typ

  proc getInput(x: var typ; data: openArray[byte]): var typ {.nocov, nosan.} =
    if equals(data, buffer):
      result = cached
    else:
      var pos = 1
      fromData(data, pos, x)
      result = x

  proc setInput(x: var typ; data: openArray[byte]; len: int) {.inline.} =
    setLen(buffer, len)
    var pos = 1
    toData(buffer, pos, x)
    assert pos == len
    copyMem(addr data, addr buffer[0], len)
    cached = move x

  proc clearBuffer() {.inline.} =
    setLen(buffer, 1)

  proc testOneInputImpl[T](x: var T; data: openArray[byte]) =
    if data.len > 1: # Ignore '\n' passed by LibFuzzer.
      FuzzTarget(target)(getInput(x, data))

  proc customMutatorImpl(x: var typ; data: openArray[byte]; maxLen: int;
      r: var Rand): int {.nosan.} =
    if data.len > 1:
      #var pos = 1
      #fromData(data, pos, x)
      x = getInput(x, data)
    FuzzMutator(mutator)(x, maxLen-x.byteSize, r)
    result = x.byteSize+1 # +1 for the skipped byte
    if result <= maxLen:
      setInput(x, data, result)
    else:
      clearBuffer()
      result = data.len

  proc LLVMFuzzerTestOneInput(data: ptr UncheckedArray[byte], len: int): cint {.exportc.} =
    result = 0
    try:
      var x: typ
      testOneInputImpl(x, toOpenArray(data, 0, len-1))
    finally:
      # Call Nim's compiler api to report unhandled exceptions. See: Nim#18215
      when compileOption("exceptions", "goto"):
        {.emit: "nimTestErrorFlag();".}

  proc LLVMFuzzerCustomMutator(data: ptr UncheckedArray[byte], len, maxLen: int,
      seed: int64): int {.exportc.} =
    try:
      var r = initRand(seed)
      var x: typ
      result = customMutatorImpl(x, toOpenArray(data, 0, len-1), maxLen, r)
    finally:
      when compileOption("exceptions", "goto"):
        {.emit: "nimTestErrorFlag();".}

proc commonImpl(target, mutator: NimNode): NimNode =
  let typ = getTypeImpl(target).params[^1][1]
  result = getAst(mutatorImpl(target, mutator, typ))
  result.add getAst(initializeImpl())

macro defaultMutator*(target: proc) =
  ## Implements the interface for running LibFuzzer's fuzzing loop, where func `target`'s
  ## single immutatable parameter, is the structured input type.
  ## It uses the default mutator that also includes the post-processor.
  ## It's recommended that the experimental "strict funcs" feature is enabled.
  commonImpl(target, bindSym"myMutator")

macro customMutator*(target, mutator: proc) =
  ## Implements the interface for running LibFuzzer's fuzzing loop, where func `target`'s
  ## single immutatable parameter, is the structured input type.
  ## It uses `mutator: proc (x: var T; sizeIncreaseHint: Natural, r: var Rand)`
  ## to generate new mutations. This has the flexibility of transforming the input and/or
  ## mutating some part of it via the `runMutator` proc. Then applying the reverse transform to
  ## convert it back to the original representation.
  ## It's recommended that the experimental "strict funcs" feature is enabled.
  commonImpl(target, mutator)
