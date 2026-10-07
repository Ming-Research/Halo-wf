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

.PHONY: check check-core check-extended check-reference oracle roots hosts json reference-lua number msgpack design-lint design-ready FORCE

# `make check` runs three groups, which CI runs as parallel jobs: the core
# (the embedding probe, the oracle corpus and the design lint), the extended
# checks that need no reference build (the collector's root controls, the
# research hosts, the JSON package) and the checks against Redis 7.0.15's
# bundled Lua built from source (the number library, the MessagePack package).
check: check-core check-extended check-reference
check-core: compiler oracle design-lint
check-extended: compiler roots hosts json
check-reference: compiler number msgpack

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
# root is hidden or one marking call is removed and rebuilt in a copy.
roots: $(E2E_TEST)
	@WHITEFOOTC=$(WHITEFOOTC) sh $(ROOT)/research/experiments/halo-gc/controls.sh $(E2E_TEST) $(BUILD)/halo-roots

# The research hosts that use the engine's interfaces directly build, and
# halo-vm's smoke and suite pass, so an interface change reaches them.
HOSTS := $(BUILD)/halo-hosts
hosts: $(PIN) $(WHITEFOOTC) FORCE
	@mkdir -p $(HOSTS)
	@cd $(ROOT)/research/experiments/halo-vm && $(WHITEFOOTC) --graph modules.wfg --entry smoke -o $(HOSTS)/vm-smoke
	@cd $(ROOT)/research/experiments/halo-vm && $(WHITEFOOTC) --graph modules.wfg --entry suite -o $(HOSTS)/vm-suite
	@cd $(ROOT)/research/experiments/halo-lib && $(WHITEFOOTC) --graph modules.wfg --entry run -o $(HOSTS)/lib-run
	@cd $(ROOT)/research/experiments/halo-bench && $(WHITEFOOTC) --graph modules.wfg --entry bench -o $(HOSTS)/bench
	@$(HOSTS)/vm-smoke && echo "halo-vm smoke: passed"
	@$(HOSTS)/vm-suite && echo "halo-vm suite: passed"

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
