public enum JSONValue: Equatable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String : JSONValue])
}

enum JSONError: Error {
    case unexpectedCharacter(Character)
    case unexpectedEnd
    case invalidNumber(String)
}

public struct JSONParser {
    private let source: String
    private var index: String.Index

    public init(_ source: String) {
        self.source = source
        self.index = source.startIndex
    }

    public mutating func parse() throws -> JSONValue {
        return try parseValue()
    }

    private mutating func parseValue() throws -> JSONValue {
        skipWhitespaceIfNeeded()
        switch source[index] {
        case "n" : return try parseNull()
        case "t", "f" : return try parseBool()
        case "-", "0"..."9":  return try parseNumber()
        case "\"": return try parseString()
        case "[": return try parseArray()
        case "{": return try parseObject()
        default: throw JSONError.unexpectedCharacter(source[index])
        }
    }

    private mutating func parseNull() throws -> JSONValue {
        return try parseLiteral("null")
    }

    private mutating func parseBool() throws -> JSONValue {
        if source[index] == "t" { return try parseLiteral("true") }
        return try parseLiteral("false")
    }

    private mutating func parseNumber() throws -> JSONValue {
        let startIndex = index
        if (try? peek()) == "-" { advance() }
        while index < source.endIndex, try "0"..."9" ~= peek() { advance() }
        if index < source.endIndex, (try? peek()) == "." {
            advance()
            while index < source.endIndex, try "0"..."9" ~= peek() { advance() }
        }
        let substring = String(source[startIndex..<index])
        guard let value = Double(substring) else {
            throw JSONError.invalidNumber(substring)
        }
        return .number(value)
    }

    private mutating func parseString() throws -> JSONValue {
        let value = try getString()
        return .string(value)
    }

    private mutating func parseArray() throws -> JSONValue {
        try consume("[")
        skipWhitespaceIfNeeded()
        var array: [JSONValue] = []
        while try peek() != "]" {
            let value = try parseValue()
            array.append(value)
            skipWhitespaceIfNeeded()
            if (try? peek()) == "," {
                advance()
                skipWhitespaceIfNeeded()
            }
        }
        try consume("]")
        return .array(array)
    }

    private mutating func parseObject() throws -> JSONValue {
        try consume("{")
        var dict: [String: JSONValue] = [:]
        while try peek() != "}" {
            skipWhitespaceIfNeeded()
            let key = try getString()
            skipWhitespaceIfNeeded()
            try consume(":")
            let value = try parseValue()
            dict[key] = value
            skipWhitespaceIfNeeded()
            if (try? peek()) == "," {
                advance()
                skipWhitespaceIfNeeded()
            }
        }
        try consume("}")
        return .object(dict)
    }

    private mutating func skipWhitespaceIfNeeded() {
        while index != source.endIndex, 
        source[index].isWhitespace || source[index].isNewline { index = source.index(after: index) }
    }

    // MARK: Helper
    private mutating func parseLiteral(_ expectedString: String) throws -> JSONValue {
        guard let endIndex = source.index(index, offsetBy: expectedString.count, limitedBy: source.endIndex) else {
            throw JSONError.unexpectedEnd
        }
        if source[index..<endIndex] == expectedString {
            index = endIndex
            switch expectedString {
                case "null": return .null
                case "true": return .bool(true)
                case "false": return .bool(false)
                default: throw JSONError.unexpectedCharacter(source[index])
            }
        }
        throw JSONError.unexpectedCharacter(source[index])
    }

    private mutating func getString() throws -> String {
        try consume("\"")
        let startIndex = index
        while try peek() != "\"" { advance() }
        let value = String(source[startIndex..<index])
        try consume("\"")
        return value
    }

    private mutating func advance() {
        index = source.index(after: index)
    }

    private func peek() throws -> Character {
        guard index < source.endIndex else { throw JSONError.unexpectedEnd }
        return source[index]
    }

    private mutating func consume(_ expected: Character) throws {
        guard try peek() == expected else { throw JSONError.unexpectedCharacter(source[index]) }
        advance()
    }
}