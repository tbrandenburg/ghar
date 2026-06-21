.PHONY: test

test:
	git ls-files '*.md' | grep -v '^\.' | xargs markdownlint
	yamllint .github/workflows/*.yml
	actionlint
