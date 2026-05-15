# ──────────────────────────────────────────────────────────────────────────────
# vim + nvim — plugin management, symlink setup, native artifact builds
#
# Plugins are vendored as git submodules under pack/{shared,nvim}/{start,opt}.
# This Makefile symlinks ~/.vim/nvim configs, initializes plugin submodules,
# and builds native plugins (fzf, jsregexp, treesitter parsers).
#
# Usage:
#   make                                      # print help
#   make install                              # symlinks + submodule init + build
#   make update                               # pull latest for floated plugins, rebuild
#   make build                                # compile native artifacts (fzf, jsregexp, TS)
#   make helptags                             # regenerate vim/nvim helptags
#   make add PLUGIN=owner/repo BUNDLE=shared|nvim  # vendor a new plugin
#   make rm  PLUGIN=name   BUNDLE=shared|nvim     # remove a vendored plugin
#   make list                                 # list all vendored plugins
#   make plugins                              # show staged plugins per editor
#   make doctor                               # run :checkhealth in nvim
#
# Parameters:
#   BUNDLE       target bundle: 'shared' (both vim/nvim) or 'nvim' (nvim only) (default: shared)
#   PLUGIN       GitHub owner/repo or plugin name (for add/rm)
#   DOT_DRY_RUN=1  print planned changes, do not mutate (symlinks, submodules, etc.)
#   DOT_DEBUG=1    enable bash xtrace (-x) during install/build
#   DOT_VERBOSE=1  verbose output for git/cmake/make operations
#
# Environment Variables:
#   The root Makefile and bootstrap.sh pass these env vars:
#   - DRY → DOT_DRY_RUN (disable all mutations if 1)
#   - DEBUG → DOT_DEBUG (enable xtrace if 1)
#   - VERBOSE → DOT_VERBOSE (verbose output if 1)
#
# Dry-run Behavior (DOT_DRY_RUN=1):
#   - Planned symlinks, submodule operations shown as "[dry-run] <cmd>"
#   - No files copied, moved, or symlinked
#   - No git submodule init, deinit, update operations execute
#   - No cmake/make build operations execute
#   - Expected output: "🔮 plan » <planned_action>" prefix
#
# Examples:
#   DRY=1 make install          # Preview install without changes
#   DEBUG=1 make build          # Show build commands with xtrace
#   DRY=1 DEBUG=1 make update   # Dry-run with debug output
# ──────────────────────────────────────────────────────────────────────────────

SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

REPO            := $(shell cd "$(dir $(lastword $(MAKEFILE_LIST)))" && pwd)
SHARED_BUNDLE   := pack/shared/start
NVIM_BUNDLE     := pack/nvim/opt
BUNDLE          ?= shared
PLUGIN          ?=
DRY             ?= 0
DEBUG           ?= 0
VERBOSE         ?= 0
DOT_DRY_RUN     ?= $(DRY)
DOT_DEBUG       ?= $(DEBUG)
DOT_VERBOSE     ?= $(VERBOSE)

RECIPE_ENV := set -euo pipefail; \
	if [[ "$(DOT_DEBUG)" == "1" ]]; then set -x; fi; \
	dry="$(DOT_DRY_RUN)"

.PHONY: help install update helptags clean add rm doctor list plugins build \
        build-fzf-native build-fzf-bin build-luasnip-jsregexp build-treesitter

