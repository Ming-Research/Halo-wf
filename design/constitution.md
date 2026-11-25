# The Halo constitution

This constitution holds what Halo is for and its lasting values, and every
decision in the project comes from them. The owner sets it and changes it.

## What Halo is for

Halo is an engine of the Lua language written in Whitefoot. It exists first for
Whitefoot: it shows what Whitefoot gives a dynamic-language runtime, with
dynamic values, closures and a garbage collector all under Whitefoot's
guarantees, and it exposes what Whitefoot still lacks. It is a general engine
that any host can embed; its first host is Firn. Second, it may become a product
in its own right: the fastest Lua interpreter.

## Article 1 (faithful). Lua runs as the reference runs it

A Lua program behaves on Halo as on the reference Lua, so that hosts and their
scripts move to Halo unchanged.

Violations: a program in scope that behaves differently on Halo, unrecorded.

## Article 2 (safe). Safety from Whitefoot's proofs

Halo's safety comes from Whitefoot's proofs: it keeps every check Whitefoot
requires, and nothing turns one off. A script, whatever it does, cannot break
the safety of Halo or of its host.

Violations: an unchecked operation or an escape from Whitefoot's checks, for any
reason; a script that breaks the safety of Halo or its host.

## Article 3 (fast). The fastest Lua interpreter

Halo is faster than every existing Lua interpreter on the same machine. Speed
counts only on top of Articles 1 and 2.

Violations: a speed-up that breaks Article 1 or 2.

## Article 4 (for Whitefoot). A gap goes back to Whitefoot

What Halo cannot write well or make fast in Whitefoot is a gap of Whitefoot,
closed in Whitefoot; a fault of Halo's own is fixed in Halo.

Violations: a gap of Whitefoot that Whitefoot never heard of.
