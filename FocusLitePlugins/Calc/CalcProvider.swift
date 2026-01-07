import Foundation

struct CalcProvider: ResultProvider {
    static let providerID = "calc"
    let id = CalcProvider.providerID
    let displayName = "Calculator"

    private let parser = ExpressionParser()
    private let unitConverter = UnitConverter()

    func results(for query: String, isScoped: Bool) async -> [ResultItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        if let conversion = unitConverter.convertIfPossible(trimmed) {
            return [ResultItem(
                title: conversion.output,
                subtitle: conversion.subtitle,
                icon: .system("function"),
                score: 1.0,
                action: .copyText(conversion.output),
                providerID: id,
                category: .calc
            )]
        }

        guard let value = parser.evaluate(trimmed) else {
            return []
        }

        let formatted = formatNumber(value)
        let subtitle = "= \(normalizedExpression(from: trimmed))"

        return [ResultItem(
            title: formatted,
            subtitle: subtitle,
            icon: .system("function"),
            score: 1.0,
            action: .copyText(formatted),
            providerID: id,
            category: .calc
        )]
    }

    private func normalizedExpression(from input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("=") {
            return String(trimmed.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed
    }

    private func formatNumber(_ value: Double) -> String {
        if value.isNaN || value.isInfinite {
            return "NaN"
        }

        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 6
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false

        if let formatted = formatter.string(from: NSNumber(value: value)) {
            return formatted
        }

        return String(value)
    }
}

private struct UnitConverter {
    private struct UnitInfo {
        let group: String
        let multiplier: Double
        let symbol: String
    }

    private let units: [String: UnitInfo] = [
        "mm": UnitInfo(group: "length", multiplier: 0.001, symbol: "mm"),
        "cm": UnitInfo(group: "length", multiplier: 0.01, symbol: "cm"),
        "m": UnitInfo(group: "length", multiplier: 1.0, symbol: "m"),
        "km": UnitInfo(group: "length", multiplier: 1000.0, symbol: "km"),
        "mg": UnitInfo(group: "weight", multiplier: 0.001, symbol: "mg"),
        "g": UnitInfo(group: "weight", multiplier: 1.0, symbol: "g"),
        "kg": UnitInfo(group: "weight", multiplier: 1000.0, symbol: "kg"),
        "ms": UnitInfo(group: "time", multiplier: 0.001, symbol: "ms"),
        "s": UnitInfo(group: "time", multiplier: 1.0, symbol: "s"),
        "sec": UnitInfo(group: "time", multiplier: 1.0, symbol: "s"),
        "min": UnitInfo(group: "time", multiplier: 60.0, symbol: "min"),
        "h": UnitInfo(group: "time", multiplier: 3600.0, symbol: "h"),
        "hr": UnitInfo(group: "time", multiplier: 3600.0, symbol: "h"),
        "b": UnitInfo(group: "data", multiplier: 1.0, symbol: "B"),
        "kb": UnitInfo(group: "data", multiplier: 1024.0, symbol: "KB"),
        "mb": UnitInfo(group: "data", multiplier: 1024.0 * 1024.0, symbol: "MB"),
        "gb": UnitInfo(group: "data", multiplier: 1024.0 * 1024.0 * 1024.0, symbol: "GB")
    ]

    struct ConversionResult {
        let output: String
        let subtitle: String
    }

    func convertIfPossible(_ input: String) -> ConversionResult? {
        let normalized = input.lowercased()
        let tokens = normalized.split(whereSeparator: { $0.isWhitespace })
        guard tokens.count >= 3 else { return nil }

        let (value, fromUnit, keywordIndex) = parseValueAndUnit(tokens)
        guard let value else { return nil }
        guard let fromUnit, let keywordIndex else { return nil }
        guard keywordIndex + 1 < tokens.count else { return nil }

        let keyword = tokens[keywordIndex]
        guard keyword == "to" || keyword == "in" else { return nil }

        let toUnitKey = String(tokens[keywordIndex + 1])
        guard let fromInfo = units[fromUnit], let toInfo = units[toUnitKey] else { return nil }
        guard fromInfo.group == toInfo.group else { return nil }

        let baseValue = value * fromInfo.multiplier
        let converted = baseValue / toInfo.multiplier

        let output = formatNumber(converted) + " " + toInfo.symbol
        let subtitle = formatNumber(value) + " " + fromInfo.symbol + " = " + output
        return ConversionResult(output: output, subtitle: subtitle)
    }

    private func parseValueAndUnit(_ tokens: [Substring]) -> (Double?, String?, Int?) {
        let firstToken = tokens[0]
        if let parsed = parseNumberAndUnit(String(firstToken)) {
            return (parsed.value, parsed.unit, 1)
        }

        guard tokens.count >= 2 else { return (nil, nil, nil) }
        let value = Double(String(firstToken))
        let unit = String(tokens[1])
        return (value, unit, 2)
    }

    private func parseNumberAndUnit(_ token: String) -> (value: Double, unit: String)? {
        var numberPart = ""
        var unitPart = ""
        var hasDot = false

        for char in token {
            if char.isNumber {
                numberPart.append(char)
                continue
            }
            if char == "." && !hasDot {
                hasDot = true
                numberPart.append(char)
                continue
            }
            unitPart.append(char)
        }

        guard !numberPart.isEmpty, !unitPart.isEmpty, let value = Double(numberPart) else {
            return nil
        }

        return (value, unitPart)
    }

    private func formatNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 6
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false

        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}
