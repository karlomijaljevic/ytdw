# YTDW - YouTube Audio Download

This simple script is used to download audio from YouTube. It needs three
programs to works properly:

- [yt-dlp](https://github.com/yt-dlp/yt-dlp)
- [ffmpeg](https://ffmpeg.org/)
- [aria2](https://github.com/aria2/aria2)

It can download playlists as well. It accepts two parameters. The first
parameter is the URL to the video/playlist and the second parameter, which is
an optional one is the video/directory name.

It will save audio either into a directory defined by the environment variable
`AUDIO_DIRECTORY` and if none is found it will save it into `$HOME/music`.

The audio will be saved in the `opus` format, which is a modern audio codec
used by YouTube. If you want to change the format, you can do so by editing
the `ffmpeg` command in the script. For example, if you want to save the audio
in `mp3` format, you can change the command to (starts on line 91):

```sh
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
    --audio-format mp3 \
    --audio-quality 0 \
    --postprocessor-args "-q:a 0 -map a" \
    -o "$name" \
    "$url"
```

As you can see, the `--audio-format` option is set to `mp3` which will
convert the audio to `mp3` format instead of `opus`.

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