import XCTest

/// Issue #99 (Nachtrag zu PR #193): Restock ist nur fürs iPhone. Geprüft wird `UIDeviceFamily` in der
/// `Info.plist` des gebauten Test-Hosts `Restock.app` und seiner beiden Erweiterungen, nicht die Build-Einstellung.
/// Fehlende Datei oder fehlender Schlüssel ist ein Fehler, nie ein Skip.
/// Spec: `docs/specs/fast/test-99-devicefamily-bundle-test.md`.
final class DeviceFamilyTests: XCTestCase {

    private func deviceFamily(_ relativePath: String) throws -> [Int] {
        let url = Bundle.main.bundleURL.appendingPathComponent(relativePath).appendingPathComponent("Info.plist")
        let data = try XCTUnwrap(FileManager.default.contents(atPath: url.path), "Info.plist fehlt: \(url.path)")
        let plist = try XCTUnwrap(
            try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
            "Info.plist nicht lesbar: \(url.path)")
        return try XCTUnwrap(plist["UIDeviceFamily"] as? [Int], "UIDeviceFamily fehlt: \(url.path)")
    }

    func testAppIsIphoneOnly() throws {
        XCTAssertEqual(try deviceFamily(""), [1])
    }

    func testWidgetExtensionIsIphoneOnly() throws {
        XCTAssertEqual(try deviceFamily("PlugIns/SmartCartWidgets.appex"), [1])
    }

    func testShareExtensionIsIphoneOnly() throws {
        XCTAssertEqual(try deviceFamily("PlugIns/RestockShareExtension.appex"), [1])
    }
}
