#!/usr/bin/env python3
"""Generate the deterministic Zone 1 audio presentation set (issue #181).

Every WAV in this directory is synthesized from scratch with Python's standard
library. The sounds combine muted medieval-material gestures (wood, string,
stone) with restrained synthetic relic tones, matching DESIGN.md §10 without
shipping third-party samples. Re-run from the repository root:

    python3 assets/audio/generate_placeholder_audio.py
"""

import math
import random
import struct
import wave
from pathlib import Path

SAMPLE_RATE = 22050
OUTPUT_DIR = Path(__file__).parent
TAU = math.tau


def write_wav(name: str, samples: list[float]) -> None:
    """Write a mono, signed 16-bit WAV after clipping the synthesis mix."""
    path = OUTPUT_DIR / name
    with wave.open(str(path), "wb") as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(SAMPLE_RATE)
        frames = bytearray()
        for sample in samples:
            clipped = max(-1.0, min(1.0, sample))
            frames += struct.pack("<h", int(clipped * 32767))
        wav_file.writeframes(bytes(frames))
    print(f"wrote {path.name}: {len(samples) / SAMPLE_RATE:.2f}s")


def sample_count(duration: float) -> int:
    return int(duration * SAMPLE_RATE)


def decay_envelope(progress: float, attack: float, decay: float = 5.0) -> float:
    """A click-free attack and exponential decay for one-shot combat cues."""
    if progress < attack:
        return progress / max(attack, 0.0001)
    return math.exp(-decay * (progress - attack) / max(0.0001, 1.0 - attack))


def filtered_noise(duration: float, seed: int, smoothing: float) -> list[float]:
    """Deterministic one-pole noise; low smoothing is rougher and brighter."""
    rng = random.Random(seed)
    value = 0.0
    result: list[float] = []
    for _ in range(sample_count(duration)):
        value += smoothing * (rng.uniform(-1.0, 1.0) - value)
        result.append(value)
    return result


def ambient_forest_drone() -> list[float]:
    """An eight-second loop: bowed-root drone plus distant relic pulse.

    All oscillators complete integral cycles over the loop, keeping the replay
    fallback in AudioManager continuous even when WAV loop metadata is ignored.
    """
    duration = 8.0
    samples: list[float] = []
    for index in range(sample_count(duration)):
        time = index / SAMPLE_RATE
        breath = 0.82 + 0.18 * math.sin(TAU * 0.25 * time)
        root = (
            0.48 * math.sin(TAU * 48.0 * time)
            + 0.22 * math.sin(TAU * 72.0 * time + 0.18 * math.sin(TAU * 0.5 * time))
            + 0.13 * math.sin(TAU * 96.0 * time)
        )
        relic = (
            0.055 * math.sin(TAU * 216.0 * time + 0.16 * math.sin(TAU * 0.25 * time))
            + 0.035 * math.sin(TAU * 288.0 * time)
        )
        samples.append(0.20 * breath * (root + relic))
    return samples


def sfx_melee_swing() -> list[float]:
    """A steel scrape followed by a broad air-whoosh."""
    duration = 0.22
    noise = filtered_noise(duration, seed=1811, smoothing=0.34)
    total = sample_count(duration)
    samples: list[float] = []
    for index in range(total):
        progress = index / total
        sweep_frequency = 720.0 - 290.0 * progress
        steel = math.sin(TAU * sweep_frequency * (index / SAMPLE_RATE))
        material = 0.62 * noise[index] + 0.20 * steel
        samples.append(0.56 * decay_envelope(progress, 0.07, 4.4) * material)
    return samples


def sfx_dash() -> list[float]:
    """A short low-to-high air displacement, distinct from the sword sweep."""
    duration = 0.16
    noise = filtered_noise(duration, seed=1812, smoothing=0.68)
    total = sample_count(duration)
    samples: list[float] = []
    for index in range(total):
        progress = index / total
        rush = math.sin(TAU * (130.0 + 260.0 * progress) * (index / SAMPLE_RATE))
        samples.append(0.46 * decay_envelope(progress, 0.025, 5.8) * (0.78 * noise[index] + 0.16 * rush))
    return samples


def sfx_relic_cast() -> list[float]:
    """A three-part cyan relic chirp that rises into a restrained electric tail."""
    duration = 0.34
    total = sample_count(duration)
    samples: list[float] = []
    phase = 0.0
    for index in range(total):
        progress = index / total
        frequency = 310.0 * math.pow(1180.0 / 310.0, progress)
        phase += TAU * frequency / SAMPLE_RATE
        signal = (
            0.58 * math.sin(phase)
            + 0.24 * math.sin(1.5 * phase + 0.25)
            + 0.12 * math.sin(2.0 * phase)
        )
        samples.append(0.52 * decay_envelope(progress, 0.035, 3.4) * signal)
    return samples


def sfx_hit() -> list[float]:
    """A readable wood-and-stone impact with a compact hostile-tech crack."""
    duration = 0.15
    noise = filtered_noise(duration, seed=1813, smoothing=0.84)
    total = sample_count(duration)
    samples: list[float] = []
    phase = 0.0
    for index in range(total):
        progress = index / total
        frequency = 190.0 * math.pow(62.0 / 190.0, progress)
        phase += TAU * frequency / SAMPLE_RATE
        thud = math.sin(phase)
        crack = noise[index] if progress < 0.18 else 0.0
        samples.append(0.66 * decay_envelope(progress, 0.012, 6.2) * (0.72 * thud + 0.32 * crack))
    return samples


def sfx_death() -> list[float]:
    """A broken-root descent: low material collapse with a fading relic overtone."""
    duration = 0.78
    noise = filtered_noise(duration, seed=1814, smoothing=0.18)
    total = sample_count(duration)
    samples: list[float] = []
    phase = 0.0
    for index in range(total):
        progress = index / total
        frequency = 260.0 * math.pow(44.0 / 260.0, progress)
        phase += TAU * frequency / SAMPLE_RATE
        fall = math.sin(phase) + 0.34 * math.sin(1.96 * phase)
        samples.append(0.50 * decay_envelope(progress, 0.04, 4.7) * (0.70 * fall + 0.27 * noise[index]))
    return samples


def main() -> None:
    write_wav("ambient_forest_drone.wav", ambient_forest_drone())
    write_wav("sfx_melee_swing.wav", sfx_melee_swing())
    write_wav("sfx_dash.wav", sfx_dash())
    write_wav("sfx_relic_cast.wav", sfx_relic_cast())
    write_wav("sfx_hit.wav", sfx_hit())
    write_wav("sfx_death.wav", sfx_death())


if __name__ == "__main__":
    main()
