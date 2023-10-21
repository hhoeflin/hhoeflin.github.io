.ONESHELL:
SHELL:=/bin/bash

.PHONY: create-env

create-env:
	mamba create -y -p ./conda_env python=3.11
	mamba activate ./conda_env
	pip install mkdocs mkdocs-material pymdown-extensions

format-md:
	prettier -w --prose-wrap=always docs/**/*.md
