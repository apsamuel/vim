# Self-contained vim + nvim configuration.
# Plugins are vendored as git submodules under pack/{shared,nvim}/{start,opt}.

REPO            := $(shell pwd)
SHARED_BUNDLE   := pack/shared/start
NVIM_BUNDLE     := pack/nvim/opt
BUNDLE          ?= shared
PLUGIN          ?=

.PHONY: help install update helptags clean add rm doctor list plugins build \
        build-fzf-native build-fzf-bin build-luasnip-jsregexp build-treesitter

help:
	@printf 'Targets:\n'
	@printf '  make install                    Run install.sh (symlinks + submodules + build).\n'
	@printf '  make build                      Compile native artifacts (fzf-native, fzf bin, jsregexp, TS parsers).\n'
	@printf '  make update                     Pull latest for every floated submodule, then rebuild.\n'
	@printf '  make helptags                   Regenerate vim/nvim helptags.\n'
	@printf '  make plugins                    Show which staged plugins each editor actually loads.\n'
	@printf '  make doctor                     Run plugin-status + :checkhealth in nvim.\n'
	@printf '  make list                       List vendored plugins.\n'
	@printf '  make add PLUGIN=owner/repo BUNDLE=shared|nvim   Vendor a new plugin.\n'
	@printf '  make rm  PLUGIN=name BUNDLE=shared|nvim         Remove a vendored plugin.\n'
	@printf '  make clean                      Remove ~/.vim and ~/.config/nvim symlinks.\n'

install:
	@bash $(REPO)/install.sh

update:
	@echo '[update] git submodule update --remote --merge --jobs 8'
	@git -C $(REPO) submodule update --remote --merge --jobs 8
	@$(MAKE) build
	@$(MAKE) helptags

# ---- native build steps --------------------------------------------------
# These compile/install per-plugin native artifacts that submodule update
# alone does NOT produce. All sub-targets are best-effort: a failure in one
# does not abort the others (so missing toolchains degrade gracefully).
build: build-fzf-native build-fzf-bin build-luasnip-jsregexp build-treesitter
	@echo '[build] done'

build-fzf-native:
	@dir=$(REPO)/pack/nvim/opt/telescope-fzf-native.nvim; \
	 if [ ! -d "$$dir" ]; then echo '[build-fzf-native] not vendored, skipping'; exit 0; fi; \
	 if command -v cmake >/dev/null 2>&1; then \
	   echo '[build-fzf-native] cmake'; \
	   cmake -S "$$dir" -B "$$dir/build" -DCMAKE_BUILD_TYPE=Release >/dev/null && \
	   cmake --build "$$dir/build" --config Release >/dev/null || \
	     { echo '[build-fzf-native] cmake build failed'; exit 0; }; \
	 elif command -v make >/dev/null 2>&1 && command -v cc >/dev/null 2>&1; then \
	   echo '[build-fzf-native] make'; \
	   $(MAKE) -C "$$dir" >/dev/null || \
	     { echo '[build-fzf-native] make failed'; exit 0; }; \
	 else \
	   echo '[build-fzf-native] need cmake or (make+cc); skipping'; \
	 fi

build-fzf-bin:
	@dir=$(REPO)/pack/shared/start/fzf; \
	 if [ ! -d "$$dir" ]; then echo '[build-fzf-bin] not vendored, skipping'; exit 0; fi; \
	 if [ -x "$$dir/bin/fzf" ]; then echo '[build-fzf-bin] already present'; exit 0; fi; \
	 if command -v fzf >/dev/null 2>&1; then \
	   echo "[build-fzf-bin] system fzf already on PATH ($$(command -v fzf)); skipping vendored install"; \
	   exit 0; \
	 fi; \
	 if [ -x "$$dir/install" ]; then \
	   echo '[build-fzf-bin] downloading prebuilt binary via vendored install --bin'; \
	   "$$dir/install" --bin >/dev/null || echo '[build-fzf-bin] install --bin failed'; \
	 else \
	   echo '[build-fzf-bin] no install script found, skipping'; \
	 fi

