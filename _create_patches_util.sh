#!/bin/bash
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This script should not be executed directly."
else
    echo "Loading create patch util."
fi

reset_file_if_only_index_changes() {
    local patch_fp=$1
    # Switch to the repository with the patch files, and check
    # if there are substantial changes in the patch file
    cd $patch_dp

    # shortstat_result=$(git diff --shortstat $patch_fp)
    numstat_result=$(git diff --numstat $patch_fp)

    performed_git_restore=0

    # If numstat_result is empty, the file is up-to-date and there is nothing to restore.
    if [ -n "$numstat_result" ]; then
        read -r num_added_lines num_deleted_lines fn <<< "$numstat_result"

        if [ $num_added_lines == 1 ] && [ $num_deleted_lines == 1 ]; then
            local diff_output=$(git diff -- "$patch_fp")
            # printf "%s\n" "$diff_output"

            # Check for lines that start with "+index"" or "-index"
            local added_index_lines=$(echo "$diff_output" | grep '^+index')
            local removed_index_lines=$(echo "$diff_output" | grep '^-index')
            local num_added_index_lines=$(echo "$added_index_lines" | wc -l)
            local num_removed_index_lines=$(echo "$removed_index_lines" | wc -l)

            if [ $num_added_index_lines == 1 ] && [ $num_removed_index_lines == 1 ]; then
                # echo "Only index lines have changed in $patch_fp"
                git restore $patch_fp
                performed_git_restore=1
            else
                echo "ERROR: SINGLE CHANGE (BUT NOT INDEX LINE) in $patch_fp"
                exit
            fi
        # else
        #     echo "Actual changes in $patch_fp"
        fi
    fi

    # Switch back to the previous directory (i.e. the colmap git repository)
    cd $modified_colmap_source_dp
    return $performed_git_restore
}


create_patch() {
    local source_fp=$1
    local patch_fn=$2
    local patch_fp="$patch_dp/$patch_fn"
    if [ "$overwrite_patch_file" -eq 1 ] || [ ! -f "$patch_fp" ]; then
        git diff "$source_fp" > "$patch_fp"
        if [ $reset_index_changes == 1 ]; then
            reset_file_if_only_index_changes $patch_fp
            # Get return value of reset_file_if_only_index_changes
            performed_git_restore=$?
        else
            performed_git_restore=0
        fi
        if [ $performed_git_restore == 0 ]; then
            echo "Running: git diff \"$source_fp\" > \"$patch_fp\""
        fi
    fi
}

encode_path_as_filename() {
    local filepath="$1"
    echo "${filepath//\//__}"
}

decode_filename_as_path() {
    local filename="$1"
    echo "${filename//__/\/}"
}