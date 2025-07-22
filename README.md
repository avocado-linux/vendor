# Managing Vendored Layers

This repository serves as a superproject to manage vendored dependencies using Git submodules. Each submodule is a dependency that we vendor from an upstream source.

Two main scripts help manage this process:
- `vendor-repo.sh`: For adding a new dependency.
- `update-all.sh`: For syncing all existing dependencies with their upstream sources.

---

## Vendoring a New Library

To add a new dependency, use the `vendor-repo.sh` script. This script will clone the upstream repository, set up our internal mirror as the `origin` remote, and add it as a submodule to this superproject.

### Usage

1.  Run the script with the upstream repository's URL. You can also provide an optional GitHub organization name, which defaults to `avocado-linux`.
    ```bash
    ./vendor-repo.sh <upstream-repo-url> [github-org]
    ```
    For example, to use the default organization:
    ```bash
    ./vendor-repo.sh https://github.com/upstream/project.git
    ```
    Or to specify a different organization:
    ```bash
    ./vendor-repo.sh https://github.com/upstream/project.git my-other-org
    ```

2.  The script will perform the necessary steps and stage the new submodule. Review the changes to ensure everything is correct:
    ```bash
    git status
    ```

3.  Commit the newly added submodule to the superproject:
    ```bash
    git commit -m "feat: add new vendor library project"
    ```

---

## Syncing All Repositories

To update all vendored dependencies at once, use the `update-all.sh` script. This script iterates through each submodule directory, fetches the latest changes from the `upstream` remote, resets the local branches to match their upstream counterparts, and then pushes all branches to our `origin` remote.

### Usage

1.  Run the update script from the root of this repository:
    ```bash
    ./update-all.sh
    ```

2.  The script will update each submodule, which will change the commit they point to in this superproject. After the script finishes, stage the changes:
    ```bash
    git add .
    ```

3.  Commit the updated submodule references:
    ```bash
    git commit -m "chore: sync all vendor libraries to latest upstream"
    ```
