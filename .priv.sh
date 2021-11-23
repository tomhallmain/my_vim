#!/bin/bash

toascii() { # Convert file to ascii: toascii file
    ds:file_check "$1"
    local file="$1" tmp=$(ds:tmp 'toascii')
    cp "$file" $tmp
    native2ascii $tmp > "$file"
    rm "$tmp"
}

jqkeyssearch() { # Search JSON: jqsearch query JSON_file
    jq ".. | objects | with_entries(select(.key | test(\"$1\"; \"i\"))) | select(. != {})" "$2"
}

jqkeys() { # Get keys from JSON
    jq -r '[paths | join(".")]' "$1"
}

jvi() { # ds:grepvi public.+$1: jvi methodname
    ds:grepvi "public.+$1"
}

java_long_extends() { # Java long extends: java_long_extends
    rg -UIog '*java' ' [A-z][A-z0-9\.]+[[:space:]]*(\n)?[[:space:]]extends[[:space:]]*(\n)?[[:space:]]*[A-z][A-z0-9\.]+( |\{|<)'
}

java_class_extensions() { # Java class extensions: java_class_extensions
    rg -Iog '*java' -e ' [A-z][A-z0-9\.]+[[:space:]]+extends[[:space:]]+[A-z][A-z0-9\.]+( |\{|<)' \
        -e  ' class[[:space:]]+[A-z][A-z0-9\.]+[[:space:]]+( |\{|<_)' \
        | rg '[A-Z]' \
        | sed -E 's: class : :g;s:extends ::g;s:(^ +| +$)::g;s:(\{|<)$::g'
}

java_class_graph() { # Java class graph: java_class_graph
    java_class_extensions | ds:graph -v print_bases=1 | sed 's#\[\[:space:\]\]\+# #g' | sort
}

retouchbar() { # Refresh touchbar: retouchbar
    sudo pkill TouchBarServer
}

dl() { # Download internet media: dl url [output_filename]
    if [[ "$1" =~ 'youtube.com' || "$1" =~ 'vimeo.com' ]]; then
        vlc_dl "$1" "$2"
    elif [[ "$1" =~ 'm3u8' ]]; then
        m3u_dl "$1" "$2"
    else
        echo 'Unable to parse download url'
        local filepath="${2}"
    fi
}

vlc_dl() { # Download media file using VLC: vlc_dl url [output_filename]
    local url="$1" file="$(gen_next_series_file ~"/Downloads/vlc_output.mp4" "$2")"
    VLC -vvv "$url" --sout "file/ts:${file}"
}

m3u_dl() { # Download streaming video to MP4 from m3u playlist resource: m3u_dl url [output_filename]
    local url="$1" output_file="$(gen_next_series_file ~"/Downloads/m3u_converted_output.mp4" "$2")"
    local whitelist=(-protocol_whitelist "crypto,data,file,hls,http,https,tcp,tls")
    local user_agent_osx="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_5) AppleWebKit/601.7.8 (KHTML, like Gecko) Version/9.1.3 Safari/537.86.7"
    ffmpeg "${whitelist[@]}" -user_agent "$user_agent_osx" -i "$url" -c copy "$output_file"
}

strip_audio() { # Strips audio from a video file using ffmpeg: strip_audio source_path
    local source_path=$1
    local output_path="$(add_str_to_filename $source_path '_noaudio')"
    [ $? = 1 ] && echo 'Filepath given is invalid' && return 1
    ffmpeg -i "$source_path" -vcodec copy -an "$output_path"
}

combin_vid_aud() { # Combine video and audio: combin_vid_aud vid aud [output_filename]
    local vid="$1" aud="$2" output="$(gen_next_series_file "combined_audio_video_output.mp4" "$3")"
    ffmpeg -i "$vid" -i "$aud" -c:v copy -c:a aac "$output"
}

media_title() { # Get media title using ffmpeg
    ffmpeg -i "$1" 2>&1 | rg title | ds:reo a 'NF>1' -F: | sed -E 's#^ +##g;s# +$##g;s# +#_#g;s#/#_#g'
}

media_duration() { # Get media duration using ffmpeg
    ffmpeg -i "$1" 2>&1 | rg Duration | ds:reo a 1 -F, | sed -E 'S#^ +Duration: +##g;s# +$##g'
}

