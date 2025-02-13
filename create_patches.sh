#!/bin/bash
script_dp="$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd
source "$script_dp/_create_patches_util.sh"

# This script expects the following parameter:
# 	the path to a (MODIFIED) colmap source directory for wich a set of patches should be computed 

if [ $# -lt 3 ] || [ $# -gt 5 ]; then
    echo "Script expects beteen 2 and 4 parameters, but ${#} provided!" >&2
    echo "Usage: $0 <path_to_MODIFIED_colmap_source> <patch_dp> <commit_ofp> <overwrite_flag> <reset_index_changes>"
    echo "The last parameters <overwrite_flag> and <reset_index_changes> are optional."
    exit 2
fi

original_dp=$PWD

modified_colmap_source_dp=$1
patch_dp=$2
commit_ofp=$3
overwrite_patch_file=${4:-1}   # Set 1 as default parameter
reset_index_changes=${5:-1}    # Set 1 as default parameter

echo "Reading colmap from: $modified_colmap_source_dp"

# Go to the directory where the script is located
cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd
sh_file_dp=$PWD

echo "Creating patch files in: $patch_dp"

cd $modified_colmap_source_dp
git branch

unmerged_files=$(git diff --name-only --diff-filter=U)
if [ -n "$unmerged_files" ]; then
    echo "Found the following unmerged files:"
    echo "$unmerged_files"
    echo "Open the file(s) with VSCode, resolve the conflicts and click on complete merge"
    echo "Afterwards, run this script again"
    exit
fi

staged_files=$(git diff --name-only --staged)
if [ -n "$staged_files" ]; then
    git restore --staged .
fi

git_diff_files=$(git diff --name-only)

for file_path in $git_diff_files; do
  # Process each file (e.g., print its name or perform some action)
  echo "File with changes: $file_path"
  file_path_encoded=$(encode_path_as_filename $file_path)
  patch_file_name="${file_path_encoded}.patch"
  create_patch $file_path $patch_file_name
done

# Write the current commit SHA and corresponding information to output file
commit_sha=$(git rev-parse HEAD)
commit_date="$(git show -s --format=%ci $commit_sha)"
commit_message="$(git log -n 1 --pretty=format:%B $COMMIT_SHA | head -n 1)"
# Clear the file
> $commit_ofp
echo "$commit_sha   ($commit_date)" >> $commit_ofp
echo "$commit_message" >> $commit_ofp

cd $original_dp
