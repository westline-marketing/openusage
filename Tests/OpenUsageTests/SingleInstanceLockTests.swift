import XCTest
@testable import OpenUsage

@MainActor
final class SingleInstanceLockTests: XCTestCase {
    func testSecondAcquisitionIsRejectedUntilTheFirstTokenIsReleased() throws {
        let lockURL = makeLockURL()
        var token: SingleInstanceLock.Token?

        switch SingleInstanceLock.acquire(at: lockURL) {
        case .acquired(let acquired):
            token = acquired
        default:
            XCTFail("first acquisition should own the lock")
        }

        XCTAssertNotNil(token)
        assertAlreadyRunning(SingleInstanceLock.acquire(at: lockURL))
        token = nil

        switch SingleInstanceLock.acquire(at: lockURL) {
        case .acquired:
            break
        default:
            XCTFail("lock should be acquirable after the first token is released")
        }
    }

    func testLockRejectsDuplicateWhenRunningApplicationSnapshotMissesThePeer() throws {
        let lockURL = makeLockURL()
        var token: SingleInstanceLock.Token?

        switch SingleInstanceLock.acquire(at: lockURL) {
        case .acquired(let acquired):
            token = acquired
        default:
            XCTFail("first acquisition should own the lock")
        }

        XCTAssertNotNil(token)
        XCTAssertNil(SingleInstanceGuard.instanceToYieldTo(myPID: 101, runningPIDs: [101]))
        assertAlreadyRunning(SingleInstanceLock.acquire(at: lockURL))
        token = nil
    }

    /// The relaunch-handoff wait (#restart race): the replacement instance must acquire the lock as
    /// soon as the exiting holder releases it, instead of declaring itself a duplicate on the first
    /// attempt — which killed both copies and left the app gone after an account change.
    func testHandoffRetryAcquiresOnceTheHolderReleasesMidWait() throws {
        let lockURL = makeLockURL()
        let box = TokenBox()

        switch SingleInstanceLock.acquire(at: lockURL) {
        case .acquired(let acquired):
            box.token = acquired
        default:
            XCTFail("first acquisition should own the lock")
        }

        // Release from another thread while the retry loop below blocks this one — the shape of an
        // exiting predecessor instance.
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) {
            box.token = nil
        }
        switch SingleInstanceLock.acquire(at: lockURL, retryingFor: 3) {
        case .acquired:
            break
        default:
            XCTFail("handoff retry should acquire once the holder releases")
        }
    }

    func testHandoffRetryStillGivesUpWhenTheHolderNeverReleases() throws {
        let lockURL = makeLockURL()
        var token: SingleInstanceLock.Token?

        switch SingleInstanceLock.acquire(at: lockURL) {
        case .acquired(let acquired):
            token = acquired
        default:
            XCTFail("first acquisition should own the lock")
        }

        let start = Date()
        assertAlreadyRunning(SingleInstanceLock.acquire(at: lockURL, retryingFor: 0.35))
        XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(start), 0.3)
        withExtendedLifetime(token) { token = nil }
    }

    private final class TokenBox: @unchecked Sendable {
        var token: SingleInstanceLock.Token?
    }

    private func makeLockURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("openusage-lock-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("OpenUsage.lock")
    }

    private func assertAlreadyRunning(
        _ acquisition: SingleInstanceLock.Acquisition,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .alreadyRunning = acquisition else {
            XCTFail("second acquisition should be rejected", file: file, line: line)
            return
        }
    }
}
