# Make sure we catch the exception and it doesn't leak any memory.
# Should print a stack trace in debug mode.
import drchaos

proc testMe(x: int) =
  raise newException(ValueError, "Fuzzer test1: " & $x)

func fuzzTarget(x: int) =
  testMe(x)

defaultMutator(fuzzTarget)
