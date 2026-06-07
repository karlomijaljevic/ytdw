# YTDW - YouTube Audio Download

This simple script is used to download audio from YouTube. It needs three
programs to works properly:

- [yt-dlp](https://github.com/yt-dlp/yt-dlp)
- [ffmpeg](https://ffmpeg.org/)
- [aria2](https://github.com/aria2/aria2)

It can download playlists as well. It accepts a single mandatory positional
parameter, the URL to the video/playlist, plus a set of optional flags.

It will save audio either into a directory defined by the environment variable
`XDG_MUSIC_DIR` and if none is found it will save it into `$HOME/music`.

By default the audio will be saved in the `opus` format, which is a modern
audio codec used by YouTube. To save it in a different format, pass
`-f`/`--format` with one of the formats supported by yt-dlp's
`--audio-format` option: `best`, `aac`, `alac`, `flac`, `m4a`, `mp3`, `opus`,
`vorbis`, `wav`. For example, to download in `mp3` instead:

```sh
./ytdw.sh -f mp3 --title "In The End" "https://www.youtube.com/watch?v=eVTXPUF4Oz4&pp=ygUKaW4gdGhlIGVuZA%3D%3D"
```

## Options

- `-f, --format <fmt>`: audio output format to transcode to (default: `opus`),
  one of `best`, `aac`, `alac`, `flac`, `m4a`, `mp3`, `opus`, `vorbis`, `wav`.
- `-q, --quality <tier>`: source audio quality tier to download from YouTube
  (default: `best`), one of `best`, `medium`, `low`. YouTube only serves two
  real source tiers per codec — roughly 48kbps (`low`) and 128kbps (`medium`)
  — there is no lossless source; `best` simply picks the highest available.
- `--no-transcode`: skip re-encoding entirely and remux/extract the native
  audio stream as-is (faster, no quality loss). Mutually exclusive with
  `-f`/`--format`.
- `-i, --interactive`: for playlist URLs, preview each entry — thumbnail,
  channel, title and duration — and choose which tracks to download, then pick
  a single quality tier (`best`/`medium`/`low`) applied to the whole selection.
  Requires an interactive terminal; ignored for single-track URLs. Thumbnails
  are drawn with the first available image renderer (`kitty`'s `icat`, `chafa`,
  `viu` or `timg`); when none is installed the thumbnail URL is printed
  instead. Entry enumeration stays fast (no per-video probing).
- `-t, --thumbnail`: embed the video's thumbnail into the audio file as cover
  art.
- `--title <name>`: track title; also used as the output filename. Only valid
  for single-track URLs (the script exits with an error if combined with a
  playlist URL — use `--album` to name a playlist's output directory).
- `--artist <name>`: artist tag embedded into every downloaded track.
- `--album <name>`: album tag embedded into every track; for playlists it is
  also used as the output subdirectory name.
- `--description <text>`: description tag embedded into every track.

`--artist`, `--album`, `--description` and (for single tracks) `--title` are
embedded as metadata regardless of how they are supplied. Any of them left
unset are prompted for interactively when the script is run from a terminal —
piped or scripted invocations skip the prompts so a bare `ytdw <url>` stays
fully unattended. `upload_date`, `duration` and `channel` are always taken
from yt-dlp's own metadata and embedded automatically; they are never
prompted for. Playlist downloads also get a `track` tag (`N/total`) numbered
over the set actually downloaded — so an interactive selection is numbered
`1..N` across just the chosen tracks.

## Example use case

To download the audio of [In The End](https://www.youtube.com/watch?v=eVTXPUF4Oz4&pp=ygUKaW4gdGhlIGVuZA%3D%3D)
from Linkin Park, embedding the thumbnail as cover art:

```sh
./ytdw.sh -t --title "In The End" --artist "Linkin Park" "https://www.youtube.com/watch?v=eVTXPUF4Oz4&pp=ygUKaW4gdGhlIGVuZA%3D%3D"
```

To download the entire playlist of their [Hybrid Theory](https://www.youtube.com/playlist?list=PLE6dlt5SQB8r5oagkd_cwA6FlhGLGlxef)
album, keeping the native source stream instead of transcoding:

```sh
./ytdw.sh --no-transcode --album "Hybrid Theory" --artist "Linkin Park" "https://www.youtube.com/playlist?list=PLE6dlt5SQB8r5oagkd_cwA6FlhGLGlxef"
```
