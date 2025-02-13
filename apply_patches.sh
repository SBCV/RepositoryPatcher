#!/bin/bash
script_dp="$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd
source "$script_dp/_apply_patches_util.sh"

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
tool=""
patch_dp=""
target_dp=""
commit=()
lazy=0

# # Options that do not require parameters by simply not specifying a colon (:) for those options.
# options=$(getopt -o a:b: --long paramA:,paramB: -- "$@")
# eval set -- "$options"

# Parse options
while [[ $# -gt 0 ]]; do
    case "$1" in
         -t|--tool)
            shift
            tool="$1"
            shift
            tool_option="$1"

            # Validate mandatory value for --tool
            if [[ "$tool" != "git_apply" && "$tool" != "patch" ]]; then
                echo "Error: --tool must be 'git_apply' or 'patch'."
                usage
            fi

            # Define valid options for each tool as a single string
            declare -A valid_options
            valid_options["git_apply"]="reject r 3way 3"
            valid_options["patch"]="reject r merge m"

            # Validate optional value based on mandatory value
            if [[ -n "${valid_options[$tool]}" ]]; then
                # Convert the space-separated string into an array
                IFS=' ' read -r -a options_array <<< "${valid_options[$tool]}"

                # Check if tool_option is valid
                if [[ ! " ${options_array[@]} " =~ " $tool_option " ]]; then
                    echo "Error: For $tool, optional value must be one of: ${valid_options[$tool]}."
                    usage
                fi
            fi

            # Define abbreviations mapping
            declare -A abbreviations
            abbreviations["r"]="reject"
            abbreviations["3"]="3way"
            abbreviations["m"]="merge"

            if [[ -n "${abbreviations[$tool_option]}" ]]; then
                tool_option="${abbreviations[$tool_option]}"
            fi

            shift
            ;;
         -p|--patch_dp)
            shift
            patch_dp="$1"
            shift
            ;;
         -r|--target_repository_dp)
            shift
            target_repository_dp="$1"
            shift
            ;;
         -c|--commit)
            shift
            starting_commit="$1"
            shift
            if [[ $# -gt 0 ]]; then
                target_commit="$1"
            else
                target_commit="0"
            fi
            shift

            commit+=("$starting_commit" "$target_commit")

            ;;
        -l|--lazy)
            lazy=1
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
if [[ -z "$tool" || -z "$patch_dp" || -z "$target_repository_dp" || -z "$starting_commit" ]]; then
    echo "Error: All mandatory parameters must be provided."
    usage
fi

echo "Tool: $tool"
echo "Tool Option: ${tool_option:-None}"
echo "Patch DP: $patch_dp"
echo "Target DP: $target_dp"
# echo "Starting Commit: ${starting_commit}"
# echo "Target Commit: ${target_commit}"

echo "Starting Commit: ${starting_commit}"
echo "Target Commit: ${target_commit}"

echo "LAZY: ${lazy}"

main_branch="main"
vissat_branch="vissat"

if [ $lazy = 1 ]; then

    apply_patches $tool $tool_option $target_repository_dp $patch_dp $lazy
    apply_result=$?

    if [ $apply_result -ne 0 ]; then
        echo "apply_patches failed"
        echo "---------------------------------------------------------------------"
        echo "-------- Status --------"
        echo "---------------------------------------------------------------------"
        git status
    else
        echo "apply_patches succeeded"
        echo "---------------------------------------------------------------------"
        if [ $tool == "git_apply" ] && [ $tool_option == "3way" ]; then
            git restore --staged .
        fi
    fi

else

    cd $target_repository_dp

    # Ensure we are on the main_branch before running rev-list
    git switch --force $main_branch >/dev/null 2>&1

    # Assuming commit_params is already populated with starting_commit and target_commit
    if [[ -n "$target_commit" && "$target_commit" =~ ^[0-9]+$ ]] && [ "$target_commit" -lt 1000 ]; then
        # target_commit is a number less than 1000, treat it as an offset

        offset="$target_commit"
        commit_list=$(git rev-list --reverse $starting_commit^..HEAD)
        commit_array=($commit_list)

        # Check if the target index is within bounds
        if [ $offset -lt 0 ]; then
            echo "Offset is negative. $offset"
            exit 1
        elif [ $offset -ge ${#commit_array[@]} ]; then
            echo "Offset is out of bounds. $offset"
            exit 1
        fi
        target_commit=${commit_array[$offset]}
        echo "Target commit is an offset"
    else
        echo "Target commit is an SHA"
    fi

    echo "Compatible commit hash: $starting_commit"
    echo "Target commit hash: $target_commit"


    # Get a list of all commits from $starting_commit to $target_commit
    commit_list=$(git rev-list --reverse $starting_commit^..$target_commit)
    commit_list_length=$(git rev-list --count $starting_commit^..$target_commit)
    echo "Number commits from compatible to target commit: $commit_list_length"

    # # Debugging output for commit list
    # echo "Commit list:"
    # for commit_sha in $commit_list; do
    #     echo $commit_sha
    # done

    for commit_sha in $commit_list;
    do
        echo ""
        echo "---------------------------------------------------------------------"
        echo "-------- $commit_sha --------"
        echo "-------------- ($(git show -s --format=%ci $commit_sha)) --------------"
        echo "-------- $(git log -n 1 --pretty=format:%B $commit_sha | head -n 1) --------"
        echo "---------------------------------------------------------------------"
        echo ""
        git switch --force $main_branch >/dev/null 2>&1
        # Delete outdated local $vissat_branch (if exists)
        if [ -n "$(git branch --list vissat)" ]; then
            git branch --force --delete $vissat_branch >/dev/null
        fi
        # Order of "--force" and "--create" can not be swapped
        git switch --force --create $vissat_branch $commit_sha
        echo "Set head to commit with hash $(git rev-parse HEAD)"

        apply_patches $tool $tool_option $target_repository_dp $patch_dp $lazy
        apply_result=$?

        if [ $apply_result -ne 0 ]; then
            echo "apply_patches failed for commit: $commit_sha"
            echo "---------------------------------------------------------------------"
            echo "-------- Status --------"
            echo "---------------------------------------------------------------------"
            git status
            # Exit the loop
            break
        else
            echo "apply_patches succeeded for commit: $commit_sha"
            echo "---------------------------------------------------------------------"
            if [ $tool == "git_apply" ] && [ $tool_option == "3way" ]; then
                git restore --staged .
            fi
        fi
    done

fi