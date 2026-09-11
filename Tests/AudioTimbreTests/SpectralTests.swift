//
//  SpectralTests.swift
//  AudioTimbreTests
//
//  Created by David Sherlock on 2026.
//
//  Centroid and flatness, against signals whose spectra are known in advance.
//

import XCTest
@testable import AudioTimbre

final class SpectralTests: XCTestCase {

    func testCentroidOfASineIsItsOwnFrequency() {
        // All the energy of a pure tone is at one frequency, so the energy-weighted mean
        // frequency is that frequency. Anything else means the transform, the window or
        // the bin-to-Hz mapping is wrong.
        for hz in [220.0, 440.0, 1000.0, 4000.0] {
            let shape = SpectralFeatures.measure(TestSignals.sine(hz: hz, seconds: 1),
                                                 sampleRate: TestSignals.sampleRate)
            XCTAssertNotNil(shape)
            XCTAssertEqual(shape!.centroidHz, hz, accuracy: hz * 0.02,
                           "centroid of a \(hz) Hz sine")
        }
    }

    func testASineIsTonalAndNoiseIsNoisy() {
        let sine = SpectralFeatures.measure(TestSignals.sine(hz: 440, seconds: 1),
                                            sampleRate: TestSignals.sampleRate)!
        let noise = SpectralFeatures.measure(TestSignals.whiteNoise(seconds: 1),
                                             sampleRate: TestSignals.sampleRate)!

        XCTAssertLessThan(sine.flatness, 0.025, "a pure tone is the flattest thing there is not")
        XCTAssertGreaterThan(noise.flatness, sine.flatness * 10)
        XCTAssertEqual(Texture.of(flatness: sine.flatness), .tonal)
        XCTAssertEqual(Texture.of(flatness: noise.flatness), .noisy)
    }

    func testWhiteNoiseCentroidSitsNearTheMiddleOfTheBand() {
        // Uniform energy from 0 to Nyquist puts the mean frequency at Nyquist/2.
        let shape = SpectralFeatures.measure(TestSignals.whiteNoise(seconds: 1),
                                             sampleRate: TestSignals.sampleRate)!
        XCTAssertEqual(shape.centroidHz, TestSignals.sampleRate / 4, accuracy: 1500)
    }

    func testADcOffsetDoesNotDragTheCentroidDown() {
        // The documented failure: with bin 0 excluded but the mean left in, a 1 kHz sine
        // carrying a 0.5 offset reads about 804 Hz, because a Hann window spreads the
        // offset into bin 1 as well. Both removals together must hold the true value.
        let clean = TestSignals.sine(hz: 1000, seconds: 1)
        let offset = TestSignals.offset(clean, by: 0.5)

        let a = SpectralFeatures.measure(clean, sampleRate: TestSignals.sampleRate)!
        let b = SpectralFeatures.measure(offset, sampleRate: TestSignals.sampleRate)!

        XCTAssertEqual(b.centroidHz, 1000, accuracy: 30, "DC must not pull the centroid down")
        XCTAssertEqual(a.centroidHz, b.centroidHz, accuracy: 15,
                       "an offset is not a sound; it should barely move the measurement")
    }

    func testTextureBucketsMatchTheMeasuredClassMedians() {
        // The medians from the 240-file calibration, each landing where it should.
        XCTAssertEqual(Texture.of(flatness: 0.001), .tonal)   // sub bass
        XCTAssertEqual(Texture.of(flatness: 0.003), .tonal)   // kick
        XCTAssertEqual(Texture.of(flatness: 0.071), .mixed)   // clap
        XCTAssertEqual(Texture.of(flatness: 0.234), .mixed)   // open hat
        XCTAssertEqual(Texture.of(flatness: 0.380), .noisy)   // snare
        XCTAssertEqual(Texture.of(flatness: 0.601), .noisy)   // closed hat
    }

    func testBrightnessBucketsFollowTheCentroid() {
        XCTAssertEqual(Brightness.of(centroidHz: 168), .dark)      // a kick
        XCTAssertEqual(Brightness.of(centroidHz: 1894), .warm)     // a bell
        XCTAssertEqual(Brightness.of(centroidHz: 3134), .bright)   // a snare
        XCTAssertEqual(Brightness.of(centroidHz: 10280), .airy)    // a hi-hat
    }

    func testAOneShotShorterThanAFullFrameStillMeasures() {
        // 46 ms at 44.1 kHz is 2,028 samples — under the preferred 2,048 frame. This is
        // the case Apple's classifier returns nothing for, and it must not return nothing
        // here.
        let short = TestSignals.sine(hz: 2000, seconds: 0.046)
        XCTAssertLessThan(short.count, Spectrum.preferredFrameSize)

        let shape = SpectralFeatures.measure(short, sampleRate: TestSignals.sampleRate)
        XCTAssertNotNil(shape, "a sub-frame one-shot must still be measurable")
        XCTAssertEqual(shape!.centroidHz, 2000, accuracy: 120)
    }

    func testFrameSizeDropsToFitAShortSignalAndStaysAPowerOfTwo() {
        XCTAssertEqual(Spectrum.frameSize(forSignalOf: 100_000), 2048)
        XCTAssertEqual(Spectrum.frameSize(forSignalOf: 2048), 2048)
        XCTAssertEqual(Spectrum.frameSize(forSignalOf: 2047), 1024)
        XCTAssertEqual(Spectrum.frameSize(forSignalOf: 100), 64)
        XCTAssertEqual(Spectrum.frameSize(forSignalOf: 1), Spectrum.minimumFrameSize)
    }

    func testSilenceIsRefusedRatherThanReportedAsZeroHz() {
        XCTAssertNil(SpectralFeatures.measure(TestSignals.silence(seconds: 0.5),
                                              sampleRate: TestSignals.sampleRate))
    }

    func testCentroidRangeWidensWhenTheSoundChangesCharacter() {
        // A sweep from dark to bright: one number cannot describe it, and the range is
        // what tells a caller so.
        let low = TestSignals.sine(hz: 200, seconds: 0.5)
        let high = TestSignals.sine(hz: 6000, seconds: 0.5)
        let sweep = low + high

        let steady = SpectralFeatures.measure(low, sampleRate: TestSignals.sampleRate)!
        let changing = SpectralFeatures.measure(sweep, sampleRate: TestSignals.sampleRate)!

        let steadySpread = steady.centroidRangeHz.upperBound - steady.centroidRangeHz.lowerBound
        let changingSpread = changing.centroidRangeHz.upperBound - changing.centroidRangeHz.lowerBound
        XCTAssertLessThan(steadySpread, 100)
        XCTAssertGreaterThan(changingSpread, 3000)
    }

    func testMedianOfAnEvenCountAveragesTheMiddleTwo() {
        XCTAssertEqual(SpectralFeatures.median([1, 2, 3, 4]), 2.5)
        XCTAssertEqual(SpectralFeatures.median([3, 1, 2]), 2)
        XCTAssertEqual(SpectralFeatures.median([]), 0)
    }
}
