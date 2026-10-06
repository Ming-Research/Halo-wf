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

# The pinned Whitefoot compiler. whitefoot.pin holds one line,
# `release = wf-<12-character commit hash>` for a commit on Whitefoot's main,
# or `release = wf-exp-<12-character commit hash>` for an experiment release
# of an unmerged commit, naming a release of Ming-Research/Whitefoot;
# `make compiler` downloads that release's whitefootc for this host, checked
# against its SHA256SUMS and manifest, to build/whitefoot/<release>/.
PIN := $(ROOT)/whitefoot.pin
PIN_LINE := ^release = wf-(exp-)?[0-9a-f]{12}$$
RELEASE := $(shell sed -n -E 's/^release = (wf-(exp-)?[0-9a-f]{12})$$/\1/p' $(PIN) 2>/dev/null)
RELEASE_COMMIT := $(lastword $(subst -, ,$(RELEASE)))
RELEASES := https://github.com/Ming-Research/Whitefoot/releases/download
HOST := $(shell uname -s)-$(shell uname -m)
ASSET := $(if $(filter Linux-x86_64,$(HOST)),whitefootc-linux-x86_64.tar.gz,$(if $(filter Darwin-arm64,$(HOST)),whitefootc-macos-arm64.tar.gz))
WHITEFOOT := $(BUILD)/whitefoot/$(RELEASE)
WHITEFOOTC := $(WHITEFOOT)/whitefootc

.PHONY: check compiler oracle design-lint design-ready FORCE

check: compiler oracle design-lint

compiler: $(WHITEFOOTC)

$(PIN):
	@echo "whitefoot.pin is missing; it names the Whitefoot compiler release (AGENTS.md, Upgrading Whitefoot)" >&2
	@exit 1

$(WHITEFOOTC): $(PIN)
	@test "$$(grep -c '' $(PIN))" = 1 && grep -qE '$(PIN_LINE)' $(PIN) || { \
		echo "whitefoot.pin must hold exactly one line: release = wf-<12-character commit hash> (or wf-exp-<hash> on an experiment branch)" >&2; \
		exit 1; }
	@test -n "$(ASSET)" || { echo "Whitefoot publishes no compiler for $(HOST)" >&2; exit 1; }
	@rm -rf $(WHITEFOOT).part && mkdir -p $(WHITEFOOT).part
	@cd $(WHITEFOOT).part && for file in $(ASSET) SHA256SUMS whitefoot-release.json; do \
		curl -fsSL --retry 3 -o $$file $(RELEASES)/$(RELEASE)/$$file || { \
			echo "cannot download $$file of $(RELEASE): dispatch Whitefoot's release workflow for that commit (AGENTS.md, Upgrading Whitefoot)" >&2; \
			exit 1; }; \
	done
	@cd $(WHITEFOOT).part && grep '  $(ASSET)$$' SHA256SUMS | shasum -a 256 -c -
	@cd $(WHITEFOOT).part && $(PY) -c 'import json, sys; m = json.load(open("whitefoot-release.json")); sys.exit(0 if m["tag"] == "$(RELEASE)" and m["commit"].startswith("$(RELEASE_COMMIT)") else "whitefoot-release.json does not describe $(RELEASE)")'
	@cd $(WHITEFOOT).part && tar -xzf $(ASSET) && rm $(ASSET) && test -x whitefootc
	@rm -rf $(WHITEFOOT) && mv $(WHITEFOOT).part $(WHITEFOOT)
	@echo "whitefootc $(RELEASE) for $(HOST) at $(WHITEFOOTC)"

# The end-to-end comparison: research/experiments/halo-e2e builds a test
# program that runs scripts through pkg::embed and an in-memory host, and its
# runner compares the 80 scripts of research/experiments/halo-oracle at
# budgets 1, 7 and 1000, in ordinary and collector-stress modes, byte for
# byte with Redis 7.0.15's recorded replies. It exits nonzero on any
# difference in either mode, after running both, and keeps each mode's
# report and actual replies under build/halo-e2e/ for inspection. The test program is built once, with the graph always named
# by the same relative path so that the compiler's cache key stays stable.
E2E := $(BUILD)/halo-e2e
E2E_TEST := $(E2E)/test
E2E_RUN = cd $(ROOT) && $(PY) -B research/experiments/halo-e2e/run.py \
	--compiler $(WHITEFOOTC) --binary $(E2E_TEST) --budgets 1,7,1000 --scratch-root $(E2E)

$(E2E_TEST): compiler FORCE
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
