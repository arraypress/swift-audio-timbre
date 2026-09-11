//
//  EnvelopeTests.swift
//  AudioTimbreTests
//
//  Created by David Sherlock on 2026.
//
//  Attack and decay, against a signal whose envelope is known in closed form.
//

import XCTest
@testable import AudioTimbre

final class EnvelopeTests: XCTestCase {

    private func measure(_ samples: [Float]) -> Envelope.Shape {
        Envelope.measure(samples, sampleRate: TestSignals.sampleRate)
    }

    func testAttackLandsOnTheOnset() {
        let shape = measure(TestSignals.decayingSine(hz: 440, tau: 0.1, onset: 0.1, seconds: 1.5))
        XCTAssertEqual(shape.attackMs, 100, accuracy: 3)
    }

    func testAttackOfASoundThatStartsImmediatelyIsZero() {
        let shape = measure(TestSignals.decayingSine(hz: 440, tau: 0.1, onset: 0, seconds: 1.5))
        XCTAssertEqual(shape.attackMs, 0, accuracy: 3)
    }

    func testDecayMatchesTheTimeConstant() {
        // A level of e^(-t/tau) falls 60 dB after 60*ln(10)/20 = 6.908 time constants.
        for tau in [0.05, 0.1, 0.2] {
            let shape = measure(TestSignals.decayingSine(hz: 440, tau: tau, onset: 0.05, seconds: 3))
            let expected = TestSignals.decayMs(tau: tau)
            XCTAssertNotNil(shape.decayMs, "tau \(tau) must reach -60 dB inside 3 s")
            XCTAssertEqual(shape.decayMs!, expected, accuracy: expected * 0.05,
                           "tau \(tau) should decay in \(expected) ms")
        }
    }

    func testASustainedToneReportsNoDecayRatherThanTheFileLength() {
        let shape = measure(TestSignals.sine(hz: 440, seconds: 2))
        XCTAssertNil(shape.decayMs, "it never fell 60 dB, and saying otherwise would invent a number")
        XCTAssertEqual(shape.sustainRatio, 1.0, accuracy: 0.02)
    }

    func testSustainRatioSeparatesAPercussiveHitFromAHeldNote() {
        let held = measure(TestSignals.sine(hz: 440, seconds: 1.5))
        let hit = measure(TestSignals.decayingSine(hz: 440, tau: 0.02, onset: 0.05, seconds: 1.5))
        XCTAssertGreaterThan(held.sustainRatio, 0.95)
        XCTAssertLessThan(hit.sustainRatio, 0.10)
    }

    func testSignalsTooShortForTwoWindowsReturnZeroesRatherThanGuessing() {
        let shape = measure(TestSignals.sine(hz: 440, seconds: 0.005))
        XCTAssertEqual(shape.attackMs, 0)
        XCTAssertNil(shape.decayMs)
        XCTAssertEqual(shape.sustainRatio, 0)
    }

    func testSilenceDoesNotDivideByZero() {
        let shape = measure(TestSignals.silence(seconds: 0.5))
        XCTAssertEqual(shape.attackMs, 0)
        XCTAssertNil(shape.decayMs)
    }
}
