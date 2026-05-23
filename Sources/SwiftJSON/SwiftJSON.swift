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
    private let source: [UInt8]
    private var index: Int

    public init(_ source: String) {
        self.source = Array(source.utf8)
        self.index = 0
    }

    public mutating func parse() throws -> JSONValue {
        let value = try parseValue()
        skipWhitespaceIfNeeded()
        if index != source.count {
            throw JSONError.unexpectedCharacter(Character(UnicodeScalar(source[index])))
        }
        return value
    }

    private mutating func parseValue() throws -> JSONValue {
        skipWhitespaceIfNeeded()
        let c = try peek()
        switch c {
        case UInt8(ascii: "n") : return try parseNull()
        case UInt8(ascii: "t"), UInt8(ascii: "f") : return try parseBool()
        case UInt8(ascii: "-"), UInt8(ascii: "0")...UInt8(ascii: "9"):  return try parseNumber()
        case UInt8(ascii: "\""): return try parseString()
        case UInt8(ascii: "["): return try parseArray()
        case UInt8(ascii: "{"): return try parseObject()
        default: throw JSONError.unexpectedCharacter(Character(UnicodeScalar(source[index])))
        }
    }

    private mutating func parseNull() throws -> JSONValue {
        try expect(Array("null".utf8))
        return .null
    }

    private mutating func parseBool() throws -> JSONValue {
        if try peek() == UInt8(ascii: "t") { 
            try expect(Array("true".utf8))
            return .bool(true)
        }
        try expect(Array("false".utf8))
        return .bool(false)
    }

    private mutating func parseNumber() throws -> JSONValue {
        let startIndex = index
        if (try? peek()) == UInt8(ascii: "-") { advance() }
        while index < source.count, try UInt8(ascii: "0")...UInt8(ascii: "9") ~= peek() { advance() }
        if index < source.count, (try? peek()) == UInt8(ascii: ".") {
            advance()
            while index < source.count, try UInt8(ascii: "0")...UInt8(ascii: "9") ~= peek() { advance() }
        }
        let substring = String(decoding: source[startIndex..<index], as: UTF8.self)
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
        try consume(UInt8(ascii: "["))
        skipWhitespaceIfNeeded()
        var array: [JSONValue] = []
        while try peek() != UInt8(ascii: "]") {
            let value = try parseValue()
            array.append(value)
            skipWhitespaceIfNeeded()
            if (try? peek()) == UInt8(ascii: ",") {
                advance()
                skipWhitespaceIfNeeded()
            }
        }
        try consume(UInt8(ascii: "]"))
        return .array(array)
    }

    private mutating func parseObject() throws -> JSONValue {
        try consume(UInt8(ascii: "{"))
        var dict: [String: JSONValue] = [:]
        while try peek() != UInt8(ascii: "}") {
            skipWhitespaceIfNeeded()
            let key = try getString()
            skipWhitespaceIfNeeded()
            try consume(UInt8(ascii: ":"))
            let value = try parseValue()
            dict[key] = value
            skipWhitespaceIfNeeded()
            if (try? peek()) == UInt8(ascii: ",") {
                advance()
                skipWhitespaceIfNeeded()
            }
        }
        try consume(UInt8(ascii: "}"))
        return .object(dict)
    }

    private mutating func skipWhitespaceIfNeeded() {
        while index < source.count {
            let c = source[index]
            if c == UInt8(ascii: " ") || c == UInt8(ascii: "\t") || c == UInt8(ascii: "\n") || c == UInt8(ascii: "\r") {
                index += 1
            } else {
                break
            }
        }
    }

    // MARK: Helper
    private mutating func expect(_ literal: [UInt8]) throws {
        guard index + literal.count <= source.count else {
            throw JSONError.unexpectedEnd
        }
        for i in 0..<literal.count{
            if source[index + i] != literal[i] {
                throw JSONError.unexpectedCharacter(Character(UnicodeScalar(source[index + i])))
            }
        }
        index += literal.count
    }

    private mutating func getString() throws -> String {
        try consume(UInt8(ascii: "\""))
        let startIndex = index
        while try peek() != UInt8(ascii: "\"") { advance() }
        let value = String(decoding: source[startIndex..<index], as: UTF8.self)
        try consume(UInt8(ascii: "\""))
        return value
    }

    private mutating func advance() {
        index += 1
    }

    private func peek() throws -> UInt8 {
        guard index < source.count else { throw JSONError.unexpectedEnd }
        return source[index]
    }

    private mutating func consume(_ expected: UInt8) throws {
        guard try peek() == expected else { throw JSONError.unexpectedCharacter(Character(UnicodeScalar(source[index]))) }
        advance()
    }
}