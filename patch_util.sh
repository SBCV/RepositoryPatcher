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

apply_patches() {
    # Options:
    #  "-v"         Verbose (useful for debugging, shows why applying patch failed)
    #  "--reject"   Creation of *.rej files (hunks that failed to apply) 
    #  "--3way"     this is similar to the "fuzz" option of "patch" and allows for a
    #               less strict matching of context lines.
    # Note: The "--reject" and "--3way" options can not be used together

    # Loop through each patch file in the the patch file array
    for PATCH in "$@";
    do
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
    done

    echo "All patches applied successfully."
    return 0
}