#!/bin/bash
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This script should not be executed directly."
else
    echo "Loading patch util."
fi

get_patch_files_as_array() {
    local patch_dir="$1"
    patch_files_as_string=$(find "$patch_dir" -type f -name "*.patch")
    mapfile -t patch_files_as_array <<< $patch_files_as_string
    echo "${patch_files_as_array[@]}"
}

apply_patch() {
    # Options:
    #  "-v"         Verbose (useful for debugging, shows why applying patch failed)
    #  "--reject"   Creation of *.rej files (hunks that failed to apply) 
    #  "--3way"     this is similar to the "fuzz" option of "patch" and allows for a
    #               less strict matching of context lines.
    # Note: The "--reject" and "--3way" options can not be used together

    if [ $TOOL == "git_apply" ]; then
        git apply $OPTIONS $PATCH
    elif [ $TOOL == "patch" ]; then
        # --reject-format=FORMAT  Create 'context' or 'unified' rejects.
        if [ $OPTIONS == "--reject" ]; then
            # Reject descibes the default behavior of patch, so ommit any parameter
            patch -p1 -i $PATCH
        elif [ $OPTIONS == "--merge" ]; then
            patch -p1 --merge -i $PATCH
        else
            echo "SOMETHING WENT TERRIBLY WRONG"
            exit 1
        fi
    else
        echo "SOMETHING WENT TERRIBLY WRONG"
        exit 1
    fi

    # Check the exit status of git apply
    if [ $? -ne 0 ]; then
        # Return 1 if patch fails
        echo "Failed to apply patch: $PATCH"
        return 1
    fi
}

apply_patch_lazy() {
    # Read the file names affected by the patch file
    RELATIVE_FP_PAIR=$(grep -oP '(?<=a/).*' <<< $(grep -m 1 -oP 'a/.*' $PATCH))
    # Get the first file name
    RELATIVE_FP=$(echo $RELATIVE_FP_PAIR | cut -d' ' -f1)
    # Get the absolute path of the file, the file is located in $COLMAP_TARGET_DP
    ABSOLUTE_FP="./${RELATIVE_FP}"

    ABSOLUTE_TEMP_FP="$ABSOLUTE_FP.tmp"
    mv $ABSOLUTE_FP $ABSOLUTE_TEMP_FP
    git checkout $ABSOLUTE_FP

    apply_patch

    # Check if ABSOLUTE_TEMP_FP and ABSOLUTE_FP are different
    diff $ABSOLUTE_FP $ABSOLUTE_TEMP_FP > /dev/null
    if [ $? -eq 0 ]; then
        echo "File $ABSOLUTE_FP has not changed."
        mv $ABSOLUTE_TEMP_FP $ABSOLUTE_FP
    else
        echo "File $ABSOLUTE_FP has changed."
    fi
}


apply_patches() {
    local lazy=$1
    local target_repository_dp=$2
    # Shift the parameters to process only the patch files
    shift 2
    local patches=("$@")

    cd $target_repository_dp

    # Loop through each patch file in the the patch file array
    for PATCH in "$@"; do
        if [ $lazy = 1 ]; then
            apply_patch_lazy
        else
            apply_patch
        fi
    done
    echo "All patches applied successfully."
    return 0
}