# YTDW

This simple script is used to download audio from YouTube. It needs three
programs to works properly:

- [yt-dlp](https://github.com/yt-dlp/yt-dlp)
- [ffmpeg](https://ffmpeg.org/)
- [aria2](https://github.com/aria2/aria2)

It can download playlists as well. It accepts two parameters. The
first parameter is the URL to the video/playlist and the second parameter, which
is an optional one is the video/directory name.

It will save audio either into a directory defined by the environment variable
`AUDIO_DIRECTORY` and if none is found it will save it into `$HOME/Downloads`.

The GPL-2.0 license is added to respect aria2 and ffmpeg.

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