#!/bin/bash
SCRIPT_DP="$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd
source "$SCRIPT_DP/patch_util.sh"

# This script expects the following parameter:
#   - mode (reject or 3way) for applying the patches
# 	- the path to the colmap source directory wich will be modified using a set of patches
#   - the commit SHA-1 hash of the colmap version compatible to the patch files
#   - the commit SHA-1 hash or "latest" of the colmap version we would like to update the patch files (optional)

# TODO: Consider other tools such as:
#   - patch: https://wiki.ubuntuusers.de/patch/
#   - wiggle: https://manpages.ubuntu.com/manpages/focal/man1/wiggle.1.html

if [ $# -lt 5 ] || [ $# -gt 7 ]; then
    echo "Script expects between 5 and 7 parameters, but ${#} provided!" >&2
    echo "Usage: $0 <tool> <options> <patch_dp> <target_repository_dp> <colmap_compatible_commit_hash> <colmap_target_commit_hash> <max_iterations>"
    echo "Valid values for the <mode> parameter are reject and 3way".
    echo "The last parameter <colmap_target_hash> is optional. Can be set to HEAD."
    exit 2
fi

TOOL=$1
OPTIONS=$2
PATCH_DP=$3
COLMAP_TARGET_DP=$4
COLMAP_COMPATIBLE_COMMIT_HASH=$5
COLMAP_TARGET_COMMIT_HASH=${6:-$5}
max_iterations=${7:--1}

if [ $TOOL == "git_apply" ]; then
    case "$OPTIONS" in
    --reject|--3way|--stat|--check)
        # Valid parameter, continue
        ;;
    *)
        echo "Invalid parameter: $OPTIONS."
        echo "Allowed values are: --reject, --3way, --stat and --check."
        exit 1
        ;;
    esac
elif [ $TOOL == "patch" ]; then
    case "$OPTIONS" in
    --reject|--merge)
        # Valid parameter, continue
        ;;
    *)
        echo "Invalid parameter: $OPTIONS."
        echo "Allowed values are: --reject and --merge."
        exit 1
        ;;
    esac
else
    echo "Invalid tool: $TOOL."
    echo "Allowed values are: git_apply and patch."
    exit 1
fi

MAIN_BRANCH="main"
VISSAT_BRANCH="vissat"

cd $COLMAP_TARGET_DP

# Delete previous reject files
# find . -name \*.rej | xargs rm

echo "Colmap compatible commit hash: $COLMAP_COMPATIBLE_COMMIT_HASH"
echo "Colmap target commit hash: $COLMAP_TARGET_COMMIT_HASH"

# Ensure we are on the MAIN_BRANCH before running rev-list
git switch --force $MAIN_BRANCH >/dev/null 2>&1

# Get a list of all commits from $COLMAP_COMPATIBLE_COMMIT_HASH to $COLMAP_TARGET_COMMIT_HASH
COMMIT_LIST=$(git rev-list --reverse $COLMAP_COMPATIBLE_COMMIT_HASH^..$COLMAP_TARGET_COMMIT_HASH)
COMMIT_LIST_LENGTH=$(git rev-list --count $COLMAP_COMPATIBLE_COMMIT_HASH^..$COLMAP_TARGET_COMMIT_HASH)
echo "Number commits from compatible to target commit: $COMMIT_LIST_LENGTH"
# for COMMIT_SHA in $COMMIT_LIST
# do
#     echo $COMMIT_SHA
# done

PATCH_FILES_AS_ARRAY=($(get_patch_files_as_array "$PATCH_DP"))
# for PATCH_FILE in "${PATCH_FILES_AS_ARRAY[@]}"; do
#     echo "$PATCH_FILE"
# done

current_iteration=0
for COMMIT_SHA in $COMMIT_LIST;
do
    if [ $current_iteration = $max_iterations ]; then
        break
    fi

    echo ""
    echo "---------------------------------------------------------------------"
    echo "-------- $COMMIT_SHA --------"
    echo "-------------- ($(git show -s --format=%ci $COMMIT_SHA)) --------------"
    echo "-------- $(git log -n 1 --pretty=format:%B $COMMIT_SHA | head -n 1) --------"
    echo "---------------------------------------------------------------------"
    echo ""
    git switch --force $MAIN_BRANCH >/dev/null 2>&1
    # Delete outdated local $VISSAT_BRANCH (if exists)
    if [ -n "$(git branch --list vissat)" ]; then
        git branch --force --delete $VISSAT_BRANCH >/dev/null
    fi
    # Order of "--force" and "--create" can not be swapped
    git switch --force --create $VISSAT_BRANCH $COMMIT_SHA
    echo "Set head to commit with hash $(git rev-parse HEAD)"

    apply_patches "${PATCH_FILES_AS_ARRAY[@]}"
    APPLY_RESULT=$?

    if [ $APPLY_RESULT -ne 0 ]; then
        echo "apply_patches failed for commit: $COMMIT_SHA"
        echo "---------------------------------------------------------------------"
        echo "-------- Status --------"
        echo "---------------------------------------------------------------------"
        git status
        # Exit the loop
        break
    else
        echo "apply_patches succeeded for commit: $COMMIT_SHA"
        echo "---------------------------------------------------------------------"
        if [ $TOOL == "git_apply" ] && [ $OPTIONS == "--3way" ]; then
            git restore --staged .
        fi
    fi
    current_iteration=$((current_iteration + 1))
done
