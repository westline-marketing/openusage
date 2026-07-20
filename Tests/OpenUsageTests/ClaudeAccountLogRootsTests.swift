import XCTest
@testable import OpenUsage

/// Root discovery for account-scoped spend scans: an extra account's scan must cover exactly its own
/// config dir plus the data dirs signed into its email, so each card prices its own subscription
/// instead of repeating the machine-wide pool.
final class ClaudeAccountLogRootsTests: XCTestCase {
    private var home: URL!

    override func setUpWithError() throws {
        home = FileManager.default.temporaryDirectory
            .appendingPathComponent("claude-account-roots-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: home)
    }

    private func makeDataDir(_ name: String, email: String?, configAtHomeRoot: Bool = false) throws -> URL {
        let dir = home.appendingPathComponent(name)
        try FileManager.default.createDirectory(
            at: dir.appendingPathComponent("projects"), withIntermediateDirectories: true
        )
        if let email {
            let config = ["oauthAccount": ["emailAddress": email]]
            let data = try JSONSerialization.data(withJSONObject: config)
            let target = configAtHomeRoot
                ? home.appendingPathComponent(".claude.json")
                : dir.appendingPathComponent(".claude.json")
            try data.write(to: target)
        }
        return dir
    }

    private func roots(configDir: String, email: String?) -> Set<String> {
        let scoped = ClaudeLogUsageScanner.accountScopedRoots(
            scope: .init(configDir: configDir, email: email),
            home: home,
            environment: OverrideEnvironment([:])
        )
        return Set(scoped.map(\.path))
    }

    func testMatchesDirsSignedIntoTheAccountEmailCaseInsensitively() throws {
        let mine = try makeDataDir(".claude-2", email: "Jordan@Example.com")
        _ = try makeDataDir(".claude-3", email: "ads@example.com")
        let slot = home.appendingPathComponent("slot").path

        let result = roots(configDir: slot, email: "jordan@example.com")
        XCTAssertTrue(result.contains(slot))
        XCTAssertTrue(result.contains(mine.path))
        XCTAssertFalse(result.contains(home.appendingPathComponent(".claude-3").path))
    }

    func testDefaultClaudeDirEmailComesFromHomeRootConfigFile() throws {
        // The default `~/.claude` keeps its config at `~/.claude.json`, not inside the dir.
        let defaultDir = try makeDataDir(".claude", email: "main@example.com", configAtHomeRoot: true)
        let slot = home.appendingPathComponent("slot").path

        XCTAssertTrue(roots(configDir: slot, email: "main@example.com").contains(defaultDir.path))
        XCTAssertFalse(roots(configDir: slot, email: "other@example.com").contains(defaultDir.path))
    }

    func testNilEmailScansOnlyTheAccountConfigDir() throws {
        _ = try makeDataDir(".claude-2", email: "jordan@example.com")
        let slot = home.appendingPathComponent("slot").path

        XCTAssertEqual(roots(configDir: slot, email: nil), [slot])
    }

    func testDirWithoutProjectsOrEmailIsNeverClaimed() throws {
        // No projects/ folder → not a data dir even with a matching email.
        let bare = home.appendingPathComponent(".claude-bare")
        try FileManager.default.createDirectory(at: bare, withIntermediateDirectories: true)
        let config = ["oauthAccount": ["emailAddress": "jordan@example.com"]]
        try JSONSerialization.data(withJSONObject: config)
            .write(to: bare.appendingPathComponent(".claude.json"))
        // projects/ but no signed-in email → stays with the default instance.
        let anonymous = try makeDataDir(".claude-anon", email: nil)
        let slot = home.appendingPathComponent("slot").path

        let result = roots(configDir: slot, email: "jordan@example.com")
        XCTAssertFalse(result.contains(bare.path))
        XCTAssertFalse(result.contains(anonymous.path))
    }

    func testOwnConfigDirIsNotDuplicatedWhenItAlsoMatchesByEmail() throws {
        let dir = try makeDataDir(".claude-2", email: "jordan@example.com")

        let scoped = ClaudeLogUsageScanner.accountScopedRoots(
            scope: .init(configDir: dir.path, email: "jordan@example.com"),
            home: home,
            environment: OverrideEnvironment([:])
        )
        XCTAssertEqual(scoped.filter { $0.path == dir.resolvingSymlinksInPath().path }.count, 1)
    }
}
