# Swift Audio Timbre

What a sound *sounds like*, as measured facts — brightness, texture, pitch, envelope, level and
stereo width — plus two streamed readers for files too long to hold: the waveform's shape for
drawing and the peak level with rail hits. Pure Accelerate for the maths, AVFoundation only to
decode; no model, no network, no dependencies. The describing half of swift-audio-forge, which
does the cutting.

- Module `AudioTimbre` in `Sources/AudioTimbre`; tests in `Tests`; `swift test` is the whole check.
- Swift 6 language mode, tools 6.2, macOS 14+ (iOS 17), no dependencies.
- Part of the Sidewatch package family; every package follows the same layout and PR rules.

## Module map

- `Core/` — `TimbreAnalyzer` (the whole description), `SpectralFeatures`, `HarmonicAnalyzer`, `PitchEstimator`, `ChromaAnalysis`, `Envelope`, `Loudness` (peak / RMS of samples in memory), `StereoAnalysis`; the streamed pair added 22 Sep 2026 for a media gallery — `Waveform` (`peaks(fileAt:bins:)`: one normalised peak per bin from an 8 kHz mono read, capped at 20 minutes) and `Level` (`measure(fileAt:)`: the loudest sample and the count at the 16-bit rails, at the file's own rate and channels)
- `Models/` — `Timbre`, `Pitch`, `PitchClassProfile`, `StereoImage`, `AttackRejection`, `LevelReport`
- `Enums/` — `Brightness`, `Texture`
- `Errors/` — `AudioTimbreError`
- `Support/` — `AudioDecoder` (a whole file into Float channels), `SampleStream` (blocks of Int16 through a sink, never the whole file), and the maths helpers

## Rules

@CONTRIBUTING.md

- **Auditing? Read `AUDIT.md` first** — what the last full audit checked and fixed, and the known non-issues to skip; extend it, do not redo it.
