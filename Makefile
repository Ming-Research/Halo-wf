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

.PHONY: check oracle design-lint design-ready FORCE

check: compiler oracle design-lint

# The end-to-end comparison: research/experiments/halo-e2e builds a test
# program that runs scripts through pkg::embed and an in-memory host, and its
# runner compares every script of research/experiments/halo-oracle at
# budgets 1, 7 and 1000, in ordinary and collector-stress modes, byte for
# byte with Redis 7.0.15's recorded replies. It exits nonzero on any
# difference in either mode, after running both, and keeps each mode's
# report and actual replies under build/halo-e2e/ for inspection. The test
# program is built once, with the graph always named by the same relative
# path so that the compiler's cache key stays stable.
E2E := $(BUILD)/halo-e2e
E2E_TEST := $(E2E)/test
E2E_RUN = cd $(ROOT) && $(PY) -B research/experiments/halo-e2e/run.py \
	--compiler $(WHITEFOOTC) --binary $(E2E_TEST) --budgets 1,7,1000 --scratch-root $(E2E)

$(E2E_TEST): $(PIN) $(WHITEFOOTC) FORCE
	@mkdir -p $(E2E)
	@cd $(ROOT)/research/experiments/halo-e2e && $(WHITEFOOTC) --graph modules.wfg --entry test -o $@

oracle: $(E2E_TEST)
	@rm -rf $(E2E)/ordinary $(E2E)/stress
	@status=0; \
	$(E2E_RUN) --report $(E2E)/ordinary.md --actual $(E2E)/ordinary || status=1; \
	$(E2E_RUN) --gc-stress --report $(E2E)/stress.md --actual $(E2E)/stress || status=1; \
	exit $$status

# The design skill's own tests, then the lint of every live tree; until the
# first tree lands there is nothing to lint.
design-lint:
	@$(PY) -B -m unittest discover -s $(ROOT)/design/skill -p 'test_lint.py'
	@$(if $(DESIGN_TREES),$(PY) -B $(ROOT)/design/skill/lint.py --root $(ROOT)/design --trees $(DESIGN_TREES) --base "$(DESIGN_REVIEW_BASE)",echo "design lint: no live tree")

design-ready:
	@$(if $(DESIGN_TREES),$(PY) -B $(ROOT)/design/skill/lint.py --root $(ROOT)/design --trees $(DESIGN_TREES) --base "$(DESIGN_REVIEW_BASE)" --require-approval,echo "design ready: no live tree")

FORCE:
