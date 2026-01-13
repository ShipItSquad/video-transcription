#!/usr/bin/env -S uv run --script
#
# /// script
# requires-python = ">=3.12"
# dependencies = ["loguru", "torch", "transformers"]
# ///

from pathlib import Path
import argparse
import shutil
import subprocess
import tempfile
import torch
from loguru import logger
from transformers import pipeline

def get_device():
    if torch.cuda.is_available():
        return 0
    if torch.backends.mps.is_available():
        return "mps"
    return -1

def extract_audio(mp4: Path) -> Path | None:
    if shutil.which("ffmpeg") is None:
        logger.error("ffmpeg not found on PATH; cannot decode {}", mp4)
        return None
    tmp = tempfile.NamedTemporaryFile(suffix=".wav", delete=False)
    tmp_path = Path(tmp.name)
    tmp.close()
    cmd = [
        "ffmpeg",
        "-y",
        "-i",
        str(mp4),
        "-ac",
        "1",
        "-ar",
        "16000",
        "-vn",
        str(tmp_path),
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        logger.error("ffmpeg failed for {}: {}", mp4, result.stderr.strip())
        tmp_path.unlink(missing_ok=True)
        return None
    return tmp_path

def transcribe_mp4s(root: Path, model_name: str, overwrite: bool, language: str | None) -> None:
    if shutil.which("ffmpeg") is None:
        logger.warning("ffmpeg not found on PATH; decoding may fail for .mp4 files.")

    device = get_device()
    asr = pipeline(
        "automatic-speech-recognition",
        model=model_name,
        device=device,
        ignore_warning=True,
    )

    for mp4 in root.rglob("*.mp4"):
        if not mp4.is_file():
            continue
        logger.info("Processing: {}", mp4)
        srt_path = mp4.with_suffix(".srt")
        if srt_path.exists() and not overwrite:
            logger.info("Skipping (exists): {}", srt_path)
            continue

        audio_path = extract_audio(mp4)
        if audio_path is None:
            continue

        try:
            generate_kwargs = {"task": "transcribe"}
            if language:
                generate_kwargs["language"] = language
            result = asr(str(audio_path), generate_kwargs=generate_kwargs, return_timestamps=True)
            chunks = result.get("chunks") or []

            def fmt_srt_time(seconds: float) -> str:
                total_ms = int(round(seconds * 1000))
                ms = total_ms % 1000
                total_s = total_ms // 1000
                s = total_s % 60
                total_m = total_s // 60
                m = total_m % 60
                h = total_m // 60
                return f"{h:02d}:{m:02d}:{s:02d},{ms:03d}"

            lines = []
            idx = 1
            for chunk in chunks:
                ts = chunk.get("timestamp") or (None, None)
                start, end = ts
                if start is None or end is None:
                    continue
                text = (chunk.get("text") or "").strip()
                if not text:
                    continue
                lines.append(str(idx))
                lines.append(f"{fmt_srt_time(float(start))} --> {fmt_srt_time(float(end))}")
                lines.append(text)
                lines.append("")
                idx += 1

            srt_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
            logger.info("Wrote: {}", srt_path)
        except PermissionError:
            logger.warning("Skipping (permission denied): {}", srt_path)
        except Exception as exc:
            logger.error("Failed: {} ({})", mp4, exc)
        finally:
            audio_path.unlink(missing_ok=True)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Transcribe .mp4 files to .srt with Whisper.")
    parser.add_argument(
        "--dir",
        type=Path,
        default=Path("."),
        help="Root directory to scan (default: current directory).",
    )
    parser.add_argument(
        "--model",
        default="openai/whisper-base",
        help="Hugging Face model id to use.",
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Overwrite existing .srt files.",
    )
    parser.add_argument(
        "--language",
        default=None,
        help="Optional language code to hint Whisper (e.g., en, es).",
    )
    args = parser.parse_args()

    transcribe_mp4s(args.dir, args.model, args.overwrite, args.language)
    logger.info("Done")
