#!/bin/bash
SCRIPT_DP="$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd
source "$SCRIPT_DP/patch_util.sh"

if [ $# -lt 4 ] || [ $# -gt 4 ]; then
    echo "Script expects 4 parameters, but ${#} provided!" >&2
    echo "Usage: $0 <tool> <options> <patch_dp> <target_repository_dp>"
    echo "<tool>: valid values are git_apply and patch".
    echo "<options>: valid values corresponding to tool such as --reject".
    exit 2
fi

TOOL=$1
OPTIONS=$2
PATCH_DP=$3
TARGET_REPOSITORY_DP=$4


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

PATCH_FILES_AS_ARRAY=($(get_patch_files_as_array "$PATCH_DP"))
# for PATCH_FILE in "${PATCH_FILES_AS_ARRAY[@]}"; do
#     echo "$PATCH_FILE"
# done
LAZY=1
apply_patches $LAZY $TARGET_REPOSITORY_DP "${PATCH_FILES_AS_ARRAY[@]}"
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
    if [ $TOOL == "git_apply" ] && [ $OPTIONS == "--3way" ]; then
        git restore --staged .
    fi
fi