help: ## Show this help
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-24s\033[0m %s\n", $$1, $$2}'

install: ## Run install.sh (symlinks + submodules + build)
	@DOT_DRY_RUN="$(DOT_DRY_RUN)" DOT_DEBUG="$(DOT_DEBUG)" DOT_VERBOSE="$(DOT_VERBOSE)" bash $(REPO)/install.sh

update: ## Pull latest for every floated submodule, then rebuild
	@$(RECIPE_ENV); \
	echo '[update] git submodule update --remote --merge --jobs 8'; \
	if [[ "$$dry" == "1" ]]; then \
		echo '[dry-run] git -C $(REPO) submodule update --remote --merge --jobs 8'; \
	else \
		git -C $(REPO) submodule update --remote --merge --jobs 8; \
	fi
	@$(MAKE) build DOT_DRY_RUN="$(DOT_DRY_RUN)" DOT_DEBUG="$(DOT_DEBUG)" DOT_VERBOSE="$(DOT_VERBOSE)"
	@$(MAKE) helptags DOT_DRY_RUN="$(DOT_DRY_RUN)" DOT_DEBUG="$(DOT_DEBUG)" DOT_VERBOSE="$(DOT_VERBOSE)"

# ---- native build steps --------------------------------------------------
# These compile/install per-plugin native artifacts that submodule update
# alone does NOT produce. All sub-targets are best-effort: a failure in one
# does not abort the others (so missing toolchains degrade gracefully).
build: build-fzf-native build-fzf-bin build-luasnip-jsregexp build-treesitter ## Compile native artifacts (fzf, jsregexp, TS parsers)
	@echo '[build] done'

build-fzf-native:
	@$(RECIPE_ENV); \
	dir=$(REPO)/pack/nvim/opt/telescope-fzf-native.nvim; \
	 if [ ! -d "$$dir" ]; then echo '[build-fzf-native] not vendored, skipping'; exit 0; fi; \
	 if command -v cmake >/dev/null 2>&1; then \
	   echo '[build-fzf-native] cmake'; \
	   if [[ "$$dry" == "1" ]]; then \
	     echo "[dry-run] cmake -S $$dir -B $$dir/build -DCMAKE_BUILD_TYPE=Release"; \
	     echo "[dry-run] cmake --build $$dir/build --config Release"; \
	     exit 0; \
	   fi; \
	   cmake -S "$$dir" -B "$$dir/build" -DCMAKE_BUILD_TYPE=Release >/dev/null && \
	   cmake --build "$$dir/build" --config Release >/dev/null || \
	     { echo '[build-fzf-native] cmake build failed'; exit 0; }; \
	 elif command -v make >/dev/null 2>&1 && command -v cc >/dev/null 2>&1; then \
	   echo '[build-fzf-native] make'; \
	   if [[ "$$dry" == "1" ]]; then \
	     echo "[dry-run] $(MAKE) -C $$dir"; \
	     exit 0; \
	   fi; \
	   $(MAKE) -C "$$dir" >/dev/null || \
	     { echo '[build-fzf-native] make failed'; exit 0; }; \
	 else \
	   echo '[build-fzf-native] need cmake or (make+cc); skipping'; \
	 fi


build-fzf-bin:
	@$(RECIPE_ENV); \
	dir=$(REPO)/pack/shared/start/fzf; \
	 if [ ! -d "$$dir" ]; then echo '[build-fzf-bin] not vendored, skipping'; exit 0; fi; \
	 if [ -x "$$dir/bin/fzf" ]; then echo '[build-fzf-bin] already present'; exit 0; fi; \
	 if command -v fzf >/dev/null 2>&1; then \
	   echo "[build-fzf-bin] system fzf already on PATH ($$(command -v fzf)); skipping vendored install"; \
	   exit 0; \
	 fi; \
	 if [ -x "$$dir/install" ]; then \
	   echo '[build-fzf-bin] downloading prebuilt binary via vendored install --bin'; \
	   if [[ "$$dry" == "1" ]]; then \
	     echo "[dry-run] $$dir/install --bin"; \
	     exit 0; \
	   fi; \
	   "$$dir/install" --bin >/dev/null || echo '[build-fzf-bin] install --bin failed'; \
	 else \
	   echo '[build-fzf-bin] no install script found, skipping'; \
	 fi


build-luasnip-jsregexp:
	@$(RECIPE_ENV); \
	dir=$(REPO)/pack/nvim/opt/LuaSnip; \
	 if [ ! -d "$$dir" ]; then echo '[build-luasnip-jsregexp] not vendored, skipping'; exit 0; fi; \
	 if ! command -v make >/dev/null 2>&1 || ! command -v cc >/dev/null 2>&1; then \
	   echo '[build-luasnip-jsregexp] need make+cc; skipping (LSP snippet transformations disabled)'; \
	   exit 0; \
	 fi; \
	 echo '[build-luasnip-jsregexp] make install_jsregexp'; \
	 if [[ "$$dry" == "1" ]]; then \
	   echo "[dry-run] $(MAKE) -C $$dir install_jsregexp"; \
	   exit 0; \
	 fi; \
	 $(MAKE) -C "$$dir" install_jsregexp >/dev/null 2>&1 || \
	   echo '[build-luasnip-jsregexp] failed (optional; ignore unless you use LSP snippet transformations)'

build-treesitter:
	@$(RECIPE_ENV); \
	dir=$(REPO)/pack/nvim/opt/nvim-treesitter; \
	 if [ ! -d "$$dir" ]; then echo '[build-treesitter] not vendored, skipping'; exit 0; fi; \
	 if ! command -v nvim >/dev/null 2>&1; then \
	   echo '[build-treesitter] nvim not installed, skipping'; exit 0; fi; \
	 if ! command -v cc >/dev/null 2>&1 && ! command -v gcc >/dev/null 2>&1 && ! command -v clang >/dev/null 2>&1; then \
	   echo '[build-treesitter] no C compiler; parsers will fail to build'; exit 0; fi; \
	 echo '[build-treesitter] :TSUpdateSync (compiling configured parsers)'; \
	 if [[ "$$dry" == "1" ]]; then \
	   echo "[dry-run] nvim --headless -u $(REPO)/init.lua -c 'TSUpdateSync' -c 'qa!'"; \
	   exit 0; \
	 fi; \
	 nvim --headless -u $(REPO)/init.lua -c 'TSUpdateSync' -c 'qa!' </dev/null >/dev/null 2>&1 || \
	   echo '[build-treesitter] some parsers failed; run :TSUpdate inside nvim for details'


helptags: ## Regenerate vim/nvim helptags
	@$(RECIPE_ENV); \
	if [[ "$$dry" == "1" ]]; then \
		echo "[dry-run] vim -E -es -u $(REPO)/vimrc -c 'silent! helptags ALL' -c 'qa!'"; \
		echo "[dry-run] nvim --headless -u $(REPO)/init.lua -c 'silent! helptags ALL' -c 'qa!'"; \
	else \
		command -v vim  >/dev/null 2>&1 && vim  -E -es -u $(REPO)/vimrc   -c 'silent! helptags ALL' -c 'qa!' >/dev/null 2>&1 || true; \
		command -v nvim >/dev/null 2>&1 && nvim --headless -u $(REPO)/init.lua -c 'silent! helptags ALL' -c 'qa!' >/dev/null 2>&1 || true; \
	fi
	@echo '[helptags] regenerated'


doctor: ## Run plugin-status + :checkhealth in nvim
	@$(RECIPE_ENV); \
	fails=0; \
	echo "── vim doctor ──"; \
	echo ""; \
	echo "── dependencies ──"; \
	for cmd in vim nvim; do \
		if command -v $$cmd >/dev/null 2>&1; then \
			printf '  ✔  %s (%s)\n' "$$cmd" "$$($$cmd --version 2>/dev/null | head -1)"; \
		else \
			printf '  ✘  %s not found\n' "$$cmd"; \
			fails=$$((fails + 1)); \
		fi; \
	done; \
	echo ""; \
	echo "── config symlinks ──"; \
	nvim_cfg="$${XDG_CONFIG_HOME:-$$HOME/.config}/nvim"; \
	for pair in "$$HOME/.vim:$(REPO)" "$$nvim_cfg:$(REPO)"; do \
		p="$${pair%%:*}"; expect="$${pair#*:}"; \
		if [ -L "$$p" ]; then \
			target=$$(readlink "$$p"); \
			if [ "$$target" = "$$expect" ]; then \
				printf '  ✔  %-25s → %s\n' "$$p" "$$target"; \
			else \
				printf '  ✘  %-25s → %s (expected %s)\n' "$$p" "$$target" "$$expect"; \
				printf '      fix: ln -snf "%s" "%s"\n' "$$expect" "$$p"; \
				fails=$$((fails + 1)); \
			fi; \
		elif [ -e "$$p" ]; then \
			printf '  ✘  %-25s exists but is NOT a symlink\n' "$$p"; \
			printf '      fix: mv "%s" "%s.bak" && ln -snf "%s" "%s"\n' "$$p" "$$p" "$$expect" "$$p"; \
			fails=$$((fails + 1)); \
		else \
			printf '  ✘  %-25s missing\n' "$$p"; \
			printf '      fix: ln -snf "%s" "%s"\n' "$$expect" "$$p"; \
			fails=$$((fails + 1)); \
		fi; \
	done; \
	echo ""; \
	echo "── shared plugins ($(SHARED_BUNDLE)) ──"; \
	for d in $(REPO)/$(SHARED_BUNDLE)/*/; do \
		name=$$(basename "$$d"); \
		if [ "$$name" = "*" ]; then break; fi; \
		if [ -z "$$(ls -A "$$d" 2>/dev/null)" ]; then \
			printf '  ✘  %-30s empty (not checked out)\n' "$$name"; \
			fails=$$((fails + 1)); \
		else \
			printf '  ✔  %-30s ok\n' "$$name"; \
		fi; \
	done; \
	echo ""; \
	echo "── nvim plugins ($(NVIM_BUNDLE)) ──"; \
	for d in $(REPO)/$(NVIM_BUNDLE)/*/; do \
		name=$$(basename "$$d"); \
		if [ "$$name" = "*" ]; then break; fi; \
		if [ -z "$$(ls -A "$$d" 2>/dev/null)" ]; then \
			printf '  ✘  %-30s empty (not checked out)\n' "$$name"; \
			fails=$$((fails + 1)); \
		else \
			printf '  ✔  %-30s ok\n' "$$name"; \
		fi; \
	done; \
	echo ""; \
	if [ $$fails -gt 0 ]; then \
		echo "✘ $$fails issue(s) found"; \
		exit 1; \
	else \
		echo "✔ vim fully healthy"; \
	fi


plugins: ## Show staged plugins per editor
	@bash $(REPO)/scripts/plugin-status.sh

list: ## List vendored plugins
	@printf '\n[shared] pack/shared/start\n'
	@ls -1 $(REPO)/$(SHARED_BUNDLE) 2>/dev/null | grep -v '^\.gitkeep$$' || echo '  (empty)'
	@printf '\n[nvim]   pack/nvim/opt\n'
	@ls -1 $(REPO)/$(NVIM_BUNDLE)   2>/dev/null | grep -v '^\.gitkeep$$' || echo '  (empty)'
	@echo

# add: PLUGIN=owner/repo BUNDLE=shared|nvim
add: ## Vendor a new plugin (PLUGIN=owner/repo BUNDLE=shared|nvim)
	@test -n "$(PLUGIN)" || (echo 'usage: make add PLUGIN=owner/repo BUNDLE=shared|nvim' && exit 1)
	@$(RECIPE_ENV); \
	case "$(BUNDLE)" in shared) DEST=$(SHARED_BUNDLE) ;; nvim) DEST=$(NVIM_BUNDLE) ;; \
	  *) echo "BUNDLE must be 'shared' or 'nvim'"; exit 1;; esac; \
	NAME=$$(basename $(PLUGIN) .git); \
	if [ -d "$(REPO)/$$DEST/$$NAME" ] && [ -n "$$(ls -A "$(REPO)/$$DEST/$$NAME" 2>/dev/null)" ]; then \
		echo "[add] $$DEST/$$NAME already exists; skipping"; \
		exit 0; \
	fi; \
	echo "[add] $(PLUGIN) -> $$DEST/$$NAME"; \
	if [[ "$$dry" == "1" ]]; then \
		echo "[dry-run] git -C $(REPO) submodule add --depth 1 https://github.com/$(PLUGIN).git $$DEST/$$NAME"; \
	else \
		git -C $(REPO) submodule add --depth 1 https://github.com/$(PLUGIN).git $$DEST/$$NAME; \
	fi

