#!/usr/bin/env bash
#
# Copyright (C) 2025 Karlo Mijaljević
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
# ==================== DESCRIPTION OF PROGRAM ====================
#
# Use this script to download audio from YouTube. It can either download a
# single audio file or a playlist. The audio will be downloaded in OPUS format
# and saved in the specified directory. If no directory is specified, it will
# be saved in the default directory which is set to $HOME/music. The script
# uses yt-dlp for downloading and aria2c for downloading the audio files.
#

# =========================== #
# ========= GLOBALS ========= #
# =========================== #

# User defined flies and directories
g_url="$1"
g_audio_dir="${AUDIO_DIRECTORY:-"$HOME/music"}"
g_temp_dir="/tmp/ytdw"

# Control variables used between multiple functions
g_dir_or_audio_name="$2"
g_temp_file=""
g_is_playlist=0

# Colors
c_normal="\e[0m"
c_red="\e[1;31m"
c_green="\e[1;32m"

# Constants
g_user_agent="Mozilla/5.0 (X11; Linux x86_64; rv:125.0) Gecko/20100101 Firefox/125.0"

# =========================== #
# ======== FUNCTIONS ======== #
# =========================== #

# Checks for the program dependencies, which are: aria2c, yt-dlp and ffmpeg.
# And creates the temporary directory in $g_temp_dir
function f_check_dependencies {
   if ! command -v aria2c &> /dev/null; then
    echo -e "${c_red}Program 'aria2' not found!$c_normal"
    exit 1
  fi

  if ! command -v yt-dlp &> /dev/null; then
    echo -e "${c_red}Program 'yt-dlp' not found!$c_normal"
    exit 1
  fi

  if ! command -v ffmpeg &> /dev/null; then
    echo -e "${c_red}Program 'ffmpeg' not found!$c_normal"
    exit 1
  fi

  if [ ! -d "$g_temp_dir" ]; then
    mkdir -p "$g_temp_dir"
  fi
}

# Downloads audio. Takes two parameters. First is the audio URL and seconds is
# the directory where the audio will be located. The "return" of this function
# is the return code of the yt-dlp program call.
function f_dw_audio {
  local url="$1"
  local dir="$2"
  local name=""

  if [ $g_is_playlist -eq 1 ] || [ -z "$g_dir_or_audio_name" ]; then
    name="$dir/%(title)s.%(ext)s"
  else
    name="$dir/$g_dir_or_audio_name.%(ext)s"
  fi

  echo "Downloading video from URL '$url'"

  if ! yt-dlp --quiet \
    --no-warnings \
    --progress \
    --ignore-errors \
    --no-mtime \
    --downloader aria2c \
    --downloader-args "\
      --user-agent='$g_user_agent' \
      --max-connection-per-server=16 \
      --split=16 \
    " \
    --extract-audio \
    --prefer-ffmpeg \
    --audio-quality 0 \
    --postprocessor-args "-q:a 0 -map a" \
    -o "$name" \
    "$url"; then
    echo -e "${c_red}Failed to download audio from URL '$url'!$c_normal"
  else
    echo -e "${c_green}Audio from URL '$url' downloaded successfully!$c_normal"
  fi
}

# Parses the command line parameter which can either be a playlist or a single
# audio from YT.
function f_parse_data_and_dw {
  local dir="$g_audio_dir"
  local start_time=0
  local end_time=0
  local runtime=0

  start_time="$(date +%s)"

  if [[ "$g_url" == *"playlist"* ]]; then
    echo "Starting to download playlist at URL: $g_url"

    g_is_playlist=1

    if [ -n "$g_dir_or_audio_name" ]; then
      dir="$g_audio_dir/$g_dir_or_audio_name"
    else
      dir="$g_audio_dir/$(date '+%H%M%S%d%m')-playlist"
    fi

    if [ ! -d "$dir" ]; then
      mkdir -p "$dir"
    fi

    g_temp_file="${g_temp_dir}/$(date '+%H%M%S%d%m')-playlist.txt"

    yt-dlp --quiet \
      --no-warnings \
      --flat-playlist \
      --ignore-errors \
      --print-to-file url \
      "$g_temp_file" "$g_url"

    readarray -t urls < "$g_temp_file"

    for url in "${urls[@]}"; do
      f_dw_audio "$url" "$dir"
      echo
    done

    rm "$g_temp_file"
  else
    f_dw_audio "$g_url" "$dir"
  fi

  end_time="$(date +%s)"
  runtime=$((end_time-start_time))
  echo
  echo "Total program runtime lasted for $runtime seconds!"
  echo
  exit 0
}

# =========================== #
# =========== MAIN ========== #
# =========================== #

function f_main {
  f_check_dependencies
  f_parse_data_and_dw
}

f_main
