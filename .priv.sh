#!/bin/bash

toascii() { # Convert file to ascii: toascii file
    ds:file_check "$1"
    local file="$1" tmp=$(ds:tmp 'toascii')
    cp "$file" $tmp
    native2ascii $tmp > "$file"
    echo "File $file converted to ascii. Copy of original file at $tmp"
}

jqsearch() { # Search JSON: jqsearch query JSON_file
    jq ".. | objects | with_entries(select(.key | test(\"$1\"; \"i\"))) | select(. != {})" "$2"
}

jqkeys() { # Get keys from JSON
    jq -r '[paths | join(".")]' "$1"
}

jvi() { # ds:grepvi "public.+$1": jvi methodname
    ds:grepvi "public.+$1"
}

java_long_extends() { # Java long extends: java_long_extends
    rg -UIog '*java' ' [A-z][A-z0-9\.]+[[:space:]]*(\n)?[[:space:]]extends[[:space:]]*(\n)?[[:space:]]*[A-z][A-z0-9\.]+( |\{|<)'
}

java_class_extensions() { # Java class extensions: java_class_extensions
    rg -Iog '*java' ' [A-z][A-z0-9\.]+ extends [A-z][A-z0-9\.]+( |\{|<)' \
        | rg '[A-Z]' \
        | sed -E 's:extends ::g;s:(^ +| +$)::g;s:(\{|<)$::g'
}

java_class_graph() { # Java class graph: java_class_graph
    java_class_extensions | ds:graph | sed 's#\[\[:space:\]\]\+# #g' | sort
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

m3u_dl() { # Downloads a streaming video into MP4 from an m3u playlist resource
    local url=$1
    if [ -z $2 ]; then
        local count=0
        local basepath=~"/Downloads/untitled folder/m3u_converted_output"
        local filepath="${basepath}.mp4"
        while [ -f $filepath ]; do ((count++)); filepath="${basepath}${count}.mp4"; done
    else
        echo 'Unable to parse download url'
        local filepath="${2}"
    fi
}

vlc_dl() { # Download a media file using VLC: vlc_dl url [output_filename]
    local url="$1" file="$(gen_next_series_file ~"/Downloads/vlc_output.mp4" "$2")"
    VLC -vvv "$url" --sout "file/ts:${file}"
}

m3u_dl() { # Downloads a streaming video into MP4 from an m3u playlist resource: m3u_dl url [output_filename]
    local url="$1" file="$(gen_next_series_file ~"/Downloads/m3u_converted_output.mp4" "$2")"
    local whitelist=(-protocol_whitelist "crypto,data,file,hls,http,https,tcp,tls")
    local user_agent_osx="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_5) AppleWebKit/601.7.8 (KHTML, like Gecko) Version/9.1.3 Safari/537.86.7"
    ffmpeg "${whitelist[@]}" -user_agent "$user_agent_osx" -i "$url" -c copy "$file"
    ffmpeg "${whitelist[@]}" -user_agent "$user_agent_osx" -i "$url" -c copy "$filepath"
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
    ffmpeg -i "$1" 2>&1 | rg title | ds:reo a 'NF>1' -F: | sed -E 's#^ +##g;s# +$##g;s# +#_#g'
}

media_duration() { # Get media duration using ffmpeg
    ffmpeg -i "$1" 2>&1 | rg Duration | ds:reo a 1 -F, | sed -E 'S#^ +Duration: +##g;s# +$##g'
}

gen_next_series_file() { # Return next index in series of filenames or default: gen_next_series_file default_filename [filename]
    local default="$1" count=0
    [ "$2" ] && local startpath="$2" || local startpath="$default"
    local filepath="$startpath"
    while [ -f "$filepath" ]
    do
        ((count++))
        local filepath="$(ds:filename_str "$startpath" "_${count}")"
    done
    echo -n "$filepath"
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
    fd $@ . | rg -v " " | rg --color=never '([a-z][A-Z]|[0-9][a-z]|^[0-9]+\.)'
}

files_rename() { # Rename all files matching a pattern given, using the command set on var file: files_rename 'media_title $file' '^No_' $(fd files)
    if [ ! "$3" ]
    then
        echo 'Missing arguments'
        return 1
    fi

    local transform_commands="$1"
    shift
    if [ ! -f "$1" ]
    then
        output_exclusion="$1"
        shift
    fi

    while [ "$1" ]
    do
        local file="$1"
        [ ! -f "$file" ] && shift && continue
        echo "$file"
        new_filepath="$(ds:filename_str "$file" "$(eval "$transform_commands")" replace)"
        new_filepath="$(gen_next_series_file "$new_filepath")"
        echo "$new_filepath\n"
        if [ "$output_exclusion" ]
        then
            ds:test "$output_exclusion" "$new_filepath" && shift && continue
        fi
        if [ "$(ds:readp 'Rename file? (y/n)')" = 'y' ]
        then
            mv "$file" "$new_filepath"
        fi
        shift
    done
}

find_ml() { # Search for files matching markup language patterns: find_ml [dir]
    if [ "$1" ]; then
        local dir="$(dirname "$1")"
        rg --files-with-matches -e "^<\?xml" -e "^<\?html" "$dir"
    else
        rg --files-with-matches -e "^<\?xml" -e "^<\?html"
    fi
}

function log() { # Not sure what this does but I think it is similar to debug
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
    rg --color=never '[[:alnum:]_]*\(\)' ~/my_vim/.priv.sh 2> /dev/null | rg -v 'rg --' | sort \
        | awk -F "\\\(\\\) { #" '{printf "%-18s\t%s\n", $1, $2}' \
        | ds:subsep '\\\*\\\*' "$DS_SEP" -v retain_pattern=1 -v apply_to_fields=2 -v FS="[[:space:]]{2,}" -v OFS="$DS_SEP" \
        | ds:subsep ":[[:space:]]" "888" -v apply_to_fields=2 -v FS="$DS_SEP" -v OFS="$DS_SEP" \
        | sed 's/)@/@/' | awk -v FS="$DS_SEP" '
          BEGIN { print "COMMAND" FS "DESCRIPTION" FS "USAGE\n" }
                { print }' \
        | ds:ttyf "$DS_SEP" t -v bufferchar="${1:- }"
    echo
}


