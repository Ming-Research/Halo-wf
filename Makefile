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
# `release = wf-<12-character commit hash>`, naming a release of
# Ming-Research/Whitefoot; `make compiler` downloads that release's
# whitefootc for this host, checked against its SHA256SUMS and manifest, to
# build/whitefoot/<release>/.
PIN := $(ROOT)/whitefoot.pin
RELEASE := $(shell sed -n 's/^release = \(wf-[0-9a-f]\{12\}\)$$/\1/p' $(PIN) 2>/dev/null)
RELEASES := https://github.com/Ming-Research/Whitefoot/releases/download
HOST := $(shell uname -s)-$(shell uname -m)
ASSET := $(if $(filter Linux-x86_64,$(HOST)),whitefootc-linux-x86_64.tar.gz,$(if $(filter Darwin-arm64,$(HOST)),whitefootc-macos-arm64.tar.gz))
WHITEFOOT := $(BUILD)/whitefoot/$(RELEASE)
WHITEFOOTC := $(WHITEFOOT)/whitefootc

.PHONY: check compiler design-lint design-ready

check: compiler design-lint

compiler: $(WHITEFOOTC)

$(PIN):
	@echo "whitefoot.pin is missing; it names the Whitefoot compiler release (AGENTS.md, Upgrading Whitefoot)" >&2
	@exit 1

$(WHITEFOOTC): $(PIN)
	@test -n "$(RELEASE)" || { echo "whitefoot.pin must hold one line: release = wf-<12-character commit hash>" >&2; exit 1; }
	@test -n "$(ASSET)" || { echo "Whitefoot publishes no compiler for $(HOST)" >&2; exit 1; }
	@rm -rf $(WHITEFOOT).part && mkdir -p $(WHITEFOOT).part
	@cd $(WHITEFOOT).part && for file in $(ASSET) SHA256SUMS whitefoot-release.json; do \
		curl -fsSL --retry 3 -o $$file $(RELEASES)/$(RELEASE)/$$file || { \
			echo "cannot download $$file of $(RELEASE): dispatch Whitefoot's release workflow for that commit (AGENTS.md, Upgrading Whitefoot)" >&2; \
			exit 1; }; \
	done
	@cd $(WHITEFOOT).part && grep '  $(ASSET)$$' SHA256SUMS | shasum -a 256 -c -
	@cd $(WHITEFOOT).part && $(PY) -c 'import json, sys; m = json.load(open("whitefoot-release.json")); sys.exit(0 if m["tag"] == "$(RELEASE)" and m["commit"].startswith("$(RELEASE:wf-%=%)") else "whitefoot-release.json does not describe $(RELEASE)")'
	@cd $(WHITEFOOT).part && tar -xzf $(ASSET) && rm $(ASSET) && test -x whitefootc
	@rm -rf $(WHITEFOOT) && mv $(WHITEFOOT).part $(WHITEFOOT)
	@echo "whitefootc $(RELEASE) for $(HOST) at $(WHITEFOOTC)"

# The design skill's own tests, then the lint of every live tree; until the
# first tree lands there is nothing to lint.
design-lint:
	@$(PY) -B -m unittest discover -s $(ROOT)/design/skill -p 'test_lint.py'
	@$(if $(DESIGN_TREES),$(PY) -B $(ROOT)/design/skill/lint.py --root $(ROOT)/design --trees $(DESIGN_TREES) --base "$(DESIGN_REVIEW_BASE)",echo "design lint: no live tree")

design-ready:
	@$(if $(DESIGN_TREES),$(PY) -B $(ROOT)/design/skill/lint.py --root $(ROOT)/design --trees $(DESIGN_TREES) --base "$(DESIGN_REVIEW_BASE)" --require-approval,echo "design ready: no live tree")
