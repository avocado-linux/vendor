# Usage

## Setup

Idempotently ensure all submodules are initialized and configured.

```bash
# Setup all submodules.
./setup-submodules.sh

# Setup some submodules.
./setup-submodules.sh submodule-one submodule-n
```

## Vendor

Vendor a repository by specifying the upstream URL. The empty remote origin must already have been
created manually.

```bash
./vendor-repo.sh ssh://hostname/owner/repo.git
```

## Update

Update all or some vendored repositories by pulling from upstream and pushing to origin. Note the
pull will update your local submodules and the push will update the remote upstream.

```bash
# Update all vendored repositories.
./update.sh

# Update some vendored repositories.
./update.sh submodule-one submodule-n
```
