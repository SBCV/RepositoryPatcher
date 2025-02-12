#!/bin/bash
SCRIPT_DP="$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd
source "$SCRIPT_DP/patch_util.sh"

# This script expects the following parameter:
#   - mode (reject or 3way) for applying the patches
# 	- the path to the colmap source directory wich will be modified using a set of patches
#   - the commit SHA-1 hash of the colmap version compatible to the patch files
#   - the commit SHA-1 hash or "latest" of the colmap version we would like to update the patch files (optional)


usage() {
    echo "Usage: $0 
        --tool <tool>(default: git_apply) [<tool_option>(default: reject)]
        --patch_dp <patch_dp>
        --target_dp <target_dp>
        --commit <start_commit> [<target_commit>(default: HEAD)] [<num_iterations>(default: 1)]"
    echo "--tool:"
    echo "  Valid values for --tool are:"
    echo "      --tool git_apply reject (default)"
    echo "      --tool git_apply 3way"
    echo "      --tool patch reject"
    echo "      --tool patch merge"
    echo "--patch_dp:"
    echo "  Path to the directory containing the patch files."
    echo "--target_dp:"
    echo "  Path to the directory containing the target repository."
    echo "--commit:"
    exit 1
}


# Initialize variables
TOOL=""
PATCH_DP=""
TARGET_DP=""
COMMIT=()
LAZY=0

# # Options that do not require parameters by simply not specifying a colon (:) for those options.
# OPTIONS=$(getopt -o a:b: --long paramA:,paramB: -- "$@")
# eval set -- "$OPTIONS"

# Parse options
while [[ $# -gt 0 ]]; do
    case "$1" in
         -t|--tool)
            shift
            TOOL="$1"
            shift
            TOOL_OPTION="$1"

            # Validate mandatory value for --tool
            if [[ "$TOOL" != "git_apply" && "$TOOL" != "patch" ]]; then
                echo "Error: --tool must be 'git_apply' or 'patch'."
                usage
            fi

            # Validate optional value based on mandatory value
            if [[ "$TOOL" == "git_apply" && "$TOOL_OPTION" != "reject" && "$TOOL_OPTION" != "3way" && "$TOOL_OPTION" != "" ]]; then
                echo "Error: For git_apply, optional value must be reject or 3way."
                usage
            elif [[ "$TOOL" == "patch" && "$TOOL_OPTION" != "reject" && "$TOOL_OPTION" != "merge" && "$TOOL_OPTION" != "" ]]; then
                echo "Error: For patch, optional value must be reject or merge."
                usage
            fi
            shift
            ;;
         -p|--patch_dp)
            shift
            PATCH_DP="$1"
            shift
            ;;
         -r|--target_repository_dp)
            shift
            TARGET_REPOSITORY_DP="$1"
            shift
            ;;
         -c|--commit)
            shift
            STARTING_COMMIT="$1"
            shift
            if [[ $# -gt 0 ]]; then
                TARGET_COMMIT="$1"
            else
                TARGET_COMMIT="HEAD"
            fi
            shift

            COMMIT+=("$STARTING_COMMIT" "$TARGET_COMMIT")

            ;;
        -l|--lazy)
            LAZY=1
            shift
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Error: Unknown option $1"
            usage
            ;;
    esac
done


# Validate mandatory parameters
if [[ -z "$TOOL" || -z "$PATCH_DP" || -z "$TARGET_REPOSITORY_DP" || -z "$STARTING_COMMIT" ]]; then
    echo "Error: All mandatory parameters must be provided."
    usage
fi

echo "Tool: $TOOL"
echo "Tool Option: ${TOOL_OPTION:-None}"
echo "Patch DP: $PATCH_DP"
echo "Target DP: $SOURCE_DP"
# echo "Starting Commit: ${STARTING_COMMIT}"
# echo "Target Commit: ${TARGET_COMMIT}"

echo "Starting Commit: ${STARTING_COMMIT}"
echo "Target Commit: ${TARGET_COMMIT}"

echo "LAZY: ${LAZY}"

MAIN_BRANCH="main"
VISSAT_BRANCH="vissat"

if [ $LAZY = 1 ]; then

    apply_patches $TOOL $TOOL_OPTION $TARGET_REPOSITORY_DP $PATCH_DP $LAZY
    APPLY_RESULT=$?

    if [ $APPLY_RESULT -ne 0 ]; then
        echo "apply_patches failed"
        echo "---------------------------------------------------------------------"
        echo "-------- Status --------"
        echo "---------------------------------------------------------------------"
        git status
    else
        echo "apply_patches succeeded"
        echo "---------------------------------------------------------------------"
        if [ $TOOL == "git_apply" ] && [ $TOOL_OPTION == "3way" ]; then
            git restore --staged .
        fi
    fi

else

    cd $TARGET_REPOSITORY_DP

    # Ensure we are on the MAIN_BRANCH before running rev-list
    git switch --force $MAIN_BRANCH >/dev/null 2>&1

    # Assuming COMMIT_PARAMS is already populated with STARTING_COMMIT and TARGET_COMMIT
    if [[ -n "$TARGET_COMMIT" && "$TARGET_COMMIT" =~ ^[0-9]+$ ]] && [ "$TARGET_COMMIT" -lt 1000 ]; then
        # TARGET_COMMIT is a number less than 1000, treat it as an offset

        OFFSET="$TARGET_COMMIT"
        COMMIT_LIST=$(git rev-list --reverse $STARTING_COMMIT^..HEAD)
        COMMIT_ARRAY=($COMMIT_LIST)

        # Check if the target index is within bounds
        if [ $OFFSET -lt 0 ]; then
            echo "Offset is negative. $OFFSET"
            exit 1
        elif [ $OFFSET -ge ${#COMMIT_ARRAY[@]} ]; then
            echo "Offset is out of bounds. $OFFSET"
            exit 1
        fi
        TARGET_COMMIT=${COMMIT_ARRAY[$OFFSET]}
        echo "Target commit is an offset"
    else
        echo "Target commit is an SHA"
    fi

    echo "Compatible commit hash: $STARTING_COMMIT"
    echo "Target commit hash: $TARGET_COMMIT"


    # Get a list of all commits from $STARTING_COMMIT to $TARGET_COMMIT
    COMMIT_LIST=$(git rev-list --reverse $STARTING_COMMIT^..$TARGET_COMMIT)
    COMMIT_LIST_LENGTH=$(git rev-list --count $STARTING_COMMIT^..$TARGET_COMMIT)
    echo "Number commits from compatible to target commit: $COMMIT_LIST_LENGTH"

    # # Debugging output for commit list
    # echo "Commit list:"
    # for COMMIT_SHA in $COMMIT_LIST; do
    #     echo $COMMIT_SHA
    # done

    current_iteration=0
    for COMMIT_SHA in $COMMIT_LIST;
    do
        if [ $current_iteration = $MAX_ITERATIONS ]; then
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

        apply_patches $TOOL $TOOL_OPTION $TARGET_REPOSITORY_DP $PATCH_DP $LAZY
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
            if [ $TOOL == "git_apply" ] && [ $TOOL_OPTION == "3way" ]; then
                git restore --staged .
            fi
        fi
        current_iteration=$((current_iteration + 1))
    done

fi