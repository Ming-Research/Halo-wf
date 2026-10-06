# Review checklist

Halo's items for the completion review, which a separate read-only agent
runs under the owner-wide instructions, together with their design checks.

- **C1 — Reference.** Expected replies come from the reference (Redis
  7.0.15's recorded replies, PUC Lua 5.1), never from Halo's own output, and
  a fixed behavior has an oracle case that failed before the fix.
- **C2 — General path.** The change implements Lua 5.1's rule as the
  reference does; no script, test or benchmark selects a special path, and
  Halo's source names no Redis behavior that belongs to the host.
- **C3 — Interfaces.** Module bodies implement their `.wfm` interfaces as
  written, and no contract or effect row is weakened to let a body pass.
- **C4 — Gate.** CI runs the Makefile targets that `make check` runs, and a
  change to the oracle corpus records its replies with
  `.github/workflows/oracle-reference.yml`.
- **C5 — Pins.** Whitefoot-kit's [review items](../whitefoot-kit/downstream.md#review-items)
  hold for `whitefoot.pin` and the submodules.
