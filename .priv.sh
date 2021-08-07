#!/bin/bash

comparef() { # Runs compare_files script
  bash ~/refac-dir/scripts/compare_files.sh "$1"
}

find_ml() { # Search for files matching markup language patterns
  if [ $1 ]; then
    local dir="$(dirname "$1")"
    rg --files-with-matches -e "^<\?xml" -e "^<\?html" "$dir"
  else
    rg --files-with-matches -e "^<\?xml" -e "^<\?html"
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
    local filepath="${2}"
  fi
  local whitelist=(-protocol_whitelist "crypto,data,file,hls,http,https,tcp,tls")
  local user_agent_osx="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_5) AppleWebKit/601.7.8 (KHTML, like Gecko) Version/9.1.3 Safari/537.86.7"
  ffmpeg "${whitelist[@]}" -user_agent "$user_agent_osx" -i "$url" -c copy "$filepath"
}

strip_audio() { # Strips audio from a video file using ffmpeg
  local source_path=$1
  local output_path="$(add_str_to_filename $source_path '_noaudio')"
  [ $? = 1 ] && echo 'Filepath given is invalid' && return 1
  ffmpeg -i "$source_path" -vcodec copy -an "$output_path"
}

function log() { # Not sure what this does but I think it is similar to debug
  if [[ $_V -eq 1 ]]; then
    echo "$@"
  fi
}

ddg() { # Search DuckDuckGo
  local search_args="$@"
  [ -z $search_args ] && ds:fail 'Arg required for search'
  local base_url="https://www.duckduckgo.com/?q="
  local search_query=$(echo $search_args | sed -e "s/ /+/g")
  open "${base_url}${search_query}"
}

chr() { # Open Chrome at designated site
  open -a "Google Chrome" "$1"
}
alias chrome="/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome"
crc() { # Remote control headless Chrome
  chrome --headless --disable-gpu --repl --crash-dumps-dir=./tmp "$1"
  # --remote-debugging-port=9222
}

rd_user() {
  local user="$1" desc="$2" left=${3:-null}
  if [ $left != null ]; then
    [[ false =~ $left ]] || left=true
  fi
  table_insert rd_users "'$user', CURRENT_TIMESTAMP, '$desc', $left" rd
}

ls_priv() { # Lists private commands
  echo
  grep '[[:alnum:]_]*()' ~/.priv.sh | grep -v grep \
    | awk -F "{ #" '{printf "%30s%s\n", $1, $2}'
  echo
}


