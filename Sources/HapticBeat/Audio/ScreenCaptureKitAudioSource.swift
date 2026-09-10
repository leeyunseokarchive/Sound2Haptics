import Foundation
import ScreenCaptureKit
import CoreMedia
import AVFoundation
import CoreAudio
import HapticBeatCore

public final class ScreenCaptureKitAudioSource: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    private let processor: AudioStreamProcessor
    private var stream: SCStream?
    private let queue = DispatchQueue(label: "com.hapticbeat.audiocapture", qos: .userInteractive)

    public var onPermissionError: (@Sendable (String) -> Void)?
    public var onStatusChange: (@Sendable (Bool) -> Void)?

    private(set) var isRunning: Bool = false

    public init(processor: AudioStreamProcessor) {
        self.processor = processor
        super.init()
    }

    public func startCapture() async {
        guard !isRunning else { return }

        do {
            let content = try await SCShareableContent.current
            guard let display = content.displays.first else {
                onPermissionError?("No active display found for audio capture.")
                return
            }

            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()
            config.capturesAudio = true
            config.sampleRate = 48000
            config.channelCount = 2

            // Minimize video capture resource usage (we only process audio)
            config.width = 2
            config.height = 2
            config.minimumFrameInterval = CMTime(value: 1, timescale: 1)

            let newStream = SCStream(filter: filter, configuration: config, delegate: self)
            try newStream.addStreamOutput(self, type: .audio, sampleHandlerQueue: queue)
            try await newStream.startCapture()

            self.stream = newStream
            self.isRunning = true
            self.onStatusChange?(true)
            print("[HapticBeat] ScreenCaptureKit audio capture stream successfully started.")
        } catch {
            self.isRunning = false
            self.onStatusChange?(false)
            self.onPermissionError?(error.localizedDescription)
            print("[HapticBeat] ScreenCaptureKit start error: \(error)")
        }
    }

    public func stopCapture() async {
        guard isRunning, let stream = stream else { return }
        do {
            try await stream.stopCapture()
        } catch {
            // Ignore stop errors
        }
        self.stream = nil
        self.isRunning = false
        self.onStatusChange?(false)
        print("[HapticBeat] ScreenCaptureKit audio capture stopped.")
    }

    // MARK: - SCStreamOutput
    public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }

        guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer),
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc)?.pointee else {
            return
        }

        let sampleRate = Float(asbd.mSampleRate > 0 ? asbd.mSampleRate : 48000.0)
        let channelCount = Int(asbd.mChannelsPerFrame > 0 ? asbd.mChannelsPerFrame : 2)

        let maxBuffers = max(1, channelCount)
        let bufferListSize = AudioBufferList.sizeInBytes(maximumBuffers: maxBuffers)
        let bufferListPtr = AudioBufferList.allocate(maximumBuffers: maxBuffers)
        defer { free(bufferListPtr.unsafeMutablePointer) }

        var blockBuffer: CMBlockBuffer?
        let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: bufferListPtr.unsafeMutablePointer,
            bufferListSize: bufferListSize,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: 0,
            blockBufferOut: &blockBuffer
        )

        guard status == noErr else {
            return
        }

        if bufferListPtr.count == 1, let mData = bufferListPtr[0].mData {
            // Interleaved or Mono audio
            let floatPtr = mData.assumingMemoryBound(to: Float.self)
            let sampleCount = Int(bufferListPtr[0].mDataByteSize) / MemoryLayout<Float>.size
            let samples = Array(UnsafeBufferPointer(start: floatPtr, count: sampleCount))
            processor.feedInterleavedAudio(samples: samples, channelCount: channelCount, sampleRate: sampleRate)
        } else if bufferListPtr.count >= 2, let leftData = bufferListPtr[0].mData, let rightData = bufferListPtr[1].mData {
            // Non-interleaved stereo
            let leftPtr = leftData.assumingMemoryBound(to: Float.self)
            let rightPtr = rightData.assumingMemoryBound(to: Float.self)
            let frameCount = Int(bufferListPtr[0].mDataByteSize) / MemoryLayout<Float>.size

            let left = Array(UnsafeBufferPointer(start: leftPtr, count: frameCount))
            let right = Array(UnsafeBufferPointer(start: rightPtr, count: frameCount))
            processor.feedStereoAudio(left: left, right: right, sampleRate: sampleRate)
        }
    }

    // MARK: - SCStreamDelegate
    public func stream(_ stream: SCStream, didStopWithError error: Error) {
        self.isRunning = false
        self.onStatusChange?(false)
        self.onPermissionError?(error.localizedDescription)
    }
}
