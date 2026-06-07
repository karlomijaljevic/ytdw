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
# by default, or in the format passed via -f/--format, and saved in the
# specified directory. If no directory is specified, it will be saved in the
# default directory which is set to $HOME/music. The script uses yt-dlp for
# downloading and aria2c for downloading the audio files.
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
g_valid_audio_formats="best aac alac flac m4a mp3 opus vorbis wav"
g_valid_audio_qualities="best medium low"

# Runtime state (populated in f_main)
g_url=""
g_audio_dir="${XDG_MUSIC_DIR:-"$HOME/music"}"
g_audio_format="opus"
g_format_explicit=0
g_audio_quality="best"
g_no_transcode=0
g_embed_thumbnail=0
g_artist=""
g_album=""
g_description=""
g_title=""
g_temp_dir=""
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
  printf 'Usage: %s [options] <url>\n' "$(basename "$0")" >&2
  printf '  url                 YouTube video or playlist URL\n' >&2
  printf '  -f, --format        audio output format (default: opus)\n' >&2
  printf '                      one of: %s\n' "$g_valid_audio_formats" >&2
  printf '  -q, --quality       source audio quality tier to download (default: best)\n' >&2
  printf '                      one of: %s\n' "$g_valid_audio_qualities" >&2
  printf '                      note: YouTube only serves two real source tiers per\n' >&2
  printf '                      codec, ~48kbps (low) and ~128kbps (medium); there is\n' >&2
  printf '                      no lossless source. "best" picks the highest available.\n' >&2
  printf '      --no-transcode  skip re-encoding; remux/extract the native stream as-is\n' >&2
  printf '                      (mutually exclusive with -f/--format)\n' >&2
  printf '  -t, --thumbnail     embed the video thumbnail as cover art\n' >&2
  printf '      --title         track title (single track only; also used as filename)\n' >&2
  printf '      --artist        artist tag to embed (applies to every track)\n' >&2
  printf '      --album         album tag to embed; also used as the playlist subdirectory\n' >&2
  printf '      --description   description tag to embed (applies to every track)\n' >&2
  printf '                      any of the four tag options left unset are prompted for\n' >&2
  printf '                      interactively when running in a terminal\n' >&2
}

# Checks that the requested audio format is one yt-dlp's --audio-format accepts.
f_validate_audio_format() {
  local format="$1"
  local valid

  for valid in $g_valid_audio_formats; do
    [[ "$format" == "$valid" ]] && return 0
  done

  die "unsupported audio format '$format' (expected one of: $g_valid_audio_formats)"
}

# Checks that the requested source quality tier is one this script understands.
f_validate_audio_quality() {
  local quality="$1"
  local valid

  for valid in $g_valid_audio_qualities; do
    [[ "$quality" == "$valid" ]] && return 0
  done

  die "unsupported audio quality '$quality' (expected one of: $g_valid_audio_qualities)"
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

# Wraps a value in single quotes for safe embedding inside an ffmpeg
# postprocessor-args string (yt-dlp shlex-splits that string before use).
f_shquote() {
  local value="$1"

  printf "'%s'" "${value//\'/\'\\\'\'}"
}

# Prompts (once, up front) for the four user-controllable tag fields that have
# not been supplied via flags. Only runs interactively (stdin is a tty); piped
# or scripted invocations skip every prompt so bare `ytdw <url>` stays
# unattended. artist/album/description are album-level and apply to every track
# of a playlist; title is per-track and is only collected for single tracks.
f_collect_metadata() {
  [[ -t 0 ]] || return 0

  [[ -z "$g_artist" ]] && read -rp "Artist (optional, applies to all tracks): " g_artist
  [[ -z "$g_album" ]] && read -rp "Album (optional, applies to all tracks): " g_album
  [[ -z "$g_description" ]] && read -rp "Description (optional, applies to all tracks): " g_description

  if [[ "$g_is_playlist" -eq 0 ]] && [[ -z "$g_title" ]]; then
    read -rp "Title (optional): " g_title
  fi

  return 0
}

# Downloads audio from a single URL into dir. Reports success/failure to stdout.
f_dw_audio() {
  local url="$1"
  local dir="$2"
  local name
  local audio_format
  local pp_args="-q:a 0 -map a"
  local -a args=()

  if [[ "$g_is_playlist" -eq 1 ]]; then
    name="$dir/%(title)s.%(ext)s"
  elif [[ -n "$g_title" ]]; then
    name="$dir/$g_title.%(ext)s"
  else
    name="$dir/%(title)s.%(ext)s"
  fi

  case "$g_audio_quality" in
    best) ;;
    medium) args+=(--format "bestaudio[abr<=160]/bestaudio") ;;
    low) args+=(--format "worstaudio[abr>=40]/worstaudio") ;;
  esac

  if [[ "$g_no_transcode" -eq 1 ]]; then
    # yt-dlp's own "best" audio-format means "keep the native codec/container",
    # i.e. remux without re-encoding — exactly what --no-transcode asks for.
    audio_format="best"
  else
    audio_format="$g_audio_format"
    args+=(--audio-quality 0 --postprocessor-args "$pp_args")
  fi

  args+=(--extract-audio --audio-format "$audio_format")

  args+=(--embed-metadata)
  args+=(--parse-metadata "%(channel)s:%(meta_channel)s")

  if [[ -n "$g_artist" || -n "$g_album" || -n "$g_description" || ( "$g_is_playlist" -eq 0 && -n "$g_title" ) ]]; then
    local meta_pp="-metadata"
    [[ -n "$g_artist" ]] && meta_pp+=" artist=$(f_shquote "$g_artist")"
    [[ -n "$g_album" ]] && meta_pp+=" -metadata album=$(f_shquote "$g_album")"
    [[ -n "$g_description" ]] && meta_pp+=" -metadata description=$(f_shquote "$g_description")"
    [[ "$g_is_playlist" -eq 0 && -n "$g_title" ]] && meta_pp+=" -metadata title=$(f_shquote "$g_title")"
    args+=(--postprocessor-args "$meta_pp")
  fi

  if [[ "$g_embed_thumbnail" -eq 1 ]]; then
    args+=(--embed-thumbnail --convert-thumbnails jpg)
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
    "${args[@]}" \
    -o "$name" \
    "$url"; then
    printf "${c_red}Failed to download audio from URL '%s'!${c_normal}\n" "$url"
    return 1
  else
    printf "${c_green}Audio from URL '%s' downloaded successfully!${c_normal}\n" "$url"
  fi
}

