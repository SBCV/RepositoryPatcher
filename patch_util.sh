#!/bin/bash
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This script should not be executed directly."
else
    echo "Loading patch util."
fi

get_patch_files_as_array() {
    local _patch_dir="$1"
    local _patch_files_as_string=$(find "$_patch_dir" -type f -name "*.patch")
    mapfile -t patch_files_as_array <<< $_patch_files_as_string
    echo "${patch_files_as_array[@]}"
}

apply_patch() {
    local _tool=$1
    local _option=$2
    local _patch_fp=$3
    # Options:
    #  "-v"         Verbose (useful for debugging, shows why applying patch failed)
    #  "--reject"   Creation of *.rej files (hunks that failed to apply) 
    #  "--3way"     this is similar to the "fuzz" option of "patch" and allows for a
    #               less strict matching of context lines.
    # Note: The "--reject" and "--3way" options can not be used together

    if [ $_tool == "git_apply" ]; then
        if [ $_option == "reject" ]; then
            git apply --reject "$_patch_fp"
        elif [ $_option == "3way" ]; then
            git apply --3way "$_patch_fp"
        else
            echo "SOMETHING WENT WRONG. Invalid option: $_option"
            exit 1
        fi
    elif [ $_tool == "patch" ]; then
        # --reject-format=FORMAT  Create 'context' or 'unified' rejects.
        if [ $_option == "--reject" ]; then
            # Reject descibes the default behavior of patch, so ommit any parameter
            patch -p1 -i $_patch_fp
        elif [ $_option == "--merge" ]; then
            patch -p1 --merge -i $_patch_fp
        else
            echo "SOMETHING WENT WRONG. Invalid option: $_option"
            exit 1
        fi
    else
        echo "SOMETHING WENT WRONG. Invalid tool: $_tool"
        exit 1
    fi

    # Check the exit status of git apply
    if [ $? -ne 0 ]; then
        # Return 1 if patch fails
        echo "Failed to apply patch: $_patch_fp"
        return 1
    fi
    return 0
}

apply_patch_lazy() {
    local _tool=$1
    local _option=$2
    local _patch_fp=$3

    # Read the file names affected by the patch file
    local _relative_fp_pair=$(grep -oP '(?<=a/).*' <<< $(grep -m 1 -oP 'a/.*' $_patch_fp))
    # Get the first file name
    local _relative_fp=$(echo $_relative_fp_pair | cut -d' ' -f1)
    # Get the absolute path of the file, the file is located in $COLMAP_TARGET_DP
    local _absolute_fp="./${_relative_fp}"

    local _absolute_temp_fp="$_absolute_fp.nnj_tmp"
    mv $_absolute_fp $_absolute_temp_fp

    git checkout $_absolute_fp > /dev/null 2>&1
    apply_patch $_tool $_option $_patch_fp
    local _apply_result=$?
    if [ "$_apply_result" -eq 1 ]; then
        return 1
    fi

    # Check if _absolute_temp_fp and absolute_fp are different
    diff $_absolute_fp $_absolute_temp_fp > /dev/null
    if [ $? -eq 0 ]; then
        # Files are identical, move restore old file (to maintain the metadata)
        mv $_absolute_temp_fp $_absolute_fp
    fi
    return 0
}


apply_patches() {
    local _tool=$1
    local _option=$2
    local _target_repository_dp=$3
    local _patch_dp=$4
    local _lazy=$5
    local _patch_files_as_array=($(get_patch_files_as_array "$_patch_dp"))
    # for _patch_file in "${_patch_files_as_array[@]}"; do
    #     echo "$_patch_file"
    # done

    cd $_target_repository_dp

    # Loop through each patch file in the the patch file array
    local _patch_fp=""
    for _patch_fp in "${_patch_files_as_array[@]}"; do
        local _apply_result=-1
        if [ $_lazy = 1 ]; then
            apply_patch_lazy $_tool $_option $_patch_fp
            _apply_result=$?
        else
            apply_patch $_tool $_option $_patch_fp
            _apply_result=$?
        fi
        if [ "$_apply_result" -eq 1 ]; then
            exit 1
        fi
    done
    echo "All patches applied successfully."
    return 0
}