import std/[os, strformat, strutils]

proc standaloneFuzzTarget =
  stderr.write &"StandaloneFuzzTarget: running {paramCount()} inputs\n"
  #discard initialize()
  for i in 1..paramCount():
    stderr.write &"Running: {paramStr(i)}\n"
    var buf = readFile(paramStr(i))
    discard LLVMFuzzerTestOneInput(cast[ptr UncheckedArray[byte]](cstring(buf)), buf.len)
    stderr.write &"Done:    {paramStr(i)}: ({formatSize(buf.len)})\n"

standaloneFuzzTarget()
