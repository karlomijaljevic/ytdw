#!/usr/bin/env bash
#
# Copyright (C) 2025 Karlo Mijaljević
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
#

# =========================== #
# ========= GLOBALS ========= #
# =========================== #

# User defined flies and directories
g_audio_dir="${AUDIO_DIRECTORY:-"$HOME/Downloads"}"
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
        if command -v aria2c > /dev/null 2>&1 ; then
                true
        else
                echo -e "${c_red}Program 'aria2' not found!$c_normal"
                exit 1
        fi

        if command -v yt-dlp > /dev/null 2>&1 ; then
                true
        else
                echo -e "${c_red}Program 'yt-dlp' not found!$c_normal"
                exit 2
        fi

        if command -v ffmpeg > /dev/null 2>&1 ; then
                true
        else
                echo -e "${c_red}Program 'ffmpeg' not found!$c_normal"
                exit 3
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
        local name_command=""

        if [ $g_is_playlist -eq 1 ] || [ -z "$g_dir_or_audio_name" ]; then
                name_command="$dir/%(title)s.%(ext)s"
        else
                name_command="$dir/$g_dir_or_audio_name.%(ext)s"
        fi


        yt-dlp --quiet \
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
                --audio-format flac \
                --audio-quality 0 \
                --postprocessor-args "-q:a 0 -map a" \
                -o "$name_command" \
                "$url"
}

# Downloads audio. Takes two parameters. First is the audio URL and seconds is
# the directory where the audio will be located. Once the audio is downloaded
# or fails to download it will echo the result to the user.
function f_dw_audio_and_notify {
        local url="$1"
        local dir="$2"

        echo "Downloading video from URL '$url'"

        if ! f_dw_audio "$url" "$dir"; then
                echo -e "${c_red}FAILED to download video from URL '$url'!$c_normal"
        else
                echo -e "${c_green}Video from URL '$url' downloaded!$c_normal"
        fi
}

# Parses the command line parameter which can either be a playlist or a single
# audio from YT.
function f_parse_data_and_dw {
        local url="$1"
        local dir="$g_audio_dir"
        local start_time=0
        local end_time=0
        local runtime=0

        start_time="$(date +%s)"

        if [[ "$url" == *"playlist"* ]]; then
                echo "Starting to download playlist at URL: $url"
                
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
                        "$g_temp_file" "$url"


                readarray -t urls < "$g_temp_file"

                for url in "${urls[@]}"; do
                        f_dw_audio_and_notify "$url" "$dir"
                        echo
                done

                rm "$g_temp_file"
        else
                f_dw_audio_and_notify "$url" "$dir"
        fi

        end_time="$(date +%s)"
        runtime=$((end_time-start_time))
        echo
        echo "Total program runtime lasted for $runtime seconds!"
        echo
        exit 0
}

# The main function. Starts the program.
function f_main {
        f_check_dependencies
        f_parse_data_and_dw "$1"
}

# =========================== #
# =========== MAIN ========== #
# =========================== #

f_main "$1"
