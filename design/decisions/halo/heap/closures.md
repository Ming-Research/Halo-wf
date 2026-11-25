# Closures

How a heap closure names what it calls, and how `cjson.new()` instances keep their configurations.

### decision a-closure-names-its-callee
A heap closure records its callee explicitly, a Lua prototype or a builtin ID, and a native closure keeps its state in closed captures; a prototype id is engine-wide and never reused.
- rejected: an agent proposed a reserved prototype value for each kind of native closure; the owner rejected it, because the kinds stay apart only while each new native closure picks an unused value and every reader compares against all of them, which no check enforces.
- rejected: an agent proposed keeping native closures' bindings in a VM registry; the owner rejected it, because a registry's lifetime can drift apart from recycled closure handles.

### decision cjson-configurations-are-reclaimed-after-collection
After a collection, Halo frees the `cjson.new()` configurations that no live cjson closure captures, reuses the lowest freed index, trims free trailing slots and keeps index zero.
- rejected: an agent proposed making each configuration a heap object the collector manages; the owner rejected it, because it would change how the host snapshots and restores the settings, directly by index.
