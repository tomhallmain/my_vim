#!/bin/bash

retouchbar() { # Refresh touchbar: retouchbar
    sudo pkill TouchBarServer
}

rm_ds_store() { # Removes .DS_Store hidden files: rm_ds_store
    rm $(fd --hidden '\.DS_Store')
}

comparef() { # Runs compare_files script: comparef [?]
    bash ~/refac-dir/scripts/compare_files.sh "$1"
}

4cfilter() { # Get 4c filters copied to clipboard: 4cfilter
    cat ~/4cinject/filters/filter | head -n1 | ds:cp
}

find_ml() { # Search for files matching markup language patterns: find_ml [dir]
    if [ "$1" ]; then
        local dir="$(dirname "$1")"
        rg --files-with-matches -e "^<\?xml" -e "^<\?html" "$dir"
    else
        rg --files-with-matches -e "^<\?xml" -e "^<\?html"
    fi
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
    local url="$1" file="$(gen_next_series_file "/Users/tomhall/Downloads/vlc_output.mp4" "$2")"
    VLC -vvv "$url" --sout "file/ts:${file}"
}

m3u_dl() { # Downloads a streaming video into MP4 from an m3u playlist resource: m3u_dl url [output_filename]
    local url="$1" file="$(gen_next_series_file "/Users/tomhall/Downloads/m3u_converted_output.mp4" "$2")"
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

image_text() { # Runs tessract on image to stdout: image_text file
    tesseract "$1" stdout 2>/dev/null
}

image_color_diff() { # Get a color diff of the dominant colors in two images: image_color_diff file1 file2
    OLD_WD="$(pwd)"
    cd ~/scripts
    java com.compareFiles.ImageCompare $@
    cd "$OLD_WD"
}

fd_malformed() { # Find files with malformed names: fd_malformed
    fd $@ . | rg -v " " | rg --color=never '([a-z][A-Z]|[0-9][a-z]|^[0-9]+\.)'
}

chrome_kill() { # Kill all running chrome and chromedriver processes: chrome_kill
    driver_pids=($(ps aux | rg '(chromedriver|Chrome.app)' | rg -v rg | awk '{print $2}'))
    for pid in ${driver_pids[@]}
    do
        echo "Killing Chrome / chromedriver process: $pid"
        kill -9 "$pid"
    done
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

ls_priv() { # Lists private commands: ls_priv
    echo
    grep '[[:alnum:]_]*()' ~/my_vim/.priv.sh | grep -v grep | sort \
        | awk -F " { # " 'BEGIN {print "COMMAND::DESCRIPTION::USAGE"}
            {usage=$2; gsub(": ", "::", usage); print $1"::"usage}' \
        | ds:fit -v FS=::
    echo
}


