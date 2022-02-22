.PHONY: create-env

create-env:
	conda create -y -p ./conda_env python=3.9 && \
	pip install mkdocs mkdocs-material pymdown-extensions
