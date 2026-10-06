# Review checklist

- **C1 — Reference.** Expected results come from the reference (Redis
  7.0.15's recorded replies, PUC Lua 5.1) or a format's specification, never
  from Halo's own output, and a fixed behavior has an oracle case that failed
  before the fix.
- **C2 — General path.** The change implements Lua 5.1's rule as the
  reference does; no script, test or benchmark selects a special path, no
  fallback conceals an unsupported feature, and Halo's source names no Redis
  behavior that belongs to the host.
- **C3 — Interfaces.** Module bodies implement their `.wfm` interfaces as
  written, and no contract or effect row is weakened to let a body pass.
- **C4 — Gate.** CI runs the Makefile targets that `make check` runs.
- **C5 — Pins.** Whitefoot-kit's [review items](../whitefoot-kit/downstream.md#review-items)
  hold for `whitefoot.pin` and the submodules.
