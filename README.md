# drchaos

Fuzzing is a technique for automated bug detection that involves providing random inputs
to a target program to induce crashes. This approach can increase test coverage, enabling
the identification of edge cases and more efficient triggering of bugs.

Drchaos extends the Nim interface to LLVM/Clang libFuzzer, an in-process, coverage-guided,
and evolutionary fuzzing engine, while also introducing support for
[structured fuzzing](https://github.com/google/fuzzing/blob/master/docs/structure-aware-fuzzing.md).
To utilize this functionality, users must specify the input type as a parameter for the
target function, and the fuzzer generates valid inputs. This process employs value
profiling to direct the fuzzer beyond these comparisons more efficiently than relying on
the probability of finding the exact sequence of bytes by chance.

## Usage

Creating a fuzz target by defining a data type and a target function that performs
operations and verifies if the invariants are maintained via assert conditions is usually
an uncomplicated task for most scenarios. For more information on creating effective fuzz
targets, please refer to
[What makes a good fuzz target](https://github.com/google/fuzzing/blob/master/docs/good-fuzz-target.md)
Once the target function is defined, the `defaultMutator` can be called with that function
as argument.

A basic fuzz target, such as verifying that the software under test remains stable without
crashing by defining a fixed-size type, can suffice:

```nim
import drchaos

proc fuzzMe(s: string, a, b, c: int32) =
  # The function being tested.
  if a == 0xdeadc0de'i32 and b == 0x11111111'i32 and c == 0x22222222'i32:
    if s.len == 100: doAssert false

proc fuzzTarget(data: (string, int32, int32, int32)) =
  let (s, a, b, c) = data
  fuzzMe(s, a, b, c)

defaultMutator(fuzzTarget)
```

> **WARNING**: Modifying the input variable within fuzz targets is not allowed.
> If you are using ref types, you can prevent modifications by utilizing the `func` keyword
> and `{.experimental: "strictFuncs".}` in your code.

It is also possible to create more complex fuzz targets, such as the one shown below:

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

proc `==`(a, b: ContentNode): bool =
  if a.kind != b.kind: return false
  case a.kind
  of P: return a.pChildren == b.pChildren
  of Br: return true
  of Text: return a.textStr == b.textStr

proc fuzzTarget(x: ContentNode) =
  # Convert or translate `x` to any desired format (JSON, HMTL, binary, etc.),
  # and then feed it into the API being tested.

defaultMutator(fuzzTarget)
```

Using drchaos, it is possible to generate millions of inputs and execute fuzzTarget within
just a few seconds. More elaborate examples, such as fuzzing a graph library, can be
located in the [examples](examples/) directory.

It is critical to define a `==` proc for the input type. Overloading
`proc default(_: typedesc[T]): T` can also be advantageous, especially when `nil` is not a
valid value for `ref`.

### Needed config

To compile the fuzz target, it is recommended to use at least the following flags:
`--cc:clang -d:useMalloc -t:"-fsanitize=fuzzer,address,undefined" -l:"-fsanitize=fuzzer,address,undefined" -d:nosignalhandler --nomain:on -g`.
Additionally, it is recommended to use `--mm:arc|orc` when possible.

Sample nim.cfg and .nimble files can be found in the [tests/](tests/nim.cfg) directory and
[this repository](https://github.com/planetis-m/fuzz-playground/blob/master/playground.nimble), respectively.

Alternatively, drchaos offers structured input for fuzzing using [nim-testutils](https://github.com/status-im/nim-testutils). This includes a convenient [testrunner](https://github.com/status-im/nim-testutils/blob/master/testutils/readme.md).

### Post-processors

In some cases, it may be necessary to modify the randomized input to include specific
values or create dependencies between certain fields. To support this functionality,
drchaos offers a post-processing step that runs on compound types like object, tuple, ref,
seq, string, array, and set. This step is only executed on these types for performance and
clarity purposes, with distinct types being the exception.

```nim
proc postProcess(x: var ContentNode; r: var Rand) =
  if x.kind == Text:
    x.textStr = "The man the professor the student has studies Rome."
```

### Custom mutator

The `defaultMutator` is a convenient way to generate and mutate inputs for a given
fuzz target. However, if more fine-grained control is needed, the `customMutator`
can be used. With `customMutator`, the mutation procedure can be customized to
perform specific actions, such as uncompressing a `seq[byte]` before calling
`runMutator` on the raw data, and then compressing the output again.

```nim
proc myTarget(x: seq[byte]) =
  var data = uncompress(x)
  # ...

proc myMutator(x: var seq[byte]; sizeIncreaseHint: Natural; r: var Rand) =
  var data = uncompress(x)
  runMutator(data, sizeIncreaseHint, r)
  x = compress(data)

customMutator(myTarget, myMutator)
```

### User-defined mutate procs

Distinct types can be used to provide a mutate overload for fields with unique values or
to restrict the search space. For example, it is possible to define a distinct type for
file signatures or other specific values that may be of interest.

```nim
# Inside the library being fuzzed
when defined(runFuzzTests):
  type
    ClientId = distinct int

  proc `==`(a, b: ClientId): bool {.borrow.}
else:
  type
    ClientId = int

# Inside a test file
import drchaos/mutator

const
  idA = 0.ClientId
  idB = 2.ClientId
  idC = 4.ClientId

proc mutate(value: var ClientId; sizeIncreaseHint: int; enforceChanges: bool; r: var Rand) =
  # Call `random.rand()` to return a new value.
  repeatMutate(r.sample([idA, idB, idC]))
```

The `drchaos/mutator` module exports mutators for every supported type to aid in the
creation of mutate functions.

### User-defined serializers

User overloads should follow the following `proc` signatures:

```nim
proc fromData(data: openArray[byte]; pos: var int; output: var T)
proc toData(data: var openArray[byte]; pos: var int; input: T)
proc byteSize(x: T): int {.inline.} # The amount of memory that the serialized type will occupy, measured in bytes.
```

The need for this arises only in the case of objects that include raw pointers. To address
this, `drchaos/common` offers read/write procedures to simplify the process.

It is necessary to define the `mutate`, `default` and `==` procedures. For container
types, it is also necessary to define `mitems` or `mpairs` iterators.

### Best practices and considerations

- Avoid using `echo` in a fuzz target as it can significantly slow down the execution speed.

- Prefer using `-d:danger` for maximum performance, but ensure that your code is free from
  undefined behavior and does not rely on any assumptions that may break in unexpected ways.

- Once you have identified a crash, you can recompile the program with `-d:debug` and pass the
  crashing test case as a parameter to further investigate the cause of the crash.

- Use `debugEcho(x)` in a target to print the input that caused the crash, which can be
  helpful in debugging and reproducing the issue.

- Although disabling sanitizers may improve performance, it is not recommended as
  AddressSanitizer can help catch memory errors and undefined behavior that may lead to
  crashes or other bugs.

### What's not supported

- Polymorphic types do not have serialization support.
- References with cycles are not supported. However, a .noFuzz custom pragma will be added soon for cursors.
- Object variants only work with the latest memory management model, which is `--mm:arc|orc`.

## Advantages of using drchaos for fuzzing

drchaos offers a number of advantages over frameworks based on
[FuzzDataProvider](https://github.com/google/fuzzing/blob/master/docs/split-inputs.md),
which  often have difficulty handling nested dynamic types. For a more detailed
explanation of these issues, you can read an article by the author of Fuzzcheck, available
at the following link: <https://github.com/loiclec/fuzzcheck-rs/blob/main/articles/why_not_bytes.md>

## Bugs found with the help of drchaos

### Nim reference implementation

## Bugs discovered with the assistance of drchaos

The drchaos framework has helped discover various bugs in software projects. Here are some
examples of bugs that were found in the Nim reference implementation with the help of
drchaos:

* Use-after-free bugs in object variants (https://github.com/nim-lang/Nim/issues/20305)
* OpenArray on an empty sequence triggers undefined behavior (https://github.com/nim-lang/Nim/issues/20294)

## License

Licensed and distributed under either of

* MIT license: [LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT

or

* Apache License, Version 2.0, ([LICENSE-APACHEv2](LICENSE-APACHEv2) or http://www.apache.org/licenses/LICENSE-2.0)

at your option. These files may not be copied, modified, or distributed except according to those terms.
