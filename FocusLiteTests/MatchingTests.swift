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
            ("音乐", ["QQ音乐", "网易云音乐"], "QQ音乐"),
            ("wx weixin", ["微信"], "微信")
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
            ("adp", "Adobe Photoshop"),
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
        XCTAssertGreaterThan(full?.score ?? 0, single?.score ?? 0)
    }

    func testAcronymAndPinyinTypes() {
        let weixin = makeIndex(name: "微信")
        let result = Matcher.match(query: "wx", index: weixin)
        XCTAssertTrue(result?.debug.types.contains(.pinyinInitials) == true)

        let photoshop = makeIndex(name: "Adobe Photoshop")
        let ps = Matcher.match(query: "ps", index: photoshop)
        XCTAssertTrue(ps?.debug.types.contains(.acronym) == true)
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

        let index = AppNameIndex(name: "Super App", aliasEntry: store.entry(for: "Super App"), pinyinProvider: nil)
        let result = Matcher.match(query: "sa", index: index)
        XCTAssertTrue(result?.debug.types.contains(.alias) == true)
    }
}

private func makeIndex(name: String) -> AppNameIndex {
    AppNameIndex(
        name: name,
        aliasEntry: AliasStore.builtIn.entry(for: name),
        pinyinProvider: SystemPinyinProvider()
    )
}

private func match(query: String, name: String) -> MatchResult? {
    Matcher.match(query: query, index: makeIndex(name: name))
}

private func rank(query: String, names: [String]) -> [(name: String, score: Double, debug: MatchDebug)] {
    let results = names.compactMap { name -> (String, MatchResult)? in
        guard let result = match(query: query, name: name) else { return nil }
        return (name, result)
    }

    return results.sorted {
        if $0.1.score != $1.1.score {
            return $0.1.score > $1.1.score
        }
        if $0.0.count != $1.0.count {
            return $0.0.count < $1.0.count
        }
        return $0.0.localizedCaseInsensitiveCompare($1.0) == .orderedAscending
    }.map { (name: $0.0, score: $0.1.score, debug: $0.1.debug) }
}
