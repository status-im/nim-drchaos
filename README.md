# Dr. Chaos

A powerful and easy-to-use fuzzing framework in Nim for C/C++/Obj-C targets.

Fuzzing is an automated bug finding technique, where randomized inputs are fed to a target
program in order to get it to crash. With fuzzing, you can increase your test coverage to
find edge cases and trigger bugs more effectively.

Dr. Chaos extends the Nim interface to LLVM/Clang libFuzzer, an in-process,
coverage-guided, evolutionary fuzzing engine. And adds support for
[structured fuzzing](https://github.com/google/fuzzing/blob/master/docs/structure-aware-fuzzing.md).
The user should define, as a parameter to the target function, the input type and the
fuzzer is responsible for providing valid inputs. Behind the scenes it uses value profiling
to guide the fuzzer past these comparisons much more efficiently than simply hoping to
stumble on the exact sequence of bytes by chance.

## Usage

For most cases, it is fairly trivial to define a data type and a target function that
performs some operations and checks if the invariants expressed as assert conditions still
hold. Then call `defaultMutator` with that function as parameter. That can be as basic as
defining a range type and ensuring your library doesn't crash or complex as shown bellow.

### Example

A simple but somewhat contrived example looks like this:

```nim
import drchaos

type
  ContentNodeKind = enum
    P, Br, Text
  ContentNode = object
    case kind: ContentNodeKind
    of P: pChildren: seq[ContentNode]
    of Br: discard
    of Text: textStr: string

func `==`(a, b: ContentNode): bool =
  if a.kind != b.kind: return false
  case a.kind
  of P: return a.pChildren == b.pChildren
  of Br: return true
  of Text: return a.textStr == b.textStr

func fuzzTarget(x: ContentNode) =
  # Convert or translate `x` to any format (JSON, HMTL, binary, etc...)
  # and feed it to the API you are testing.

defaultMutator(fuzzTarget)
```

Dr. Chaos will generate millions of inputs and run `fuzzTarget` under a few seconds.
More articulate examples, such as fuzzing a graph library are in the `examples/` directory.

Defining a `==` proc for your input type is necessary.

### Post-processors

Sometimes it is necessary to adjust the random input in order to add magic values or
dependencies between some fields. This is supported with a post-processing step, which for
performance and clarity reasons only runs on compound types such as
object/tuple/ref/seq/string/array/set and by exception distinct types.

```nim
import std/random

proc postProcess(x: var ContentNode; r: var Rand) =
  if x.kind == Text:
    x.textStr = "The man the professor the student has studies Rome."
```

### Custom mutator

Besides `defaultMutator` there is also `customMutator` which allows more fine-grained
control of the mutation procedure, like uncompressing a `seq[byte]` then calling
`runMutator` on the raw data and compressing the output again.

```nim
proc myMutator(x: var seq[byte]; sizeIncreaseHint: Natural; r: var Rand) =
  var tmp = uncompress(x)
  runMutator(tmp, sizeIncreaseHint, r)
  x = compress(tmp)
```

### User-defined mutate procs

It's possible to use distinct types to provide a mutate overload for fields that have
interesting values, like file signatures or to limit the search space.

```nim
# Fuzzed library
when defined(runFuzzTests):
  type
    ClientId = distinct int
else:
  type
    ClientId = int

# In a test file
import drchaos/mutator

const
  id1 = 0.ClientId
  id2 = 1.ClientId

proc mutate(value: var ClientId; sizeIncreaseHint: int; enforceChanges: bool; r: var Rand) =
  # use `rand()` to return a new value.
```

For aiding the creation of mutate functions, mutators for every supported type are
exported by `drchaos/mutator`.

## What's not supported

- Polymorphic types, missing serialization support.
- References with cycles. A `.noFuzz` custom pragma will be added soon for cursors.

## License

Licensed and distributed under either of

* MIT license: [LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT

or

* Apache License, Version 2.0, ([LICENSE-APACHEv2](LICENSE-APACHEv2) or http://www.apache.org/licenses/LICENSE-2.0)

at your option. These files may not be copied, modified, or distributed except according to those terms.
