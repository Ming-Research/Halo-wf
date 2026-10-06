# Review checklist

- **C1 — Reference.** Expected results come from Redis 7.0.15's recorded
  replies on x86-64 Linux, PUC Lua 5.1, or the JSON and MessagePack
  specifications.
- **C2 — Lua and the host.** The change implements Lua 5.1's rule as the
  reference does, and Halo's source names no Redis behavior that belongs to
  the host.
- **C3 — Interfaces.** Module bodies implement their `.wfm` interfaces as
  written.
- **C4 — Gate.** CI runs the Makefile targets that `make check` runs.
- **C5 — Pins.** Whitefoot-kit's [review items](../whitefoot-kit/downstream.md#review-items)
  hold for `whitefoot.pin` and the submodules.