gen_next_series_file_no_() { # Return next index in series of filenames or default: gen_next_series_file_no_ default_filename [filename]
    local default="$1" count=1
    [ "$2" ] && local startpath="$2" || local startpath="$default"
    local filepath="$(ds:filename_str "$startpath" "${count}")"
    while [ -f "$filepath" ]
    do
        ((count++))
        if [ $count -eq 10 ]
        then
            let local trycount=50
            while [ -f "$(ds:filename_str "$startpath" "$trycount")" ]
            do
                let local count=$trycount+1
                let local trycount+=50
            done
        fi
        local filepath="$(ds:filename_str "$startpath" "$count")"
    done
    echo -n "$filepath"
}

move_gen () { # Create the next file index from a base pattern: move_gen move_without_confirm=f basename file target_dir
    local confirm="$1"
    if [ -z "$2" ]
    then
        local basefile="$(ds:readp 'Enter basename+extension')"
    else
        local basefile="$2"
    fi
    if [ -z "$3" ]
    then
        local sourcefile=""
        while [ ! -f "$sourcefile" ]
        do
            local sourcefile="$(ds:readp 'Enter sourcefile')"
        done
    elif [ ! -f "$3" ]
    then
        echo "Invalid file provided: \"$3\""
        local sourcefile=""
        while [ ! -f "$sourcefile" ]
        do
            local sourcefile="$(ds:readp 'Enter sourcefile')"
        done
    else
        local sourcefile="$3"
    fi
    if [ "$4" ]
    then
        if [ -d "$4" ]
        then
            local basefile="$4/$basefile"
        else
            ds:fail "Invalid target directory: $4"
        fi
    fi
    read -r dirpath filename extension <<< $(ds:path_elements "$sourcefile")
    local source_extension="$extension"
    read -r dirpath1 filename1 extension1 <<< $(ds:path_elements "$basefile")
    if [ -z "$extension1" ]
    then
        local basefile="${basefile}${source_extension}"
    elif [ ! "$extension1" = "$source_extension" ]
    then
        echo 'Resolving extension for file'
        local basefile="$(echo "$basefile" | sed -E "s#\\$extension1\$#\\$source_extension#g")"
    fi
    local to_file="$(gen_next_series_file_no_ "$basefile")"
    if [ "$confirm" != y ]
    then
        local confirm="$(ds:readp "Move $sourcefile to $to_file ? (y|n)")"
        if [ "$confirm" != y ]
        then
            return 1
        fi
    fi
    if [ -f "$sourcefile" ]
    then
        mv "$sourcefile" "$to_file" && echo "Moved \"$sourcefile\" -> \"$to_file\""
    fi
}
alias mgy="move_gen y $@"

gen_next_series_file() { # Return next index in series of filenames or default: gen_next_series_file default_filename [filename]
    local default="$1" count=0
    [ "$2" ] && local startpath="$2" || local startpath="$default"
    local filepath="$startpath"
    while [ -f "$filepath" ]
    do
        ((count++))
        if [ $count -eq 10 ]
        then
            let local trycount=50
            while [ -f "$(ds:filename_str "$startpath" "_$trycount")" ]
            do
                let local count=$trycount+1
                let local trycount+=50
            done
        fi
        local filepath="$(ds:filename_str "$startpath" "_$count")"
    done
    echo -n "$filepath"
}

get_sha1s () { # Get sha1s from filepath lines: fd . | get_sha1s
    if [ "$1" ]
    then
        ds:line 'if [ -f "$line" ]; then openssl sha1 "$line"; fi'
    else
        ds:line 'if [ -f "$line" ]; then openssl sha1 "$line" | awk "{print \$2}"; fi'
    fi
}

add_sha1s_to_sets() { # Save down sha1s from files to an ids.db file: add_sha1s_to_sets set_title file*
    cp ids.db sets.db
    if [ -f "$1" ]
    then
        echo "Invalid title $1"
        return 1
    else
        local title="$1"
        shift
    fi
    echo "\n$title" >> ids.db
    while [ "$1" ]
    do
        if [ -f "$1" ]
        then
            echo "$1" | get_sha1s >> ids.db
        else
            echo "Arg \"$1\" was an invalid file address."
        fi
        shift
    done
    echo >> ids.db
}

