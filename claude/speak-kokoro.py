#!/usr/bin/env python3
################################################################################
# speak: the synthesiser
#
# Reads a text file and speaks it. Synthesis and playback run at the same time,
# which is the whole point of this file: Kokoro takes about 5 s to synthesise the
# 18 s of audio a long reply turns into, so waiting for the file to be finished
# before playing it would put five silent seconds in front of every reply.
#
# Splitting by sentence and starting playback on the first one drops that to
# ~1.8 s from a cold start, and synthesis then stays permanently ahead of the
# speakers: the queue only ever grows.
#
# Invoked by speak-lib.sh, never by hand. The temp prefix is passed as argv[1]
# because it carries the console id that `speak stop` matches with pkill -f, so
# it has to appear in this process's own command line.
#
#   speak-kokoro.py <tmp-prefix> <text-file> <voice> <speed>
################################################################################

import os
import queue
import re
import signal
import subprocess
import sys
import threading
import wave

# espeak-ng is the grapheme-to-phoneme front end. The copy that ships inside the
# espeakng-loader wheel has its data directory baked in at build time, pointing at
# the GitHub runner that built it, so it dies on a missing phontab. Homebrew's copy
# is the one that works, and doctor.sh checks that it is installed.
os.environ.setdefault("PHONEMIZER_ESPEAK_LIBRARY", "/opt/homebrew/lib/libespeak-ng.dylib")
os.environ.setdefault("ESPEAK_DATA_PATH", "/opt/homebrew/share/espeak-ng-data")

KOKORO_HOME = os.path.expanduser("~/.local/share/kokoro")
MODEL = os.path.join(KOKORO_HOME, "kokoro-v1.0.onnx")
VOICES = os.path.join(KOKORO_HOME, "voices-v1.0.bin")
SAMPLE_RATE = 24000

# Split on sentence enders, but only when followed by whitespace, so version
# numbers and file.paths stay in one piece. A reply that is one long sentence is
# left whole: it costs a slower first word, not a wrong reading.
SENTENCE = re.compile(r"(?<=[.!?:;])\s+")


def sentences(text):
    return [s.strip() for s in SENTENCE.split(text) if s.strip()]


def write_wav(path, samples):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        # Kokoro returns float32 in [-1, 1]; afplay wants 16-bit PCM.
        w.writeframes((samples.clip(-1, 1) * 32767).astype("<i2").tobytes())


def main():
    if len(sys.argv) != 5:
        sys.exit("usage: speak-kokoro.py <tmp-prefix> <text-file> <voice> <speed>")
    prefix, src, voice, speed = sys.argv[1], sys.argv[2], sys.argv[3], float(sys.argv[4])

    with open(src, encoding="utf-8") as fh:
        parts = sentences(fh.read().strip())
    if not parts:
        return 0

    import numpy as np
    from kokoro_onnx import Kokoro

    kokoro = Kokoro(MODEL, VOICES)

    # The player owns the current afplay so a TERM can kill it: without this,
    # `speak stop` would end this process and leave the last sentence playing to
    # the end. A list because the handler runs on the main thread.
    current = []

    def stop(_signum, _frame):
        for proc in current:
            proc.terminate()
        os._exit(0)

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)

    clips = queue.Queue()

    def play():
        while True:
            path = clips.get()
            if path is None:
                return
            proc = subprocess.Popen(
                ["afplay", path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
            )
            current.append(proc)
            proc.wait()
            current.remove(proc)
            os.unlink(path)

    player = threading.Thread(target=play, daemon=True)
    player.start()

    for i, part in enumerate(parts):
        samples, _ = kokoro.create(part, voice=voice, speed=speed, lang="es")
        clip = f"{prefix}.{i}.wav"
        write_wav(clip, np.asarray(samples))
        clips.put(clip)
    clips.put(None)
    player.join()
    return 0


if __name__ == "__main__":
    sys.exit(main())