# rm: PLUGIN=name BUNDLE=shared|nvim
rm: ## Remove a vendored plugin (PLUGIN=name BUNDLE=shared|nvim)
	@test -n "$(PLUGIN)" || (echo 'usage: make rm PLUGIN=name BUNDLE=shared|nvim' && exit 1)
	@$(RECIPE_ENV); \
	case "$(BUNDLE)" in shared) DEST=$(SHARED_BUNDLE) ;; nvim) DEST=$(NVIM_BUNDLE) ;; \
	  *) echo "BUNDLE must be 'shared' or 'nvim'"; exit 1;; esac; \
	if ! git -C $(REPO) config -f .gitmodules --get "submodule.$$DEST/$(PLUGIN).url" >/dev/null 2>&1; then \
		echo "[rm] $$DEST/$(PLUGIN) not registered in .gitmodules; nothing to do"; \
		exit 0; \
	fi; \
	echo "[rm] $$DEST/$(PLUGIN)"; \
	if [[ "$$dry" == "1" ]]; then \
		echo "[dry-run] git -C $(REPO) submodule deinit -f $$DEST/$(PLUGIN)"; \
		echo "[dry-run] git -C $(REPO) rm -f $$DEST/$(PLUGIN)"; \
		echo "[dry-run] rm -rf $(REPO)/.git/modules/$$DEST/$(PLUGIN)"; \
	else \
		git -C $(REPO) submodule deinit -f $$DEST/$(PLUGIN) || true; \
		git -C $(REPO) rm -f $$DEST/$(PLUGIN) || true; \
		rm -rf $(REPO)/.git/modules/$$DEST/$(PLUGIN); \
	fi

clean: ## Remove ~/.vim and ~/.config/nvim symlinks
	@$(RECIPE_ENV); \
	for p in $$HOME/.vim $$HOME/.config/nvim; do \
	  if [ -L "$$p" ] && [ "$$(readlink $$p)" = "$(REPO)" ]; then \
	    echo "[clean] removing symlink $$p"; \
	    if [[ "$$dry" == "1" ]]; then \
	      echo "[dry-run] rm -f $$p"; \
	    else \
	      rm -f "$$p"; \
	    fi; \
	  fi; \
	done
