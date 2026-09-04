# Contributing

Follow the [Code of Conduct](CODE_OF_CONDUCT.md). Use synthetic data in examples
and report sensitive concerns through [SECURITY.md](SECURITY.md).

## Setup and current checks

Python 3.12 or newer is enough for the feature builder. MySQL work requires
MySQL 8.0 or newer and a disposable local database; see [README.md](README.md).

```bash
python3 -m py_compile scripts/build_features.py
python3 scripts/build_features.py --help
git diff --check
```

These checks validate Python syntax and the CLI, not query semantics. The
repository has no automated tests yet. Do not report this baseline as a passing
MySQL integration suite. The full NVIDIA script currently has a schema mismatch.

## SQL and analysis changes

Use a fresh disposable schema and execute every changed query. Check row counts,
NULLs, join cardinality, dates, and outcome alignment against small examples
whose expected results can be calculated by hand. Add regression tests alongside
behavior changes as the test harness is introduced. Quote `S&P500.sql` in shell
commands because the filename contains an ampersand.

For Python debugging, use synthetic inputs:

```bash
python3 -m pdb scripts/build_features.py data/prices.csv -o outputs/features.csv
```

Keep raw inputs in `data/` and generated files in `outputs/`. Never place a database
password in a SQL file or command example.

Numerical findings must specify dataset provenance, adjustment policy, date
range, null exclusions, and reproduction commands. Separate exploratory
observations from claims validated on new data. Preserve the historical
explanation when correcting a methodological error.

Use focused PRs with exact validation results and an Unreleased changelog entry.
Avoid em and en dashes in documentation, comments, and commit messages.
Link incomplete work with a TODO and issue. See [maintainer guidance](docs/maintenance.md).
