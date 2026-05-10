# Self-contained vim + nvim configuration.
# Plugins are vendored as git submodules under pack/{shared,nvim}/{start,opt}.

REPO            := $(shell pwd)
SHARED_BUNDLE   := pack/shared/start
NVIM_BUNDLE     := pack/nvim/opt
BUNDLE          ?= shared
PLUGIN          ?=

.PHONY: help install update helptags clean add rm doctor list

help:
	@printf 'Targets:\n'
	@printf '  make install                    Run install.sh (symlinks + submodule init).\n'
	@printf '  make update                     Pull latest for every floated submodule.\n'
	@printf '  make helptags                   Regenerate vim/nvim helptags.\n'
	@printf '  make doctor                     Run :checkhealth in nvim.\n'
	@printf '  make list                       List vendored plugins.\n'
	@printf '  make add PLUGIN=owner/repo BUNDLE=shared|nvim   Vendor a new plugin.\n'
	@printf '  make rm  PLUGIN=name BUNDLE=shared|nvim         Remove a vendored plugin.\n'
	@printf '  make clean                      Remove ~/.vim and ~/.config/nvim symlinks.\n'

install:
	@bash $(REPO)/install.sh

update:
	@echo '[update] git submodule update --remote --merge --jobs 8'
	@git -C $(REPO) submodule update --remote --merge --jobs 8
	@$(MAKE) helptags

helptags:
	@command -v vim  >/dev/null 2>&1 && vim  -E -es -u $(REPO)/vimrc   -c 'silent! helptags ALL' -c 'qa!' >/dev/null 2>&1 || true
	@command -v nvim >/dev/null 2>&1 && nvim --headless -u $(REPO)/init.lua -c 'silent! helptags ALL' -c 'qa!' >/dev/null 2>&1 || true
	@echo '[helptags] regenerated'

doctor:
	@nvim --headless -u $(REPO)/init.lua -c 'checkhealth' -c 'qa!' || true

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
