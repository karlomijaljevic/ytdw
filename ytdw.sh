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

set -euo pipefail

# =========================== #
# ========= GLOBALS ========= #
# =========================== #

# Colors
c_normal="\e[0m"
c_red="\e[1;31m"
c_green="\e[1;32m"

# Constants
g_user_agent="Mozilla/5.0 (X11; Linux x86_64; rv:125.0) Gecko/20100101 Firefox/125.0"

# Runtime state (populated in f_main)
g_url=""
g_audio_dir="${XDG_MUSIC_DIR:-"$HOME/music"}"
g_temp_dir=""
g_dir_or_audio_name=""
g_temp_file=""
g_is_playlist=0

# =========================== #
# ======== FUNCTIONS ======== #
# =========================== #

die() {
  printf "${c_red}error: %s${c_normal}\n" "$*" >&2
  exit 1
}

usage() {
  printf 'Usage: %s <url> [name]\n' "$(basename "$0")" >&2
  printf '  url   YouTube video or playlist URL\n' >&2
  printf '  name  output filename (single track) or subdirectory name (playlist)\n' >&2
}

cleanup() {
  [[ -f "$g_temp_file" ]] && rm -f "$g_temp_file"
  [[ -d "$g_temp_dir" ]] && rm -rf "$g_temp_dir"
}

# Checks for program dependencies (aria2c, yt-dlp, ffmpeg) and creates the temp dir.
f_check_dependencies() {
  command -v aria2c >/dev/null 2>&1 || die "program 'aria2' not found"
  command -v yt-dlp >/dev/null 2>&1 || die "program 'yt-dlp' not found"
  command -v ffmpeg >/dev/null 2>&1 || die "program 'ffmpeg' not found"

  g_temp_dir="$(mktemp -d)" || die "failed to create temp directory"
}

# Downloads audio from a single URL into dir. Reports success/failure to stdout.
f_dw_audio() {
  local url="$1"
  local dir="$2"
  local name

  if [[ "$g_is_playlist" -eq 1 ]] || [[ -z "$g_dir_or_audio_name" ]]; then
    name="$dir/%(title)s.%(ext)s"
  else
    name="$dir/$g_dir_or_audio_name.%(ext)s"
  fi

  printf 'Downloading video from URL '\''%s'\''\n' "$url"

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
    --audio-quality 0 \
    --postprocessor-args "-q:a 0 -map a" \
    -o "$name" \
    "$url"; then
    printf "${c_red}Failed to download audio from URL '%s'!${c_normal}\n" "$url"
    return 1
  else
    printf "${c_green}Audio from URL '%s' downloaded successfully!${c_normal}\n" "$url"
  fi
}

# Determines whether the URL is a playlist or single track and dispatches downloads.
f_parse_data_and_dw() {
  local dir="$g_audio_dir"
  local start_time
  local end_time
  local runtime
  local download_failed=0

  start_time="$(date +%s)"

  if [[ "$g_url" == *"playlist"* ]]; then
    printf 'Starting to download playlist at URL: %s\n' "$g_url"

    g_is_playlist=1

    if [[ -n "$g_dir_or_audio_name" ]]; then
      dir="$g_audio_dir/$g_dir_or_audio_name"
    else
      dir="$g_audio_dir/$(date '+%H%M%S%d%m')-playlist"
    fi

    [[ -d "$dir" ]] || mkdir -p "$dir"

    g_temp_file="${g_temp_dir}/$(date '+%H%M%S%d%m')-playlist.txt"

    yt-dlp --quiet \
      --no-warnings \
      --flat-playlist \
      --ignore-errors \
      --print-to-file url \
      "$g_temp_file" "$g_url"

    local -a urls
    mapfile -t urls < "$g_temp_file"

    local url
    for url in "${urls[@]}"; do
      if ! f_dw_audio "$url" "$dir"; then
        download_failed=1
      fi
      printf '\n'
    done

    rm -f "$g_temp_file"
    g_temp_file=""
  else
    if ! f_dw_audio "$g_url" "$dir"; then
      download_failed=1
    fi
  fi

  end_time="$(date +%s)"
  runtime=$(( end_time - start_time ))
  printf '\nTotal program runtime lasted for %d seconds!\n\n' "$runtime"

  return "$download_failed"
}

f_main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        usage
        exit 0
        ;;
      --)
        shift
        break
        ;;
      -*)
        die "unknown option: $1"
        ;;
      *)
        break
        ;;
    esac
    shift
  done

  [[ $# -lt 1 ]] && { usage; exit 1; }

  g_url="$1"
  g_dir_or_audio_name="${2:-}"

  trap cleanup EXIT

  f_check_dependencies
  f_parse_data_and_dw
}

f_main "$@"
