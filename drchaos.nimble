mode = ScriptMode.Verbose

version = "0.1.3"
author = "Dr. Chaos Team"
description = "A powerful and easy-to-use fuzzing framework in Nim for C/C++/Obj-C targets"
license = "Apache License 2.0"
srcDir = "."
skipDirs = @["tests", "benchmarks", "examples", "experiments"]

requires "nim >= 1.2.0"

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

proc test(name: string, srcDir = "tests/", args = "", lang = "c") =
  buildBinary name, srcDir, "--mm:arc -d:release"
  withDir("build/"):
    exec "./" & name & " -max_total_time=1 -runs=10000 " & args

task testDrChaosExamples, "Build & run Dr. Chaos examples":
  let examples = @["fuzz_graph"]
  for ex in examples:
    test ex, "examples/"

task testDrChaos, "Build & run Dr. Chaos tests":
  for filePath in listFiles("tests/"):
    if filePath[^4..^1] == ".nim":
      test filePath[len("tests/")..^5], args = "-error_exitcode=0"

task testDrChaosNoCrash, "Build & run Dr. Chaos tests that should not crash":
  for filePath in listFiles("tests/no_crash/"):
    if filePath[^4..^1] == ".nim":
      test filePath[len("tests/no_crash/")..^5], "tests/no_crash/"

task test, "Run basic tests":
  testDrChaosTask()
  testDrChaosNoCrashTask()

task testAll, "Run all tests":
  testDrChaosTask()
  testDrChaosNoCrashTask()
  testDrChaosExamplesTask()
