import Foundation

struct ExpressionParser {
    func evaluate(_ input: String) -> Double? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        let sanitized = trimmed.hasPrefix("=") ? String(trimmed.dropFirst()) : trimmed
        let lexer = Lexer(input: sanitized)
        var parser = Parser(lexer: lexer)
        guard let value = parser.parseExpression(), parser.isAtEnd else {
            return nil
        }
        return value
    }
}

private struct Lexer {
    private let characters: [Character]
    private var index: Int = 0

    init(input: String) {
        self.characters = Array(input)
    }

    mutating func nextToken() -> Token {
        skipWhitespace()
        guard index < characters.count else {
            return .eof
        }

        let current = characters[index]
        index += 1

        switch current {
        case "+": return .plus
        case "-": return .minus
        case "*": return .multiply
        case "/": return .divide
        case "%": return .percent
        case "(": return .lparen
        case ")": return .rparen
        case ".", "0"..."9":
            return numberToken(startingWith: current)
        default:
            return .invalid
        }
    }

    private mutating func skipWhitespace() {
        while index < characters.count, characters[index].isWhitespace {
            index += 1
        }
    }

    private mutating func numberToken(startingWith first: Character) -> Token {
        var buffer = String(first)
        var hasDot = (first == ".")

        while index < characters.count {
            let next = characters[index]
            if next == "." {
                if hasDot { break }
                hasDot = true
                buffer.append(next)
                index += 1
                continue
            }

            if next.isNumber {
                buffer.append(next)
                index += 1
                continue
            }

            break
        }

        return .number(Double(buffer))
    }
}

private enum Token: Equatable {
    case number(Double?)
    case plus
    case minus
    case multiply
    case divide
    case percent
    case lparen
    case rparen
    case invalid
    case eof
}

private struct Parser {
    private var lexer: Lexer
    private var lookahead: Token

    init(lexer: Lexer) {
        var lexer = lexer
        self.lookahead = lexer.nextToken()
        self.lexer = lexer
    }

    mutating func parseExpression() -> Double? {
        guard let value = parseTerm() else { return nil }
        var result = value

        while true {
            switch lookahead {
            case .plus:
                advance()
                guard let rhs = parseTerm() else { return nil }
                result += rhs
            case .minus:
                advance()
                guard let rhs = parseTerm() else { return nil }
                result -= rhs
            default:
                return result
            }
        }
    }

    private mutating func parseTerm() -> Double? {
        guard let value = parseFactor() else { return nil }
        var result = value

        while true {
            switch lookahead {
            case .multiply:
                advance()
                guard let rhs = parseFactor() else { return nil }
                result *= rhs
            case .divide:
                advance()
                guard let rhs = parseFactor(), rhs != 0 else { return nil }
                result /= rhs
            default:
                return result
            }
        }
    }

    private mutating func parseFactor() -> Double? {
        guard var value = parseUnary() else { return nil }

        while lookahead == .percent {
            advance()
            value /= 100
        }

        return value
    }

    private mutating func parseUnary() -> Double? {
        switch lookahead {
        case .plus:
            advance()
            return parseUnary()
        case .minus:
            advance()
            guard let value = parseUnary() else { return nil }
            return -value
        default:
            return parsePrimary()
        }
    }

    private mutating func parsePrimary() -> Double? {
        switch lookahead {
        case .number(let value):
            advance()
            return value
        case .lparen:
            advance()
            guard let value = parseExpression(), lookahead == .rparen else { return nil }
            advance()
            return value
        default:
            return nil
        }
    }

    private mutating func advance() {
        lookahead = lexer.nextToken()
    }

    var isAtEnd: Bool {
        lookahead == .eof
    }
}