open_sha1 () { # Open file in current dir by matching sha1: open_sha1 target_sha1 [force_data_update=f]
    local data_file=.sha1s.db force_data_update="${2:-f}"
    rm /tmp/open_sha1* 2>/dev/null; :
    if [ ! -f $data_file ] || ds:test 't(rue)?' "$force_data_update"; then
        local tmp_file=$(ds:tmp 'open_sha1')
        echo "Building SHA1 data file..."
        fd | get_sha1s t > $tmp_file
        cp $tmp_file $data_file
        rm $tmp_file
        echo "Saved updated SHA1 data at $data_file"
    fi
    local target="$1"
    let local target_len=$(echo "$target" | awk '{print length($0)}')
    ds:is_int "$target_len" || ds:fail "Unable to determine target length for target \"$target\""
    if [ $target_len -ne 40 ]; then
        while read -r line
        do
            if [ -f "$line" ]; then
                local FILES=( ${FILES[@]} "$line" )
            fi
        done < <(awk -v target="$target" '$2~target{print $1}' $data_file | sed -E 's#^SHA1\(##g;s#\)= *##g')
        open ${FILES[@]}
    else
        awk -v target="$target" '$2==target{print $1; exit}' $data_file \
            | head -n1 | sed -E 's#^SHA1\(##g;s#\)= *##g' | xargs open
    fi
}

open_set () { # Open a set of files stored in ids.db file in current dir: open_set set_title
    [[ "$1" =~ "^ *$" ]] && echo "Invalid set title provided" && return 1
    local target_sha1s="($(awk -v set_name="$1" 'set_found{ if ($0 ~ "^[[:space:]]*$") exit; print} $0 ~ set_name {set_found = 1}' ids.db | ds:join_by '|'))"
    open_sha1 "$target_sha1s" "$2"
}

get_sets() { # Show a list of all sets in ids.db with file counts: get_sets [sort_key]
    awk ' BEGIN { searching = 1 }
          $0 ~ "^[[:space:]]*$" { searching = 1; next }
          searching { searching = 0; set = $0; next }
          { set_counts[set]++ }
          END { for (set in set_counts) {print set_counts[set], set} }' ids.db \
        | sort -V -k"${1:-1}" | ds:ttyf
}

rename-last-dl() { # Rename last downloaded file: rename-last-dl [search]
    local old_wd="$PWD"
    cd ~/Downloads
    local base=1
    while [ ! "$confirmed" = "y" ]; do
        local tomove="$(ls -alc | rg "$1" | ds:rev \
            | ds:reo "$base" | ds:transpose -v FS=" " | tail -n1)"
        echo
        ls -alc | rg "$1" | ds:rev
        echo
        local confirmed=$(ds:readp "confirm mv $tomove to $2 (y/n): " | ds:downcase)
        let local base+=1
    done
    mv "$tomove" "$2"
}

rm_ds_store() { # Removes .DS_Store hidden files: rm_ds_store
    rm $(fd --hidden '\.DS_Store')
}

find_malformed() { # Find files with malformed names: fd_malformed
    fd $@ . | rg -v " " | rg --color=never '([a-z][A-Z]|[0-9][a-z]|^[0-9]+\.)' | sort
}

get_close_sorted_files () { # Get files closely sorted by version sort: get_close_sorted_files anchor
    _file="$1"
    ds:file_check "$_file" f t
    read -r _dir _name _ext <<< $(ds:path_elements "$_file")
    fd . | sort -V | awk -v matchfile="$_file" \
    'BEGIN{
        count=0; start_pointer=1; matchfile_found=0; files_set=0
    }
    (count - start_pointer) > 20 {exit}
    {
        count++; file=$0
        if (length(files) > 10 && !matchfile_found) { delete files[start_pointer]; start_pointer++ }
        if (file == matchfile) matchfile_found=1
        files[count]=file
    }
    END{
        for (i = start_pointer; i <= count; i++) if (files[i]) {print files[i]}
    }'
}

get_close_sorted_image_files () { # Get image files closely sorted by version sort: get_close_sorted_image_files anchor
    _file="$1"
    ds:file_check "$_file" f t
    read -r _dir _name _ext <<< $(ds:path_elements "$_file")
    fd '\.(jpe?g|png|webp)' | sort -V | awk -v matchfile="$_file" \
    'BEGIN{
        count=0; start_pointer=1; matchfile_found=0; files_set=0
    }
    (count - start_pointer) > 20 {exit}
    {
        count++; file=$0
        if (length(files) > 10 && !matchfile_found) { delete files[start_pointer]; start_pointer++ }
        if (file == matchfile) matchfile_found=1
        files[count]=file
    }
    END{
        for (i = start_pointer; i <= count; i++) if (files[i]) {print files[i]}
    }'
}

