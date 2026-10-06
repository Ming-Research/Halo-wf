# Halo

Halo is a Lua 5.1 engine written in [Whitefoot](https://github.com/Ming-Research/Whitefoot),
a language in which memory corruption, data races, uninitialized reads and
silent overflow cannot be written: every partial operation is admitted only
after the compiler proves its domain. Halo puts a dynamic-language runtime
under those guarantees, with tagged values, tables, closures and upvalues in a
handle heap, a mark-and-sweep collector, and execution that can stop at a
budget and resume.

Halo is a general embeddable engine. Its first host is
[Firn](https://github.com/Ming-Research/Firn-wf), a Redis-compatible server
in Whitefoot, which runs Redis scripts (`EVAL`) with it. Halo's own source
never names Redis: the host supplies `redis.call`, `KEYS`, `ARGV`, the reply
conversions and the script cache. The JSON and MessagePack codecs that Lua
scripts use through `cjson` and `cmsgpack` are separate, general packages in
this repository.

## Compatibility target

Halo's behavior is judged against Redis 7.0.15 and its bundled Lua 5.1 (PUC
Lua 5.1.5 with Redis's patches) on x86-64 Linux with glibc. The oracle corpus
in [research/experiments/halo-oracle](research/experiments/halo-oracle/)
records that reference's exact replies to 80 scripts covering Lua 5.1's core
semantics, the scripting API, the codec libraries and application scripts.

## Building and checking

Halo builds with a released Whitefoot compiler, never with Whitefoot's
source. `whitefoot.pin` names the release, and `make compiler` downloads
that release's `whitefootc` for the host (Linux x86-64 or macOS arm64) and
checks it against the release's checksums.

```sh
git clone --recurse-submodules https://github.com/Ming-Research/Halo-wf.git
cd Halo-wf
make check
```

`make check` is the gate every change to `main` passes in CI. It needs git,
curl, Python 3 and the toolchain the compiler links with: `/usr/bin/clang`,
and on Linux LLD.

## Where to read

- [research/investigations/halo](research/investigations/halo/): what the
  engine needs from the language ([DESIGN.md](research/investigations/halo/DESIGN.md))
  and the engine's design, work order and falsifiers
  ([VM.md](research/investigations/halo/VM.md)).
- [research/experiments](research/experiments/): measured results, each with
  its sources, commands and caveats.
- `design/`: the decisions Halo is built on, with their reasons and refused
  alternatives, and their approval log.
- [docs/todo.md](docs/todo.md): known defects, follow-up work and what Halo
  needs from Whitefoot.
- [AGENTS.md](AGENTS.md): how work on Halo proceeds, for people and coding
  agents alike.

## License

Halo is released under the [MIT License](LICENSE). Code ported from other
projects keeps its own notice beside it.
