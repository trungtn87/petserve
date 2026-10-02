"""Generate PetVerse's original 32-second ambient loop (numpy + ffmpeg)."""
from pathlib import Path
import subprocess
import tempfile
import wave
import numpy as np

RATE = 22050
SECONDS = 32

def frequency(midi):
    return 440 * 2 ** ((midi - 69) / 12)

def generate():
    music = np.zeros(RATE * SECONDS)
    # Cmaj7 / Am7 / Fmaj7 / G6, two cycles at 120 BPM, restrained bell arpeggio.
    chords = [[48, 52, 55, 59], [45, 48, 52, 55], [41, 45, 48, 52], [43, 47, 50, 52]] * 2
    for bar, chord in enumerate(chords):
        offset = bar * 4
        t = np.arange(RATE * 4) / RATE
        envelope = np.minimum(t / 0.25, 1) * np.minimum((4 - t) / 0.4, 1)
        pad = sum(np.sin(2 * np.pi * frequency(note) * t) for note in chord) * 0.025
        music[offset * RATE:(offset + 4) * RATE] += pad * envelope
        for beat, degree in enumerate([0, 2, 1, 3, 2, 1, 3, 2]):
            start = int((offset + beat * 0.5) * RATE)
            t = np.arange(RATE) / RATE
            note = frequency(chord[degree] + 24)
            bell = (np.sin(2 * np.pi * note * t) + 0.12 * np.sin(2 * np.pi * note * 2 * t))
            bell *= np.minimum(t / 0.012, 1) * np.exp(-6 * t) * 0.055
            for delay, volume in [(0, 1), (0.25, 0.22)]:
                indices = (start + int(delay * RATE) + np.arange(len(t))) % len(music)
                music[indices] += bell * volume
    pcm = (np.clip(music, -0.95, 0.95) * 32767).astype('<i2')
    target = Path(__file__).resolve().parents[1] / 'assets/audio/quiet_arcade.ogg'
    target.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as folder:
        source = Path(folder) / 'music.wav'
        with wave.open(str(source), 'wb') as stream:
            stream.setnchannels(1)
            stream.setsampwidth(2)
            stream.setframerate(RATE)
            stream.writeframes(pcm.tobytes())
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(source), '-c:a', 'libvorbis', '-q:a', '3', str(target)], check=True)
    print(target)

if __name__ == '__main__':
    generate()
