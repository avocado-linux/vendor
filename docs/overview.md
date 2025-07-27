# Overview

This repository is a tool for managing Avocado vendored repositories:

- Creating the origin repository.
- Specifying the mapping between upstreams and origins.
- Syncing changes from upstreams to origins.

## Avocado vendored repositories

Avocado vendored repositories (AVRs) are repositories in the `avocado-linux` GitHub organization
whose names are prefixed with `vendor-`.

### Why

AVRs provide an Avocado-operated git remote for a dependency.

### Data model

AVRs have the following attributes:

- `upstream` - The source remote.
- `origin` - The destination remote.

### How

AVRs sync changes from upstreams to origins. This process is driven via manual execution of
scripts provided by this repository. See [usage](usage.md).

## Git submodules

This repository uses Git submodules in its specification of AVRs.

In the `.gitmodules` file, a submodule entry for an AVR will look like:

```text
[submodule "repo-name"]
        path = repo-name
        url = ssh://git@github.com/avocado-linux/vendor-repo-name.git
        upstream = ssh://git@github.com/upstream-owner/repo-name.git
```

Note the `upstream` key is custom. An AVR's origin is denoted by the `url` key. An AVR's upstream
is denoted by the `upstream` key.
