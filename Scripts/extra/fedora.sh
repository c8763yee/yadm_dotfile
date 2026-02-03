#!/bin/bash
# Fedora-specific packages (different names)

sudo dnf install -y \
	fd-find \
	git-delta \
	yarn \
	ncurses-devel \
	openssl-devel \
	elfutils-libelf-devel \
	dwarves \
	git-email

sudo dnf --enablerepo=fedora-debuginfo,updates-debuginfo install kernel-debuginfo
