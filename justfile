setup-pre-commit:
    #!/usr/bin/env sh
    echo "#!/bin/sh" > .git/hooks/pre-commit
    echo "echo 'Running pre-commit checks...'" >> .git/hooks/pre-commit
    echo "if ! just pre-commit; then" >> .git/hooks/pre-commit
    echo "  echo 'Pre-commit checks failed. Commit aborted.'" >> .git/hooks/pre-commit
    echo "  exit 1" >> .git/hooks/pre-commit
    echo "fi" >> .git/hooks/pre-commit
    echo "exit 0" >> .git/hooks/pre-commit
    chmod +x .git/hooks/pre-commit
    echo "Pre-commit hook installed successfully!"

ensure-codespell:
    #!/usr/bin/env sh
    if ! command -v codespell > /dev/null; then \
      echo "Aborting: codespell not found in PATH" >&2; \
      exit 1; \
    fi

pre-commit: compile eunit

publish:
    rebar3 hex publish

docs:
    rebar3 ex_doc skip_deps=true

spellcheck: ensure-codespell
    #!/usr/bin/env sh
    codespell

spellfix: ensure-codespell
    #!/usr/bin/env sh
    codespell -i 3 -w

dialyzer:
    rebar3 dialyzer

xref:
    rebar3 xref

compile:
    rebar3 compile

eunit:
    rebar3 eunit

cover:
	rebar3 cover

ct:
	rebar3 as test ct


test: eunit cover ct