open_close_sorted_files () { # Open files closely sorted to an anchor: open_close_sorted_files anchor
    _FILES_=()
    while read -r line
    do
        if [ -f "$line" ]
        then
            _FILES_=(${_FILES_[@]} "$line")
        fi
    done < <(get_close_sorted_image_files $@)
    open ${_FILES_[@]}
}
alias csf="open_close_sorted_files $@"

files_rename() { # Rename files using the command set on var file: files_rename 'media_title $file' [exclude_pattern] $(fd files)
    if [ ! "$3" ]
    then
        echo 'Missing arguments'
        return 1
    fi

    local transform_commands="$1"
    shift
    if [ ! -f "$1" ]
    then
        local output_exclusion="$1"
        shift
    fi

    while [ "$1" ]
    do
        local file="$1" replace="$(eval "$transform_commands")"
        [ ! -f "$file" ] && shift && continue
        [[ "$file" =~ "^$replace" ]] && shift && continue
        [ "$replace" = 'No_matches_found' ] && shift && continue
        [ "$replace" = "''" ] && shift && continue
        local new_filepath="$(ds:filename_str "$file" "$replace" replace)"
        local new_filepath="$(gen_next_series_file "$new_filepath")"
        if [ "$output_exclusion" ]
        then
            ds:test "$output_exclusion" "$new_filepath" && shift && continue
        fi
        echo "Current filename:"
        echo "\033[37;1m$file\033[0m"
        echo "New filename:"
        echo "\033[37;1m$new_filepath\n\033[0m"
        if [ "$(ds:readp 'Rename file? (y/n)')" = 'y' ]
        then
            mv "$file" "$new_filepath"
        fi
        echo
        shift
    done

    echo "File parsing complete. If no output, all of the new filenames were excluded by the current output exclusions."
}

files_rename_all() { # Rename all files maatching a pattern to an indexed list: files_rename_all [base_dir] file_match_pattern new_base_filename
    if [ -d "$1" ]; then
        local base_dir="$1"
        shift
    else
        local base_dir=.
    fi

    local file_match_pattern="$1" new_base_filename="$2"
    let local f_count=0
    for f in $(fd "$file_match_pattern" "$base_dir"); do
        let local f_count+=1
    done
    [ $f_count = 0 ] && echo "No files found matching \"$file_match_pattern\" in \"$base_dir\"" && return 1
    local confirm="$(ds:readp "Found $f_count files to rename in \"$base_dir\", proceed with rename to \"$new_base_filename\" (y/n):")"
    [ ! "$confirm" = y ] && echo "No files renamed." && return

    for _f_ in $(fd "$file_match_pattern" "$base_dir" | sort); do
        local new_filepath="$(ds:filename_str "$_f_" "$new_base_filename" replace)"
        local new_filepath="$(gen_next_series_file "$new_filepath")"
        mv "$_f_" "$new_filepath"
    done
}

find_ml() { # Search for files matching markup language patterns: find_ml [dir]
    if [ "$1" ]; then
        local dir="$(dirname "$1")"
        rg --files-with-matches -e "^<\?xml" -e "^<\?html" "$dir" | sort
    else
        rg --files-with-matches -e "^<\?xml" -e "^<\?html" | sort
    fi
}

function log() { # Similar to debug?
    if [[ $_V -eq 1 ]]
    then
        echo "$@"
    fi
}

ddg() { # Search DuckDuckGo: ddg search_query
    local search_args="$@"
    [ -z $search_args ] && ds:fail 'Arg required for search'
    local base_url="https://www.duckduckgo.com/?q="
    local search_query=$(echo $search_args | sed -e "s/ /+/g")
    open "${base_url}${search_query}"
}

