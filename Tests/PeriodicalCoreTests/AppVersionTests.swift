import Testing
@testable import PeriodicalCore

@Test func parsesTagsAndBundleVersions() {
    #expect(AppVersion("v0.3.1")?.components == [0, 3, 1])
    #expect(AppVersion("0.2.0")?.components == [0, 2, 0])
    #expect(AppVersion("1.4.0-beta.2")?.components == [1, 4, 0])
    #expect(AppVersion("2+45")?.components == [2])
    #expect(AppVersion("") == nil)
    #expect(AppVersion("v1..2") == nil)
    #expect(AppVersion("latest") == nil)
}

@Test func comparesNumerically() {
    let v = { (s: String) in AppVersion(s)! }
    #expect(v("0.2.0") < v("0.3.0"))
    #expect(v("0.9.0") < v("0.10.0"))
    #expect(v("1.2") == v("1.2.0"))
    #expect(!(v("1.2.0") < v("1.2")))
    #expect(v("v1.0.0") > v("0.99.99"))
}
