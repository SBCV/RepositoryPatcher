# Repository Patcher

A common approach to modifying repositories without writing permissions is to `fork` the repository. However, updating the `fork` with the latest changes from the original repository is often challenging due to merge conflicts.

Instead of directly merging the codebases, this repository breaks down the merging process into simpler subtasks. By iterating over the commit history it allows to adjust the code changes on commit and file level.

To implement this strategy, this repository uses `patch files` that reflect the current code adaptations. It contains scripts to simplify tasks like creating, updating or applying a set of `patch files`.

# Installation
It is recommended to define an environment variable pointing to the location where `Repository Patcher` resides on disk.
```
export PathToRepositoryPatcher="path/to/RepositoryPatcher"
```
Add the previous command to `.bashrc` to make it persistent.

Clone the repository with:
```
git clone https://github.com/SBCV/RepositoryPatcher $PathToRepositoryPatcher
```
Ensure that the scripts have execute permissions. For example, by running:
```
chmod +x $PathToRepositoryPatcher/create_patches.sh
chmod +x $PathToRepositoryPatcher/apply_patches.sh
chmod +x $PathToRepositoryPatcher/clean_reject_files.sh
```
Verify the permissions - for example with:
```
ls -l $PathToRepositoryPatcher/apply_patches.sh
```

## Configuration of the target repository and the patch directory 

Define two (temporary) variables storing the locations of the patch files and the target repository:
```
export PathToPatchFiles="path/to/ColmapForVisSatPatches"
export PathToTargetRepository="path/to/ColmapToBePatched"
```
As an example we will use the repositories [Colmap](https://github.com/colmap/colmap) and [ColmapForVisSatPatches](https://github.com/SBCV/ColmapForVisSatPatches).
Clone the repositories with:
```
git clone https://github.com/colmap/colmap.git $PathToTargetRepository
git clone https://github.com/SBCV/ColmapForVisSatPatches.git $PathToPatchFiles
```

## Create a set of patch files from the original repository
Modify the target repository as needed. Then, run:
```
$PathToRepositoryPatcher/create_patches.sh <PathToTargetRepository> <overwrite_flag> <reset_index_changes_flag>
```
For instance:
```
$PathToRepositoryPatcher/create_patches.sh $PathToTargetRepository 1 0
```

## Apply a set of patch files to the target repository

Before you apply the patches, ensure that the target repository is up-to-date and the `main` branch is active. Note: the `apply_patches.sh` script will add new branches in the target repository as needed.
```
cd $PathToTargetRepository
git reset --hard HEAD
git switch main
git pull
```
Finally, apply the patches with the following command. Possible values for `<options>` are `--reject` and --`3way`. The value for `<target_commit_hash>` is optional.
```
$PathToRepositoryPatcher/apply_patches.sh <tool> <options> $PathToTargetRepository <compatible_commit_hash> <target_commit_hash>
```
For instance:
```
# Current patch files are created for 64916f856259d8386df96bc95e0eb28cd5fca86e (2023-03-01 20:54:52 +0000)
$PathToRepositoryPatcher/apply_patches.sh git_apply --reject $PathToTargetRepository 64916f856259d8386df96bc95e0eb28cd5fca86e
```
Note: Do NOT run `apply_patches.sh` with `sh $PathToRepositoryPatcher/apply_patches.sh` - this will not produce the required results!


## Update patch files for newer versions of the target repository

Add a `<target_commit_hash>` to the `apply_patches.sh` call.

```
$PathToRepositoryPatcher/apply_patches.sh <tool> <options> $PathToTargetRepository <compatible_commit_hash> <target_commit_hash>
```
For instance, you can use `HEAD` to point to the latest commit.
```
$PathToRepositoryPatcher/apply_patches.sh git_apply <options> $PathToTargetRepository 64916f856259d8386df96bc95e0eb28cd5fca86e HEAD
```
This will iterate over all commits from `<compatible_commit_hash>` to `<target_commit_hash>` and try to individually apply each patch. If the application of the patch (i.e. the merge) fails, the script depending on the value of `<option>` will do the following:

### Case `--reject`:

For the current `conflicting_file.ext` the script will create a rejection file `conflicting_file.ext.rej`. The rejection file contains all conflicting hunks that could not be merged.

Use Github or [PatchViewer](https://megatops.github.io/PatchViewer/) to view the corresponding patch file (e.g. [src__base__cost_functions.h.patch](https://github.com/SBCV/ColmapForVisSatPatches/blob/main/patches/src__base__cost_functions.h.patch)) - it will highlight the required changes. Copy the desired changes (i.e. the green parts) to corresponding place in the source code in `$PathToColmapLatest`!

After merging the hunks, use
```
$PathToRepositoryPatcher/create_patches.sh $PathToTargetRepository 1 1
```
to update the set of patches in `$PathToPatchFiles/patches` (overwriting previously outdated patches). Repeat this procedure until all conflicts are resolved.

### Case `--3way`: (Recommended)

Use the apply script with the `git_apply --3way` to write conflict markers into the affected files. For each conflicting hunk the script adds the code from the file to be patched between `<<<<<<< ours` and `=======`, and the code from the patch file between `=======` and `>>>>>>> theirs`. IMPORTANT: because 3-way merging uses a common base file for merging, the content between `=======` and `>>>>>>> theirs` MIGHT DIFFER from the actual hunk in the patch file (for example, this part might contain also context lines of the original hunk). With the conflict markers one can use the 3-way view of `VSCode` to merge the results (see below).

In `VSCode` open the file with the conflict markers, and click on the bottom right on `Resolve in Merge Editor`. In the `Merge Editor` the top left pane (`incomming`) represents the content of the `patch` file and the top right (`current`) represents the file that should be patched (i.e. the current commit of the vanilla target repository). The bottom pane shows the current state of the merged result. Click on the toolbar of the bottom pane on `X Conflicts Remaining` to jump to the next conflict (relative to the current selected line). After merging the hunks click on `Complete Merge` on the bottom right of the merged result in the bottom pane. This is essential to convert the `3way` merge to an updated `2way` merge. Important: non-matching hunk contexts ARE SHOWN AS SEPARATE conflicts. This is a huge advantage compared to the plain conflict markers and to the visualization in other tools such as `meld`.

After merging the hunks, use
```
$PathToRepositoryPatcher/create_patches.sh $PathToTargetRepository 1 1
```
to update the set of patches in `$PathToPatchFiles/patches` overwriting previously generated (outdated) patches. Repeat this procedure until all conflicts are resolved.

## Useful notes

### Get the next commit id
`git log --format="%H" --reverse <current_commit_sha>..HEAD | head -n 1`

### Handle Skipping of Rename Detection
If you observe
```
warning: inexact rename detection was skipped due to too many files.
warning: you may want to set your diff.renameLimit variable to at least 568 and retry the command.
```
run somethng like:
`git config --global diff.renameLimit 1000`
