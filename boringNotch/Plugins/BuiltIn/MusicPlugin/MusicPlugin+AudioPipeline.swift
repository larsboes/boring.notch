//
//  MusicPlugin+AudioPipeline.swift
//  boringNotch
//
//  Audio capture + FFT pipeline for MusicPlugin.
//  Starts/stops with playback. Writes frequencyBands/peakBands on MainActor
//  so ContentView observes changes automatically.
//

import Foundation

extension MusicPlugin {

    static let audioBandCount: Int = 32

    // MARK: - Setup

    func setupAudioPipeline() {
        let processor = AudioFFTProcessor(bandCount: Self.audioBandCount)
        fftProcessor = processor

        let service: any AudioCaptureServiceProtocol
        if #available(macOS 13.0, *) {
            service = ScreenCaptureKitAudioService()
        } else {
            service = MockAudioCaptureService()
        }

        service.setBufferHandler { [weak self] samples in
            guard let self else { return }
            self.fftProcessor?.process(samples)
            if let processor = self.fftProcessor {
                self.frequencyBands = processor.frequencyBands
                self.peakBands = processor.peakBands
            }
        }

        audioCaptureService = service
    }

    // MARK: - Capture Control

    func startAudioCapture() async {
        guard let service = audioCaptureService, !service.isCapturing else { return }
        do {
            try await service.startCapture()
        } catch {
            // Screen recording permission denied — fall back to mock
            let mock = MockAudioCaptureService()
            mock.setBufferHandler { [weak self] samples in
                guard let self else { return }
                self.fftProcessor?.process(samples)
                if let processor = self.fftProcessor {
                    self.frequencyBands = processor.frequencyBands
                    self.peakBands = processor.peakBands
                }
            }
            audioCaptureService = mock
            try? await mock.startCapture()
        }
    }

    func stopAudioCapture() async {
        await audioCaptureService?.stopCapture()
        frequencyBands = Array(repeating: 0, count: Self.audioBandCount)
        peakBands = Array(repeating: 0, count: Self.audioBandCount)
    }
}
