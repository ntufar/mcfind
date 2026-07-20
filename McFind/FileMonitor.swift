import Foundation

class FileMonitor {
    private var eventStream: FSEventStreamRef?
    private let callback: (String, FSEventStreamEventFlags) -> Void
    private let pathsToWatch: [String]

    init(paths: [String], callback: @escaping (String, FSEventStreamEventFlags) -> Void) {
        self.pathsToWatch = paths
        self.callback = callback
    }

    func start() {
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let callbackWrapper: FSEventStreamCallback = { (
            streamRef: ConstFSEventStreamRef,
            clientCallBackInfo: UnsafeMutableRawPointer?,
            numEvents: Int,
            eventPaths: UnsafeMutableRawPointer,
            eventFlags: UnsafePointer<FSEventStreamEventFlags>,
            eventIds: UnsafePointer<FSEventStreamEventId>
        ) in
            let paths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as! [String]
            let monitor = Unmanaged<FileMonitor>.fromOpaque(clientCallBackInfo!).takeUnretainedValue()

            for i in 0..<numEvents {
                monitor.callback(paths[i], eventFlags[i])
            }
        }

        eventStream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callbackWrapper,
            &context,
            pathsToWatch as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.0, // latency in seconds
            UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        )

        guard let stream = eventStream else {
            Log.fileMonitor.error("❌ Failed to create FSEventStream")
            return
        }

        FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        FSEventStreamStart(stream)
        Log.fileMonitor.debug("✅ File monitoring started for: \(self.pathsToWatch)")
    }

    func stop() {
        guard let stream = eventStream else { return }

        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        eventStream = nil
        Log.fileMonitor.debug("🛑 File monitoring stopped")
    }

    deinit {
        stop()
    }
}
