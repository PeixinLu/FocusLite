import XCTest
@testable import FocusLite

final class MatchingTests: XCTestCase {
    func testAcceptanceRankingCases() {
        let cases: [(query: String, names: [String], expectedTop: String)] = [
            ("ps", ["Adobe Photoshop"], "Adobe Photoshop"),
            ("adps", ["Adobe Photoshop", "Adobe Premiere"], "Adobe Photoshop"),
            ("wx", ["微信"], "微信"),
            ("weixin", ["微信"], "微信"),
            ("zfb", ["支付宝"], "支付宝"),
            ("zhifubao", ["支付宝"], "支付宝"),
            ("qqyy", ["QQ音乐"], "QQ音乐"),
            ("wangyiyun", ["网易云音乐"], "网易云音乐"),
            ("wyy", ["网易云音乐"], "网易云音乐"),
            ("xcode", ["Xcode", "Xcode Cloud"], "Xcode"),
            ("visual studio", ["Visual Studio Code"], "Visual Studio Code"),
            ("vsc", ["Visual Studio Code"], "Visual Studio Code"),
            ("vscode", ["Visual Studio Code", "Visual Studio"], "Visual Studio Code"),
            ("音乐", ["QQ音乐", "网易云音乐"], "QQ音乐")
        ]

        for item in cases {
            let ranked = rank(query: item.query, names: item.names)
            XCTAssertEqual(ranked.first?.name, item.expectedTop, "Query: \(item.query)")
        }
    }

    func testEnglishFuzzyCases() {
        let cases: [(String, String)] = [
            ("xcode", "Xcode"),
            ("xc", "Xcode"),
            ("adobephoto", "Adobe Photoshop"),
            ("photoshp", "Adobe Photoshop"),
            ("prem", "Adobe Premiere"),
            ("final cut", "Final Cut Pro"),
            ("fcp", "Final Cut Pro"),
            ("vs code", "Visual Studio Code"),
            ("visualstudio", "Visual Studio Code")
        ]

        for (query, name) in cases {
            XCTAssertNotNil(match(query: query, name: name), "Query: \(query)")
        }
    }

    func testChineseAndPinyinCases() {
        let cases: [(String, String)] = [
            ("微信", "微信"),
            ("weixin", "微信"),
            ("wx", "微信"),
            ("支付宝", "支付宝"),
            ("zfb", "支付宝"),
            ("zhifubao", "支付宝"),
            ("网易云音乐", "网易云音乐"),
            ("wangyiyun", "网易云音乐"),
            ("wyy", "网易云音乐"),
            ("音乐", "QQ音乐"),
            ("音乐", "网易云音乐"),
            ("jianyingzhuanyeban", "剪映专业版"),
            ("jyzyb", "剪映专业版")
        ]

        for (query, name) in cases {
            XCTAssertNotNil(match(query: query, name: name), "Query: \(query)")
        }
    }

    func testMixedTokenCoverage() {
        let name = "Visual Studio Code"
        let full = match(query: "visual studio", name: name)
        let single = match(query: "visual", name: name)

        XCTAssertNotNil(full)
        XCTAssertNotNil(single)
        XCTAssertGreaterThan(full?.finalScore ?? 0, single?.finalScore ?? 0)
    }

    func testAcronymAndPinyinTypes() {
        let weixin = makeIndex(name: "微信")
        let result = Matcher.match(query: "wx", index: weixin)
        XCTAssertEqual(result?.bucket, .acronymOrInitials)

        let photoshop = makeIndex(name: "Adobe Photoshop")
        let ps = Matcher.match(query: "ps", index: photoshop)
        XCTAssertEqual(ps?.bucket, .acronymOrInitials)
    }

    func testCaseAndWidthNormalization() {
        let cases: [(String, String)] = [
            ("XCODE", "Xcode"),
            ("ＶＳＣ", "Visual Studio Code"),
            ("Ｃｏｄｅ", "Visual Studio Code"),
            ("café", "Café Studio")
        ]

        for (query, name) in cases {
            XCTAssertNotNil(match(query: query, name: name), "Query: \(query)")
        }
    }

    func testNoMatchForEmptyQuery() {
        let result = match(query: " ", name: "Xcode")
        XCTAssertNil(result)
    }

    func testRankingTieBreakers() {
        let ranked = rank(query: "studio", names: ["Studio X", "Studio", "Studio Pro"])
        XCTAssertEqual(ranked.first?.name, "Studio")
    }

    func testAliasOverrides() {
        let store = AliasStore(userAliases: [
            "Super App": ["sa", "superapp"]
        ])

        let index = AppNameIndex(name: "Super App", aliasEntry: store.entry(for: "Super App", bundleID: nil), pinyinProvider: nil)
        let result = Matcher.match(query: "sa", index: index)
        XCTAssertEqual(result?.matchedField, .aliasStrong)
    }

    func testPinyinFullMatch() {
        let index = makeIndex(name: "微信")
        let result = Matcher.match(query: "weixin", index: index)
        XCTAssertNotNil(result)
        XCTAssertTrue(result?.bucket == .prefix || result?.bucket == .acronymOrInitials)
    }

    func testPinyinInitialsMatch() {
        let index = makeIndex(name: "剪映专业版")
        let result = Matcher.match(query: "jyzyb", index: index)
        XCTAssertEqual(result?.bucket, .acronymOrInitials)
    }

    func testAliasStrongBeatsSubstring() {
        let store = AliasStore(userAliases: [
            "Super Long Tool": ["slt"]
        ])
        let strongIndex = AppNameIndex(name: "Super Long Tool", aliasEntry: store.entry(for: "Super Long Tool", bundleID: nil), pinyinProvider: nil)
        let weakIndex = AppNameIndex(name: "Simple Logger Tool", aliasEntry: nil, pinyinProvider: nil)

        let strong = Matcher.match(query: "slt", index: strongIndex)
        let weak = Matcher.match(query: "slt", index: weakIndex)
        XCTAssertTrue((strong?.bucket.rawValue ?? 0) > (weak?.bucket.rawValue ?? 0))
    }

    func testGatingForShortQuery() {
        let index = makeIndex(name: "Visual Studio Code")
        let result = Matcher.match(query: "v", index: index)
        XCTAssertNotNil(result)
        XCTAssertNotEqual(result?.bucket, .fuzzy)
    }
}

private func makeIndex(name: String) -> AppNameIndex {
    AppNameIndex(
        name: name,
        aliasEntry: AliasStore.builtIn.entry(for: name, bundleID: nil),
        pinyinProvider: SystemPinyinProvider()
    )
}

private func match(query: String, name: String) -> MatchResult? {
    Matcher.match(query: query, index: makeIndex(name: name))
}

private func rank(query: String, names: [String]) -> [(name: String, score: Double, debug: String)] {
    let results = names.compactMap { name -> (String, MatchResult)? in
        guard let result = match(query: query, name: name) else { return nil }
        return (name, result)
    }

    return results.sorted {
        if $0.1.bucket.rawValue != $1.1.bucket.rawValue {
            return $0.1.bucket.rawValue > $1.1.bucket.rawValue
        }
        if $0.1.finalScore != $1.1.finalScore {
            return $0.1.finalScore > $1.1.finalScore
        }
        if $0.0.count != $1.0.count {
            return $0.0.count < $1.0.count
        }
        return $0.0.localizedCaseInsensitiveCompare($1.0) == .orderedAscending
    }.map { (name: $0.0, score: $0.1.finalScore, debug: $0.1.debug ?? "") }
}
