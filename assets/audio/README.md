# PetVerse audio

`quiet_arcade.ogg` is an original 32-second instrumental loop generated for this project by `tools/generate_arcade_music.py`. No third-party recordings or samples are used. Regeneration requires Python with NumPy and ffmpeg with libvorbis.

UI effects are synthesized as small PCM streams by `core/audio_service.gd`. Music and UI effects use independent buses, persistent settings and the existing master sound switch. Music pauses while the app is in the background.