ocrpdf() { # OCR PDF script: ocrpdf file.pdf
    ds:file_check "$1"
    local pdf="$(readlinkf "$1")"
    cd ~/image-table-ocr
    python3 -m table_ocr.pdf_to_images "$pdf" | grep .png \
        | xargs -I{} python -m table_ocr.extract_tables {} | grep table > /tmp/extracted-tables.txt

    cat /tmp/extracted-tables.txt | xargs -I{} python -m table_ocr.extract_cells {} | grep cells > /tmp/extracted-cells.txt
    cat /tmp/extracted-cells.txt | xargs -I{} python -m table_ocr.ocr_image {}

    for image in $(cat /tmp/extracted-tables.txt); do
        local dir=$(dirname $image)
        python3 -m table_ocr.ocr_to_csv $(find "$dir/cells" -name "*.txt")
    done
}

dfpdf() { # Diff two pdf files: dfpdf file1.pdf file2.pdf [outputfile=diff.pdf]
    [ "$3" ] && local outputfile="$3" || local outputfile="diff.pdf"
    while [ -f "$outputfile" ]; do
        local outputfile="$(ds:readp "Output diff file already exists, please select a different name: ")"
    done
    diff-pdf --output-diff="$outputfile" "$1" "$2"
}

image_text() { # Runs tessract on image to stdout: image_text file
    tesseract "$1" stdout 2>/dev/null
}

image_color_diff() { # Get a color diff of the dominant colors in two images: image_color_diff file1 file2
    OLD_WD="$(pwd)"
    cd ~/scripts
    java com.compareFiles.ImageCompare $@
    cd "$OLD_WD"
}

comparef() { # Runs compare_files script: comparef [?]
    bash ~/refac-dir/scripts/compare_files.sh "$1"
}

ggrep() { # Git grep shortcut: ggrep file [n_objs_rev_lookup=10]
    git grep "$1" $(git rev-list --all --max-count=${2:-10})
}

git_branch_commits_diff() { # Commits diff: branch_commits_diff commits_from_branch commits_exclude_branch
    local commits_from_branch="$1" commits_exclude_branch="$2"
    git log --no-merges "$commits_from_branch" "^$commits_exclude_branch"
}

git_linediff() { # Git line diff: git_linediff from_obj to_obj
    git diff --numstat "$1" "$2" \
        | ds:reo a 1..2 | ds:agg 'off' '+' | tail -n1 | ds:reo a 1..2 | ds:agg '$1-$2'
}

git_cdiff() { # Git character diff: git_cdiff from_obj to_obj
    local lnfs="$(ds:tmp 'git_cdiff_lnfs')"
    
    if ds:test 't(rue)?' "$3"; then
        local prg='FILENAME=$0{while(getline<FILENAME>OUTPUT && match($0,"$")) RSTOP-=RSTART; close(FILENAME)} END{print-RSTOP}'
        fd -t f . | rg -v \
            -f <(cat .gitignore | sed -E 's# .+$##g;s#\*##g' | ds:mini "|" t) \
            -f <(cat .gitattributes | sed -E 's# .+$##g;s#\*##g' | ds:mini "|" t) \
            -e '(pdf|driver|exe|png|jpg|jpeg|tiff|svg)$' 2>/dev/null > $lnfs

        [ "$1" = HEAD ] && local bbr="$(git rev-parse --abbrev-ref HEAD)" || local bbr="$1" 
        [ "$2" = HEAD ] && local abr="$(git rev-parse --abbrev-ref HEAD)" || local abr="$2"

        local a=$(git checkout "$abr" &>/dev/null; cat $lnfs | awk "$prg")
        local b=$(git checkout "$bbr" &>/dev/null; cat $lnfs | awk "$prg")

        if ! ds:is_int "$a" || ! ds:is_int "$b"; then
            echo 'Failed to parse files'; rm $lnfs; return 1
        fi
        rm $lnfs

        let local d=$a-$b
        if [[ $a = 0 || $b = 0 ]]; then
            echo -e "$p\t$m\t$d"; return
        fi
        if [ $a -gt $b ]; then
            let local pcdiff=$(echo "scale=2;$d/$a*100" | bc | awk '{print int($1)}')
        else
            let local pcdiff=$(echo "scale=2;$d/$b*100" | bc | awk '{print int($1)}'); fi

        echo -e "$b $a $d $pcdiff%" | ds:fit
    else
        git diff --word-diff=porcelain "$1" "$2" > $lnfs
        local lns=$(cat $lnfs | wc -l | xargs)
        local m=$(rg "^\-[^\-]" $lnfs | wc -c | xargs)
        local p=$(rg "^\+[^\+]" $lnfs | wc -c | xargs)

        if ! ds:is_int "$p" || ! ds:is_int "$m"; then
            echo 'Failed to parse diff'; rm $lnfs; return 1
        fi
        rm $lnfs

        let local m-=$lns
        let local p-=$lns
        let local d=$p-$m
        if [[ $p = 0 || $m = 0 ]]; then
            echo -e "$m\t$p\t$d"; return; fi

        if [ $p -gt $m ]; then
            let local pcdiff=$(echo "scale=2;$d/$p*100" | bc | awk '{print int($1)}')
        else
            let local pcdiff=$(echo "scale=2;$d/$m*100" | bc | awk '{print int($1)}')
        fi

        echo -e "$m $p $d $pcdiff%" | ds:fit
    fi
}

