mode = ScriptMode.Verbose

version = "0.1.0"
author = "Dr. Chaos Team"
description = "Library for structured fuzzing for Nim"
license = "MIT"
srcDir = "."
skipDirs = @["tests", "benchmarks", "examples"]

requires "nim >= 1.4.0"

proc buildBinary(name: string, srcDir = "./", params = "", lang = "c") =
  if not dirExists "build":
    mkDir "build"
  # allow something like "nim nimbus --verbosity:0 --hints:off nimbus.nims"
  var extra_params = params
  when compiles(commandLineParams):
    for param in commandLineParams:
      extra_params &= " " & param
  else:
    for i in 2..<paramCount():
      extra_params &= " " & paramStr(i)

  exec "nim " & lang & " --out:build/" & name & " " & extra_params & " " & srcDir & name & ".nim"

proc test(name: string, srcDir = "tests/", lang = "c") =
  buildBinary name, srcDir, "--mm:arc -d:danger"
  withDir("build/"):
    exec name & " -error_exitcode=0 -max_total_time=5 -runs=10000"

task testDrChaosExamples, "Build & run Dr. Chaos examples":
  let examples = @["fuzz_graph", "fuzz_tree"]
  for ex in examples:
    test ex, "examples/"

task testDrChaos, "Build & run Dr. Chaos tests":
  for filePath in listFiles("tests/"):
    if filePath[^4..^1] == ".nim":
      test filePath[len("tests/")..^5]

task testDrChaosTimed, "Build & run Dr. Chaos time limited tests":
  for filePath in listFiles("tests/time_limited/"):
    if filePath[^4..^1] == ".nim":
      test filePath[len("tests/time_limited/")..^5], "tests/time_limited/"

#task test, "Run basic tests":
  #testDrChaosTask()

task testAll, "Run all tests":
  testDrChaosTask()
  testDrChaosTimedTask()