# Enumerates a playlist's entries into a TSV temp file: url, title, id and a
# preview-sized thumbnail URL per record. Groundwork for a future interactive
# picker (see f_playlist_picker) — does not change current download behaviour.
f_enumerate_playlist() {
  local url="$1"
  local out

  out="$g_temp_dir/$(date '+%H%M%S%d%m')-playlist.tsv"

  yt-dlp --quiet \
    --no-warnings \
    --flat-playlist \
    --ignore-errors \
    --print-to-file "$(printf '%%(url)s\t%%(title)s\t%%(id)s\t%%(thumbnails.0.url)s')" \
    "$out" "$url"

  printf '%s' "$out"
}

# Stub for a future interactive playlist picker (choose tracks, preview
# thumbnails). For now it passes every enumerated entry through unchanged so
# playlist downloads behave exactly as before this groundwork was laid.
# TODO: prompt the user with the title/thumbnail columns and return only the
# selected subset of URLs.
f_playlist_picker() {
  local tsv="$1"
  local -a urls=()
  local url

  while IFS=$'\t' read -r url _; do
    [[ -n "$url" ]] && urls+=("$url")
  done < "$tsv"

  printf '%s\n' "${urls[@]}"
}

# Determines whether the URL is a playlist or single track and dispatches downloads.
f_parse_data_and_dw() {
  local dir="$g_audio_dir"
  local start_time
  local end_time
  local runtime
  local download_failed=0

  start_time="$(date +%s)"

  if [[ "$g_is_playlist" -eq 1 ]]; then
    printf 'Starting to download playlist at URL: %s\n' "$g_url"

    if [[ -n "$g_album" ]]; then
      dir="$g_audio_dir/$g_album"
    else
      dir="$g_audio_dir/$(date '+%H%M%S%d%m')-playlist"
    fi

    [[ -d "$dir" ]] || mkdir -p "$dir"

    g_temp_file="$(f_enumerate_playlist "$g_url")"

    local -a urls
    mapfile -t urls < <(f_playlist_picker "$g_temp_file")

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
      -f|--format)
        [[ $# -lt 2 ]] && die "option '$1' requires an argument"
        g_audio_format="$2"
        g_format_explicit=1
        shift
        ;;
      -q|--quality)
        [[ $# -lt 2 ]] && die "option '$1' requires an argument"
        g_audio_quality="$2"
        shift
        ;;
      --no-transcode)
        g_no_transcode=1
        ;;
      -t|--thumbnail)
        g_embed_thumbnail=1
        ;;
      --title)
        [[ $# -lt 2 ]] && die "option '$1' requires an argument"
        g_title="$2"
        shift
        ;;
      --artist)
        [[ $# -lt 2 ]] && die "option '$1' requires an argument"
        g_artist="$2"
        shift
        ;;
      --album)
        [[ $# -lt 2 ]] && die "option '$1' requires an argument"
        g_album="$2"
        shift
        ;;
      --description)
        [[ $# -lt 2 ]] && die "option '$1' requires an argument"
        g_description="$2"
        shift
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

  f_validate_audio_format "$g_audio_format"
  f_validate_audio_quality "$g_audio_quality"

  [[ "$g_no_transcode" -eq 1 && "$g_format_explicit" -eq 1 ]] &&
    die "--no-transcode and -f/--format are mutually exclusive"

  [[ "$g_url" == *"playlist"* ]] && g_is_playlist=1

  f_collect_metadata

  trap cleanup EXIT

  f_check_dependencies
  f_parse_data_and_dw
}

f_main "$@"