chrome_kill() { # Kill all running chrome and chromedriver processes: chrome_kill
    driver_pids=($(ps aux | rg '(chromedriver|Chrome.app)' | rg -v rg | awk '{print $2}'))
    for pid in ${driver_pids[@]}
    do
        echo "Killing Chrome / chromedriver process: $pid"
        kill -9 "$pid"
    done
}

wdl() { # Download a file using wget: wdl request_url output_name user password
  local request_url="$1" output_name="$2" user="$3" password="$4"
  wget --user="$user" --password="$password" --auth-no-challenge --output-document="$output_name" "$request_url"
}

chr() { # Open Chrome at designated site
    open -a "Google Chrome" "$1"
}
alias chrome="/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome"
crc() { # Remote control headless Chrome
    chrome --headless --disable-gpu --repl --crash-dumps-dir=./tmp "$1"
    # --remote-debugging-port=9222
}

read_groups () { # Read groups from simple_image_compare output
    wait_t="${2:-30}"
    ds:is_int "$wait_t" || return 1
    while read -r line
    do
        if [ "$line" = "" ]
        then
            continue
        elif [[ "$line" =~ 'Group' ]]
        then
            if [ "${_FILES_[2]}" ]
            then
                open ${_FILES_[@]}
            fi
            _FILES_=()
            sleep "$wait_t"
            echo "$line"
            continue
        fi
        if [ "$line" ]
        then
            line="$(echo $line | sed -E 's#_[A-Z0-9]{26}\.[0-9]{3,4}x0##g')"
            if [ -f "$line" ]
            then
                echo "$line"
                _FILES_=("${_FILES_[@]}" "$line")
            fi
        fi
    done < <(cat simple_image_compare_file_groups_output.txt | awk 'if_print{print}!if_print && $0~/^Group '$1'/{if_print=1}')
}

run_rdij() { # Runs reddit injection script: run_rdij [top] [comments] [standard_channels||channels]
    if [ ! "$1" ]
    then
        python3 ~/scripts/rdinjectpy/runner.py top comments standard_channels
    else
        python3 ~/scripts/rdinjectpy/runner.py $@
    fi
}

rd_user() { # Catalog a reddit user: rd_user user desc [left]
    local user="$1" desc="$2" left=${3:-null}
    
    if [ "$left" != null ]
    then
        [[ false =~ $left ]] || left=true
    fi
    
    table_insert rd_users "'$user', CURRENT_TIMESTAMP, '$desc', $left" rd
}

4cfilter() { # Get 4c filters copied to clipboard: 4cfilter
    cat ~/4cinject/filters/filter | head -n1 | ds:cp
}

ls_priv() { # Lists private commands: ls_priv
    echo
    rg --color=never '[0-9A-Za-z_]+ ?\(\)' ~/my_vim/.priv.sh 2> /dev/null | rg -v 'rg --' | sort \
        | awk -F "\\\(\\\) { #" '{printf "%-18s\t%s\n", $1, $2}' \
        | ds:subsep '\\\*\\\*' "$DS_SEP" -v retain_pattern=1 -v apply_to_fields=2 -v FS="[[:space:]]{2,}" -v OFS="$DS_SEP" \
        | ds:subsep ":[[:space:]]" "888" -v apply_to_fields=2 -v FS="$DS_SEP" -v OFS="$DS_SEP" \
        | sed 's/)@/@/' | awk -v FS="$DS_SEP" '
          BEGIN { print "COMMAND" FS "DESCRIPTION" FS "USAGE\n" }
                { print }' \
        | ds:ttyf "$DS_SEP" t -v bufferchar="${1:- }"
    echo
}


