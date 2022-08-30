import drchaos

proc fuzzMe(s: string, a, b, c: int32) =
  if a == 0xdeadc0de'i32 and b == 0x11111111'i32 and c == 0x22222222'i32:
    if s.len == 100: doAssert false

func fuzzTarget(data: (string, int32, int32, int32)) =
  let (s, a, b, c) = data
  fuzzMe(s, a, b, c)

defaultMutator(fuzzTarget)
