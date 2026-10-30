import Testing
@testable import SlimCityCore

@Suite("SlimCityCore package")
struct SlimCityCoreTests {
    @Test("package exposes a version")
    func exposesVersion() {
        #expect(SlimCityCore.version == "0.1.0")
    }
}
