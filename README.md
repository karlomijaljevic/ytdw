# YTDW - YouTube Audio Download

This simple script is used to download audio from YouTube. It needs three
programs to works properly:

- [yt-dlp](https://github.com/yt-dlp/yt-dlp)
- [ffmpeg](https://ffmpeg.org/)
- [aria2](https://github.com/aria2/aria2)

It can download playlists as well. It accepts two positional parameters and
an optional flag. The first parameter is the URL to the video/playlist and the
second parameter, which is optional, is the video/directory name.

It will save audio either into a directory defined by the environment variable
`XDG_MUSIC_DIR` and if none is found it will save it into `$HOME/music`.

By default the audio will be saved in the `opus` format, which is a modern
audio codec used by YouTube. To save it in a different format, pass
`-f`/`--format` with one of the formats supported by yt-dlp's
`--audio-format` option: `best`, `aac`, `alac`, `flac`, `m4a`, `mp3`, `opus`,
`vorbis`, `wav`. For example, to download in `mp3` instead:

```sh
./ytdw.sh -f mp3 "https://www.youtube.com/watch?v=eVTXPUF4Oz4&pp=ygUKaW4gdGhlIGVuZA%3D%3D" "In The End"
```

## Example use case

To download the audio of [In The End](https://www.youtube.com/watch?v=eVTXPUF4Oz4&pp=ygUKaW4gdGhlIGVuZA%3D%3D)
from Linkin Park.

```sh
./ytdw.sh "https://www.youtube.com/watch?v=eVTXPUF4Oz4&pp=ygUKaW4gdGhlIGVuZA%3D%3D" "In The End"
```

To download the entire playlist of their [Hybrid Theory](https://www.youtube.com/playlist?list=PLE6dlt5SQB8r5oagkd_cwA6FlhGLGlxef)
album:

```sh
./ytdw.sh "https://www.youtube.com/playlist?list=PLE6dlt5SQB8r5oagkd_cwA6FlhGLGlxef" "Hybrid Theory"
```
