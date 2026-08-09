import XCTest
@testable import Restock

/// Beweist die IKEA-Ergänzung im Store-Katalog (Nutzer meldete: "gibt es gar keinen Ikea als
/// Shop") — reine Datenlücke in `Store.presets(for:)`, der Katalog unterstützte Nicht-Grocery-
/// Läden (OBI, Hornbach, Decathlon, …) bereits vorher.
final class StorePresetsTests: XCTestCase {

    func testIKEAPresetExistsInEachSupportedCountry() {
        for country in Store.availableCountries {
            let names = Store.presets(for: country.code).map(\.name)
            XCTAssertTrue(
                names.contains("IKEA"),
                "IKEA fehlt im Preset-Katalog für \(country.name) (\(country.code))"
            )
        }
    }

    func testIKEAIconMapsToSofaSymbol() {
        let ikea = Store(name: "IKEA", emoji: "🛋️", colorHex: "#0058A3")
        XCTAssertEqual(ikea.iconSystemName, "sofa")
    }
}
