BOOTSTRAP_PYTHON_VERSION        := 3.7
BOOTSTRAP_PYTHON_PREFIX         := /usr/bin
BOOTSTRAP_PYTHON_BIN_PATH       := ~/Library/Python/$(BOOTSTRAP_PYTHON_VERSION)/bin
BOOTSTRAP_PIP                   := $(BOOTSTRAP_PYTHON_PREFIX)/python3 -m pip 

PYTHON_VERSION                  := 3.8
PYTHON_PREFIX                   := /usr/local/bin
PYTHON_BIN_PATH                 := ~/Library/Python/$(PYTHON_VERSION)/bin
PYTHON                          := $(PYTHON_PREFIX)/python3
PIP                             := $(PYTHON) -m pip 

MACOS_VERSION                   := 10.14
MACOS_SDK_HEADERS_PKG           := /Library/Developer/CommandLineTools/Packages/macOS_SDK_headers_for_macOS_$(MACOS_VERSION).pkg
LOCAL_PROJECT_DIRECTORY         := $(shell pwd)
ANSIBLE_DIRECTORY               := .
ANSIBLE_PLAYBOOKS_DIRECTORY     := $(ANSIBLE_DIRECTORY)
ANSIBLE_ROLES_DIRECTORY         := $(ANSIBLE_DIRECTORY)/roles
ANSIBLE_INVENTORY               := $(ANSIBLE_DIRECTORY)/hosts
ANSIBLE_VERBOSE                 := -v
ANSIBLE_VAULT_PASSWORD_FILE     := $(ANSIBLE_DIRECTORY)/.ansible_vault_password
ANSIBLE_SENSITIVE_CONTENT_FILES := \
  $(ANSIBLE_ROLES_DIRECTORY)/better-touch-tool/files/license.xml \
  $(ANSIBLE_ROLES_DIRECTORY)/awscli/files/credentials \
  $(ANSIBLE_ROLES_DIRECTORY)/ssh-keys/files/mpereira@pluto \
  $(ANSIBLE_ROLES_DIRECTORY)/ssh-keys/files/mpereira@argonaut \
  $(ANSIBLE_ROLES_DIRECTORY)/s3cmd/files/.s3cfg \
  $(ANSIBLE_ROLES_DIRECTORY)/dotfiles/vars/environment.yml \
  $(ANSIBLE_ROLES_DIRECTORY)/prey/vars/api_key.yml

ANSIBLE := \
	$(PYTHON_BIN_PATH)/ansible-playbook $(ANSIBLE_VERBOSE) \
		-i $(ANSIBLE_INVENTORY) \
		--extra-vars "local_project_directory=$(LOCAL_PROJECT_DIRECTORY)" \
		$(ARGS)

ANSIBLE_LOCAL := \
	$(PYTHON_BIN_PATH)/ansible-playbook $(ANSIBLE_VERBOSE) \
		-i $(ANSIBLE_INVENTORY) \
		--extra-vars "local_project_directory=$(LOCAL_PROJECT_DIRECTORY)" \
		$(ARGS)

ANSIBLE_LOCAL_WITH_VAULT := \
	$(ANSIBLE_LOCAL) --vault-password-file $(ANSIBLE_VAULT_PASSWORD_FILE)

ANSIBLE_VAULT = \
	$(PYTHON_BIN_PATH)/ansible-vault $(1) \
		--vault-password-file $(ANSIBLE_VAULT_PASSWORD_FILE)

.PHONY: \
	clean_bootstrap_pip \
	get_bootstrap_pip \
	bootstrap \
	upgrade_pip \
	upgrade_ansible \
	converge \
	encrypt \
	decrypt \
	encrypt_pre_commit

# This might be required if you're seeing errors like "ImportError: No module
# named _internal".
# $ sudo python -m pip uninstall pip
# Uninstalling pip-9.0.1:
#   /Library/Python/2.7/site-packages/pip-9.0.1-py2.7.egg
#   /usr/local/bin/pip
#   /usr/local/bin/pip2
#   /usr/local/bin/pip2.7
clean_bootstrap_pip:
	sudo python -m pip uninstall pip

# only required for Mojave.
get_bootstrap_pip:
	curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
	python get-pip.py --user --force-reinstall
	rm -f get-pip.py

.ansible_vault_password:
	@test -s $(ANSIBLE_VAULT_PASSWORD_FILE) \
		|| echo "ATTENTION: Please create '$(PWD)/$(ANSIBLE_VAULT_PASSWORD_FILE)' with this project's Ansible Vault password" && exit 1

# TODO: install Python 3 manually outside Ansible? Only required for Mojave.
bootstrap: upgrade_pip
	$(BOOTSTRAP_PIP) install --user ansible
	sudo $(ANSIBLE_LOCAL_WITH_VAULT) $(ANSIBLE_PLAYBOOKS_DIRECTORY)/bootstrap.yml
	$(PIP) install --user ansible

upgrade_pip:
	@$(PIP) install --upgrade pip

# six on Mojave: https://github.com/pypa/pip/issues/3165#issuecomment-146666737
upgrade_ansible:
	@$(PIP) install --user --upgrade ansible

converge:
	@$(ANSIBLE_LOCAL_WITH_VAULT) $(ANSIBLE_PLAYBOOKS_DIRECTORY)/main.yml

encrypt:
	$(call ANSIBLE_VAULT,encrypt) $(ANSIBLE_SENSITIVE_CONTENT_FILES)

decrypt:
	$(call ANSIBLE_VAULT,decrypt) $(ANSIBLE_SENSITIVE_CONTENT_FILES)

.PHONY: truncate-sensitive-files
truncate-sensitive-files:
	@truncate --size 0 $(ANSIBLE_SENSITIVE_CONTENT_FILES)

encrypt_pre_commit: encrypt
	@git add $(ANSIBLE_SENSITIVE_CONTENT_FILES)
