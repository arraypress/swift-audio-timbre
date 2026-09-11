# Swift Audio Timbre

What a sound *sounds like*, as measured facts — brightness, texture, pitch, envelope, level
and stereo width. Pure Accelerate, no model, no network, no dependencies.

The describing half of [swift-audio-forge](https://github.com/arraypress/swift-audio-forge),
which does the cutting.

```swift
import AudioTimbre

let timbre = try TimbreAnalyzer.analyze(fileAt: url)

timbre.brightness            // .warm
timbre.spectralCentroidHz    // 1894.2
timbre.pitch?.name           // "C5"
timbre.attackMs              // 8.0
timbre.decayMs               // 1180.0
print(timbre.summary)
```

```
1.42 s, 44.1 kHz stereo
warm (centroid 1894 Hz, range 1620-2210) - tonal (flatness 0.008)
pitched C5 (523.3 Hz, +4 cents, confidence 0.87)
attack 8 ms, decay 1180 ms, sustain 0.34
peak -1.2 dBFS, RMS -18.4 dBFS
stereo: correlation 0.96, S/M -14.2 dB
```

## Why

Apple's sound classifier works on a fixed three-second window and returns **nothing at all**
below it. MusicUnderstanding needs two beats before it will name a tempo. Both are correct
for what they do, and both leave a 400 ms one-shot — the most common object in any sample
library — described by nothing but its file size.

Direct measurement has no such floor. A spectral centroid is well defined over 64 samples,
an attack time over two. Point this at a 40 ms hi-hat and it answers.

## What it will not do

**Name the sound.** No instrument, no genre, no "this is a kick". Classification belongs to
a trained model with held-out accuracy behind it; measuring and guessing are different jobs
and this only does the first.

The two are complementary rather than competing: a classifier says *what* a file is, this
says what it is *like*. Sixteen thousand files in a library are labelled `kick`; this is
what separates one from another.

## Every word ships beside its number

`brightness` never appears without `spectralCentroidHz`, `texture` never without
`spectralFlatness`, `pitch` never without `pitchConfidence`. The words are a convenience
for reading; the numbers are the measurement. Disagree with a boundary and you still have
the figure.

Where a word cannot be justified, there isn't one: `StereoImage` reports correlation and
Side/Mid as numbers with no adjective attached, because no boundary set for stereo width
was available to cite and inventing one would dress a guess as a measurement.

## Calibration

`Brightness` uses the boundaries from
[serum-mcp](https://github.com/Celian-mrc/serum-mcp)'s `sample_analysis.py` — 500 / 2,000 /
6,000 Hz — checked here against 360 one-shots across twelve classes, where they hold.

`Texture` does **not**. Those boundaries were re-measured, because the inherited pair put 22
of 25 claps in the same bucket as a kick. Median flatness per class, 30 files each:

| | | | |
|---|---|---|---|
| sub bass 0.001 | kick 0.003 | clap 0.071 | ride 0.162 |
| crash 0.177 | open hat 0.234 | snare 0.380 | closed hat 0.601 |

0.025 and 0.25 sit in the gaps between those clusters. The reason the inherited pair did not
transfer is that this library measures flatness **per frame and takes the median**, where the
reference takes one transform over the whole file — a different method gives different
numbers on the same audio, and a threshold does not survive the crossing.

## Measured

**Pitch agrees with the filename on 58 of 60** note-labelled files from a commercial pack
(`Sub Bassline - 001 - C.wav` → C1). Both misses are loops rather than one-shots, each a
semitone or two under the labelled key — the loudest window of a bassline need not sit on
the root.

Three bugs were found by real audio that no synthetic signal produced:

- **A 50 Hz pitch floor**, inherited, is above the fundamental of a sub bass. C1 is 32.7 Hz
  and D1 is 36.7, so a sub, a pluck and a lead all had correlation curves with no peak in
  range at all and came back unpitched. The floor is 20 Hz.
- **A fallback returning the edge of the search range.** With no interior peak, the tallest
  correlation sits at the shortest lag searched — 44,100 / 29 = 1,520.7 Hz — so an F-minor
  lead was reported as F#6 with 0.92 confidence. An edge of the window is an artifact of the
  window.
- **A raw autocorrelation is biased toward short lags**, because the overlap shrinks as the
  lag grows. On a 110 Hz sine, lag 29 outscored the true lag 401 on term count alone. Each
  lag is normalised by the energy of the spans it compares.

## Tested

56 tests against signals whose answers are known before they are measured: a 440 Hz sine has
a centroid of 440 Hz, a flatness near zero and a pitch of A4 — by construction, not
approximately. An exponential with a 100 ms time constant reaches −60 dB after 6.908 time
constants, which is arithmetic.

Mutation-verified: restoring the pitch floor, the boundary fallback, the raw correlation,
the DC removal or the bin-0 exclusion each fails the suite.

Six cases run against a real sample pack and assert **rates** rather than single files — one
kick proves nothing, a rate over thirty of them is a claim:

```sh
AUDIOTIMBRE_SAMPLES=~/Samples/SomePack swift test
```

## Requirements

macOS 14+ / iOS 17+, Swift 6.2. Accelerate for the maths; AVFoundation only to decode a file
into samples, so everything below `AudioDecoder` takes `[[Float]]` and can be tested in
memory.

## Licence

MIT.
