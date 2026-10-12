# Halo's canonical checks. `make check` is the gate a revision passes before
# it merges into main; CI runs the same targets.

PY ?= python3

# Every path is relative to this Makefile, so each target works from any
# working directory.
ROOT := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
BUILD := $(ROOT)/build

# The live design trees: every root node file directly under design/ except
# the log, so a tree is linted in the same change that adds it.
DESIGN_TREES := $(filter-out log,$(basename $(notdir $(wildcard $(ROOT)/design/*.md))))

# The revision a design-tree change is reviewed against. CI selects it per
# event with design/skill/review-base.sh.
DESIGN_REVIEW_BASE ?= origin/main

# The pinned Whitefoot compiler: whitefoot.pin, make compiler, pin-ready and
# WHITEFOOTC come from the whitefoot-kit submodule, shared with the other
# projects written in Whitefoot (whitefoot-kit/downstream.md).
include $(ROOT)/whitefoot-kit/whitefoot.mk

# The collector's mutant controls (research/experiments/halo-gc/controls.sh),
# one part each; gate-parts checks that controls.sh lists the same labels.
ROOTS_MUTANTS := open-upvalues frame-closure constants
ROOTS_MUTANT_TARGETS := $(ROOTS_MUTANTS:%=roots-mutant-%)
ROOTS_MUTANT_CHECKS := $(ROOTS_MUTANTS:%=check-roots-mutant-%)

# The parts of `make check`, each a `check-<part>` target and one CI job
# (.github/workflows/check.yml's matrix): the core group, the extended group's
# parts and the reference group.
EXTENDED_PARTS := roots-base $(ROOTS_MUTANTS:%=roots-mutant-%) hosts-vm hosts-lib-json
GATE_PARTS := core $(EXTENDED_PARTS) reference

.PHONY: check check-core check-extended check-reference \
	check-roots-base $(ROOTS_MUTANT_CHECKS) check-hosts-vm check-hosts-lib-json \
	oracle roots roots-base $(ROOTS_MUTANT_TARGETS) hosts hosts-vm hosts-lib json \
	reference-lua number msgpack design-lint design-ready gate-parts FORCE

# `make check` runs three groups: the core (the embedding probe, the oracle
# corpus, the design lint and gate-parts), the extended checks that need no
# reference build (the collector's root controls, the research hosts, the JSON
# package) and the checks against Redis 7.0.15's bundled Lua built from source
# (the number library, the MessagePack package). `check` and `check-extended`
# are made of their parts, so they run exactly what CI's jobs run.
check: $(GATE_PARTS:%=check-%)
check-core: compiler oracle design-lint gate-parts
check-extended: $(EXTENDED_PARTS:%=check-%)
check-reference: compiler number msgpack

# CI runs each part as a parallel job, so that no job builds more than three
# Whitefoot programs, nor more than one end-to-end test program, and the
# slowest job bounds the gate's time. The extended group's parts: the root
# controls except the mutants (check-roots-base, which builds the oracle's
# test program), one per mutant (each builds its own test program), halo-vm's
# smoke and suite (check-hosts-vm, two programs), and the other hosts' builds
# with the JSON package (check-hosts-lib-json, three programs). Each check of
# the extended group is in exactly one part.
check-roots-base: compiler roots-base
$(ROOTS_MUTANT_CHECKS): check-roots-mutant-%: compiler roots-mutant-%
check-hosts-vm: compiler hosts-vm
check-hosts-lib-json: compiler hosts-lib json

# The parts stay in step, checked without compiling anything: check.yml's
# matrix runs exactly GATE_PARTS, each once, so every check of `make check`
# has a CI job; and controls.sh's parts (ROOTS_PART=list) are exactly base and
# one mutant-<label> per ROOTS_MUTANTS label, so every roots part has a target.
GATE_WORKFLOW := $(ROOT)/.github/workflows/check.yml
ROOTS_SCRIPT := $(ROOT)/research/experiments/halo-gc/controls.sh
gate-parts:
	@ci=$$(sed -n 's/^[ -]*part: *//p' $(GATE_WORKFLOW) | sort | tr '\n' ' '); \
	gate=$$(printf '%s\n' $(GATE_PARTS) | sort | tr '\n' ' '); \
	if [ "$$ci" != "$$gate" ]; then \
		echo "gate parts: check.yml's matrix runs [ $$ci], make check runs [ $$gate]"; exit 1; fi; \
	listed=$$(ROOTS_PART=list sh $(ROOTS_SCRIPT)) || { echo "gate parts: controls.sh did not list its parts"; exit 1; }; \
	roots=$$(printf '%s\n' $$listed | sort | tr '\n' ' '); \
	want=$$(printf '%s\n' base $(ROOTS_MUTANTS:%=mutant-%) | sort | tr '\n' ' '); \
	if [ "$$roots" != "$$want" ]; then \
		echo "gate parts: controls.sh lists [ $$roots], the Makefile has targets for [ $$want]"; exit 1; fi; \
	echo "gate parts: check.yml's $(words $(GATE_PARTS)) jobs match make check's parts; controls.sh's parts match roots-base and the $(words $(ROOTS_MUTANTS)) mutant targets"

# The end-to-end comparison: research/experiments/halo-e2e builds a test
# program that runs scripts through pkg::embed and an in-memory host, and its
# runner compares every script of research/experiments/halo-oracle at
# budgets 1, 7 and 1000, in ordinary and collector-stress modes, byte for
# byte with Redis 7.0.15's recorded replies. The same program's embedding
# probe, run with three arguments, checks the engine lifecycle, budget
# continuation, host outcomes and collector roots, and exits with the number
# of the first failed observation. In each mode the runner first checks the
# Redis error replies' text and locations, 1,003 binary inputs to
# redis.sha1hex against Python's hashlib, and the 64 MiB heap limit followed
# by a script on the same engine. The target exits nonzero on any probe
# failure or difference in either mode, after running all three, and keeps
# each mode's report and actual replies under build/halo-e2e/ for
# inspection. The test
# program is built once, with the graph always named by the same relative
# path so that the compiler's cache key stays stable.
E2E := $(BUILD)/halo-e2e
E2E_TEST := $(E2E)/test
E2E_RUN = cd $(ROOT) && $(PY) -B research/experiments/halo-e2e/run.py \
	--compiler $(WHITEFOOTC) --binary $(E2E_TEST) --budgets 1,7,1000 --scratch-root $(E2E) \
	--verify-errors --verify-sha1 --verify-memory

$(E2E_TEST): $(PIN) $(WHITEFOOTC) FORCE
	@mkdir -p $(E2E)
	@cd $(ROOT)/research/experiments/halo-e2e && $(WHITEFOOTC) --graph modules.wfg --entry test -o $@

oracle: $(E2E_TEST)
	@rm -rf $(E2E)/ordinary $(E2E)/stress
	@status=0; \
	if $(E2E_TEST) probe probe probe < /dev/null; then echo "embedding probe: passed"; \
	else echo "embedding probe: failed observation $$?"; status=1; fi; \
	$(E2E_RUN) --report $(E2E)/ordinary.md --actual $(E2E)/ordinary || status=1; \
	$(E2E_RUN) --gc-stress --report $(E2E)/stress.md --actual $(E2E)/stress || status=1; \
	exit $$status

# The collector's removed-root controls (research/experiments/halo-gc): the
# local root cases pass with the oracle's test program, and fail once a sole
# root is hidden or one marking call is removed and rebuilt in a copy. `roots`
# runs all of it; `roots-base` runs the classifier self-test and the controls
# that need the oracle's test program, and `roots-mutant-<label>` builds one
# mutant in a copy and checks that its control fails by a detected result.
# Each check is in exactly one of `roots-base` and the mutant targets.
ROOTS_CONTROLS = WHITEFOOTC=$(WHITEFOOTC) sh $(ROOT)/research/experiments/halo-gc/controls.sh
roots: $(E2E_TEST)
	@ROOTS_PART=all $(ROOTS_CONTROLS) $(E2E_TEST) $(BUILD)/halo-roots

roots-base: $(E2E_TEST)
	@ROOTS_PART=base $(ROOTS_CONTROLS) $(E2E_TEST) $(BUILD)/halo-roots

$(ROOTS_MUTANT_TARGETS): roots-mutant-%: $(PIN) $(WHITEFOOTC) FORCE
	@ROOTS_PART=mutant-$* $(ROOTS_CONTROLS) $(BUILD)/halo-roots

# The research hosts that use the engine's interfaces directly build, and
# halo-vm's smoke and suite pass, so an interface change reaches them. `hosts`
# is two parts, each building two programs: `hosts-vm` builds and runs
# halo-vm's smoke and suite, and `hosts-lib` builds halo-lib's run entry and
# the benchmark host without running them.
HOSTS := $(BUILD)/halo-hosts
hosts: hosts-vm hosts-lib

hosts-vm: $(PIN) $(WHITEFOOTC) FORCE
	@mkdir -p $(HOSTS)
	@cd $(ROOT)/research/experiments/halo-vm && $(WHITEFOOTC) --graph modules.wfg --entry smoke -o $(HOSTS)/vm-smoke
	@cd $(ROOT)/research/experiments/halo-vm && $(WHITEFOOTC) --graph modules.wfg --entry suite -o $(HOSTS)/vm-suite
	@$(HOSTS)/vm-smoke && echo "halo-vm smoke: passed"
	@$(HOSTS)/vm-suite && echo "halo-vm suite: passed"

hosts-lib: $(PIN) $(WHITEFOOTC) FORCE
	@mkdir -p $(HOSTS)
	@cd $(ROOT)/research/experiments/halo-lib && $(WHITEFOOTC) --graph modules.wfg --entry run -o $(HOSTS)/lib-run
	@cd $(ROOT)/research/experiments/halo-bench && $(WHITEFOOTC) --graph modules.wfg --entry bench -o $(HOSTS)/bench

# The JSON package against the runner's independent Python oracle
# (research/experiments/json), on generated documents and number texts.
JSON_SAMPLES ?= 20
json: $(PIN) $(WHITEFOOTC) FORCE
	@mkdir -p $(BUILD)/json
	@cd $(ROOT) && $(PY) -B research/experiments/json/run.py --compiler $(WHITEFOOTC) --incremental \
		--binary $(BUILD)/json/check --build --samples $(JSON_SAMPLES)

# Redis 7.0.15's bundled Lua, built from its verified source with Redis's own
# deps Makefile, is the reference of the number and MessagePack comparisons.
REFERENCE_LUA := $(BUILD)/redis/redis-7.0.15/deps/lua/src
reference-lua:
	@sh $(ROOT)/research/experiments/halo-oracle/fetch-redis.sh $(BUILD)/redis

# The number library (lib/halo/number) against the reference Lua's tostring,
# tonumber, ^, math.fmod, floor and ceil (research/experiments/halo-number).
NUMBER_SAMPLES ?= 100
NUMBER_EXAMPLES ?= 8
number: $(PIN) $(WHITEFOOTC) reference-lua FORCE
	@cd $(ROOT) && $(PY) -B research/experiments/halo-number/compare.py --compiler $(WHITEFOOTC) \
		--incremental --lua $(REFERENCE_LUA)/lua --samples $(NUMBER_SAMPLES) --examples $(NUMBER_EXAMPLES)

# The MessagePack package against Redis's cmsgpack built with the reference
# Lua (research/experiments/msgpack); its scratch must be outside the
# repository.
MSGPACK_GENERATED ?= 0
MSGPACK_SCRATCH ?= $(or $(TMPDIR),/tmp)/halo-msgpack-check
msgpack: $(PIN) $(WHITEFOOTC) reference-lua FORCE
	@cd $(ROOT) && $(PY) -B research/experiments/msgpack/run.py --compiler $(WHITEFOOTC) --incremental \
		--redis-src $(REFERENCE_LUA) --lua-lib $(REFERENCE_LUA)/liblua.a \
		--scratch $(MSGPACK_SCRATCH) --generated $(MSGPACK_GENERATED)

# The design skill's own tests, then the lint of every live tree; until the
# first tree lands there is nothing to lint.
design-lint:
	@$(PY) -B -m unittest discover -s $(ROOT)/design/skill -p 'test_lint.py'
	@$(if $(DESIGN_TREES),$(PY) -B $(ROOT)/design/skill/lint.py --root $(ROOT)/design --trees $(DESIGN_TREES) --base "$(DESIGN_REVIEW_BASE)",echo "design lint: no live tree")

design-ready:
	@$(if $(DESIGN_TREES),$(PY) -B $(ROOT)/design/skill/lint.py --root $(ROOT)/design --trees $(DESIGN_TREES) --base "$(DESIGN_REVIEW_BASE)" --require-approval,echo "design ready: no live tree")

FORCE:
