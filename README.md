# Transcribe Videos to SRT

Simple CLI script that scans a directory for `.mp4` files and writes `.srt` subtitles next to each file using a Whisper model from Hugging Face.

## Requirements

- `ffmpeg` on your PATH (used to extract audio from `.mp4`)
- `uv` to run the script

## Installation

1) Install `uv`:

- `brew install uv`
- or https://docs.astral.sh/uv/getting-started/installation/#pypi

2) Clone this repo:

```bash
git clone https://github.com/ShipItSquad/video-transcription.git
cd video-transcription
```

3) Make the script executable:

```bash
chmod +x main.sh
```

4) Install `ffmpeg`:

macOS (Homebrew):
```bash
brew install ffmpeg
```

Ubuntu/Debian:
```bash
sudo apt-get update
sudo apt-get install ffmpeg
```

Verify it is on your PATH:
```bash
ffmpeg -version
```

## Usage

```bash
./main.sh --dir /path/to/videos
```

Optional flags:

- `--model` (default: `openai/whisper-base`)
- `--overwrite` to replace existing `.srt`
- `--language` to hint the language (e.g., `en`, `es`)
