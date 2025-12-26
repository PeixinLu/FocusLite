import XCTest
@testable import FocusLite

final class ExpressionParserTests: XCTestCase {
    private let parser = ExpressionParser()

    func testBasicAddition() {
        XCTAssertEqual(parser.evaluate("1+1"), 2)
    }

    func testOperatorPrecedence() {
        XCTAssertEqual(parser.evaluate("2*3+4"), 10)
    }

    func testParentheses() {
        XCTAssertEqual(parser.evaluate("2*(3+4)"), 14)
    }

    func testNestedParentheses() {
        XCTAssertEqual(parser.evaluate("(2+3)*4"), 20)
    }

    func testDivision() {
        XCTAssertEqual(parser.evaluate("10/4"), 2.5)
    }

    func testPercent() {
        XCTAssertEqual(parser.evaluate("50%"), 0.5)
    }

    func testPercentInExpression() {
        XCTAssertEqual(parser.evaluate("200*10%"), 20)
    }

    func testUnaryMinus() {
        XCTAssertEqual(parser.evaluate("-5+2"), -3)
    }

    func testDoubleUnaryMinus() {
        XCTAssertEqual(parser.evaluate("--5"), 5)
    }

    func testUnaryPlus() {
        XCTAssertEqual(parser.evaluate("3++4"), 7)
    }

    func testWhitespaceHandling() {
        XCTAssertEqual(parser.evaluate(" 1 + 2 * 3 "), 7)
    }

    func testLeadingEquals() {
        XCTAssertEqual(parser.evaluate("=1+2"), 3)
    }

    func testDecimalNumbers() {
        XCTAssertEqual(parser.evaluate("2.5*4"), 10)
    }

    func testComplexExpression() {
        XCTAssertEqual(parser.evaluate("1+(2*3)-(4/2)"), 5)
    }

    func testInvalidExpressionReturnsNil() {
        XCTAssertNil(parser.evaluate("1+"))
    }

    func testDivisionByZeroReturnsNil() {
        XCTAssertNil(parser.evaluate("1/0"))
    }

    func testFloatingPointAccuracy() {
        let result = parser.evaluate("0.1+0.2")
        XCTAssertNotNil(result)
        XCTAssertEqual(result ?? 0, 0.3, accuracy: 0.000001)
    }
}