build-luasnip-jsregexp:
	@dir=$(REPO)/pack/nvim/opt/LuaSnip; \
	 if [ ! -d "$$dir" ]; then echo '[build-luasnip-jsregexp] not vendored, skipping'; exit 0; fi; \
	 if ! command -v make >/dev/null 2>&1 || ! command -v cc >/dev/null 2>&1; then \
	   echo '[build-luasnip-jsregexp] need make+cc; skipping (LSP snippet transformations disabled)'; \
	   exit 0; \
	 fi; \
	 echo '[build-luasnip-jsregexp] make install_jsregexp'; \
	 $(MAKE) -C "$$dir" install_jsregexp >/dev/null 2>&1 || \
	   echo '[build-luasnip-jsregexp] failed (optional; ignore unless you use LSP snippet transformations)'

build-treesitter:
	@dir=$(REPO)/pack/nvim/opt/nvim-treesitter; \
	 if [ ! -d "$$dir" ]; then echo '[build-treesitter] not vendored, skipping'; exit 0; fi; \
	 if ! command -v nvim >/dev/null 2>&1; then \
	   echo '[build-treesitter] nvim not installed, skipping'; exit 0; fi; \
	 if ! command -v cc >/dev/null 2>&1 && ! command -v gcc >/dev/null 2>&1 && ! command -v clang >/dev/null 2>&1; then \
	   echo '[build-treesitter] no C compiler; parsers will fail to build'; exit 0; fi; \
	 echo '[build-treesitter] :TSUpdateSync (compiling configured parsers)'; \
	 nvim --headless -u $(REPO)/init.lua -c 'TSUpdateSync' -c 'qa!' </dev/null >/dev/null 2>&1 || \
	   echo '[build-treesitter] some parsers failed; run :TSUpdate inside nvim for details'

helptags:
	@command -v vim  >/dev/null 2>&1 && vim  -E -es -u $(REPO)/vimrc   -c 'silent! helptags ALL' -c 'qa!' >/dev/null 2>&1 || true
	@command -v nvim >/dev/null 2>&1 && nvim --headless -u $(REPO)/init.lua -c 'silent! helptags ALL' -c 'qa!' >/dev/null 2>&1 || true
	@echo '[helptags] regenerated'

doctor:
	@bash $(REPO)/scripts/plugin-status.sh || true
	@nvim --headless -u $(REPO)/init.lua -c 'checkhealth' -c 'qa!' || true

plugins:
	@bash $(REPO)/scripts/plugin-status.sh

list:
	@printf '\n[shared] pack/shared/start\n'
	@ls -1 $(REPO)/$(SHARED_BUNDLE) 2>/dev/null | grep -v '^\.gitkeep$$' || echo '  (empty)'
	@printf '\n[nvim]   pack/nvim/opt\n'
	@ls -1 $(REPO)/$(NVIM_BUNDLE)   2>/dev/null | grep -v '^\.gitkeep$$' || echo '  (empty)'
	@echo

# add: PLUGIN=owner/repo BUNDLE=shared|nvim
add:
	@test -n "$(PLUGIN)" || (echo 'usage: make add PLUGIN=owner/repo BUNDLE=shared|nvim' && exit 1)
	@case "$(BUNDLE)" in shared) DEST=$(SHARED_BUNDLE) ;; nvim) DEST=$(NVIM_BUNDLE) ;; \
	  *) echo "BUNDLE must be 'shared' or 'nvim'"; exit 1;; esac; \
	NAME=$$(basename $(PLUGIN) .git); \
	echo "[add] $(PLUGIN) -> $$DEST/$$NAME"; \
	git -C $(REPO) submodule add --depth 1 https://github.com/$(PLUGIN).git $$DEST/$$NAME

# rm: PLUGIN=name BUNDLE=shared|nvim
rm:
	@test -n "$(PLUGIN)" || (echo 'usage: make rm PLUGIN=name BUNDLE=shared|nvim' && exit 1)
	@case "$(BUNDLE)" in shared) DEST=$(SHARED_BUNDLE) ;; nvim) DEST=$(NVIM_BUNDLE) ;; \
	  *) echo "BUNDLE must be 'shared' or 'nvim'"; exit 1;; esac; \
	echo "[rm] $$DEST/$(PLUGIN)"; \
	git -C $(REPO) submodule deinit -f $$DEST/$(PLUGIN); \
	git -C $(REPO) rm -f $$DEST/$(PLUGIN); \
	rm -rf $(REPO)/.git/modules/$$DEST/$(PLUGIN)

clean:
	@for p in $$HOME/.vim $$HOME/.config/nvim; do \
	  if [ -L "$$p" ] && [ "$$(readlink $$p)" = "$(REPO)" ]; then \
	    echo "[clean] removing symlink $$p"; rm -f "$$p"; \
	  fi; \
	done
