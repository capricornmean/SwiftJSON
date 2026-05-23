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
    case invalidEscape(UInt8)
    case invalidUnicode
}

public struct JSONParser {
    private enum Constants {
        static let nullString = Array("null".utf8)
        static let trueString = Array("true".utf8)
        static let falseString = Array("false".utf8)
    }

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
        guard let c = peek() else {
            throw JSONError.unexpectedEnd
        }
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
        try expect(Constants.nullString)
        return .null
    }

    private mutating func parseBool() throws -> JSONValue {
        if peek() == UInt8(ascii: "t") { 
            try expect(Constants.trueString)
            return .bool(true)
        }
        try expect(Constants.falseString)
        return .bool(false)
    }

    private mutating func parseNumber() throws -> JSONValue {
        let startIndex = index
        if peek() == UInt8(ascii: "-") { advance() }
        while let c = peek(), (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(c) { advance() }
        if index < source.count, peek() == UInt8(ascii: ".") {
            advance()
            while let c = peek(), (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(c) { advance() }
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
        while peek() != UInt8(ascii: "]") {
            let value = try parseValue()
            array.append(value)
            skipWhitespaceIfNeeded()
            if peek() == UInt8(ascii: ",") {
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
        while peek() != UInt8(ascii: "}") {
            skipWhitespaceIfNeeded()
            let key = try getString()
            skipWhitespaceIfNeeded()
            try consume(UInt8(ascii: ":"))
            let value = try parseValue()
            dict[key] = value
            skipWhitespaceIfNeeded()
            if peek() == UInt8(ascii: ",") {
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
        for i in 0..<literal.count {
            if source[index + i] != literal[i] {
                throw JSONError.unexpectedCharacter(Character(UnicodeScalar(source[index + i])))
            }
        }
        index += literal.count
    }

    private mutating func getString() throws -> String {
        try consume(UInt8(ascii: "\""))
        let startIndex = index

        while index < source.count {
            let c = source[index]
            if c == UInt8(ascii: "\"") {
                let value = String(decoding: source[startIndex..<index], as: UTF8.self)
                advance()
                return value
            }
            if c == UInt8(ascii: "\\") {
                return try getStringWithEscapes(from: startIndex)
            }
            advance()
        }
        throw JSONError.unexpectedEnd
    }

    private mutating func getStringWithEscapes(from startIndex: Int) throws -> String {
        var bytes = Array(source[startIndex..<index])

        while index < source.count {
            let c = source[index]
            switch c {
            case UInt8(ascii: "\""):
                advance()
                return String(decoding: bytes, as: UTF8.self)

            case UInt8(ascii: "\\"):
                advance()                              // consume backslash
                guard let esc = peek() else { throw JSONError.unexpectedEnd }
                switch esc {
                case UInt8(ascii: "\""): bytes.append(UInt8(ascii: "\"")); advance()
                case UInt8(ascii: "\\"): bytes.append(UInt8(ascii: "\\")); advance()
                case UInt8(ascii: "/"):  bytes.append(UInt8(ascii: "/"));  advance()
                case UInt8(ascii: "b"):  bytes.append(0x08); advance()
                case UInt8(ascii: "f"):  bytes.append(0x0C); advance()
                case UInt8(ascii: "n"):  bytes.append(0x0A); advance()
                case UInt8(ascii: "r"):  bytes.append(0x0D); advance()
                case UInt8(ascii: "t"):  bytes.append(0x09); advance()
                case UInt8(ascii: "u"):  advance(); try appendUnicodeEscape(to: &bytes)
                default: throw JSONError.invalidEscape(esc)
                }

            default:
                bytes.append(c)
                advance()
            }
        }
        throw JSONError.unexpectedEnd
    }

    private mutating func appendUnicodeEscape(to bytes: inout [UInt8]) throws {
        let unit = try readHex4()
        let codePoint: UInt32

        switch unit {
        case 0xD800...0xDBFF:                       // high surrogate, expect a low surrogate next
            guard index + 1 < source.count,
                source[index]     == UInt8(ascii: "\\"),
                source[index + 1] == UInt8(ascii: "u") else {
                throw JSONError.invalidUnicode
            }
            advance(); advance()                    // consume "\u"
            let low = try readHex4()
            guard (0xDC00...0xDFFF).contains(low) else { throw JSONError.invalidUnicode }
            codePoint = 0x10000
                    + (UInt32(unit - 0xD800) << 10)
                    + UInt32(low - 0xDC00)

        case 0xDC00...0xDFFF:                        // lone low surrogate is invalid
            throw JSONError.invalidUnicode

        default:
            codePoint = UInt32(unit)
        }

        guard let scalar = Unicode.Scalar(codePoint) else { throw JSONError.invalidUnicode }
        UTF8.encode(scalar) { bytes.append($0) }     // encode to UTF-8 without allocating a String
    }

    private mutating func readHex4() throws -> UInt16 {
        guard index + 4 <= source.count else { throw JSONError.unexpectedEnd }
        var value: UInt16 = 0
        for _ in 0..<4 {
            value = (value << 4) | UInt16(try hexDigit(source[index]))
            advance()
        }
        return value
    }

    private func hexDigit(_ byte: UInt8) throws -> UInt8 {
        switch byte {
        case UInt8(ascii: "0")...UInt8(ascii: "9"): return byte - UInt8(ascii: "0")
        case UInt8(ascii: "a")...UInt8(ascii: "f"): return byte - UInt8(ascii: "a") + 10
        case UInt8(ascii: "A")...UInt8(ascii: "F"): return byte - UInt8(ascii: "A") + 10
        default: throw JSONError.invalidUnicode
        }
    }

    private mutating func advance() {
        index += 1
    }

    private func peek() -> UInt8? {
        guard index < source.count else { return nil }
        return source[index]
    }

    private mutating func consume(_ expected: UInt8) throws {
        guard peek() == expected else { throw JSONError.unexpectedCharacter(Character(UnicodeScalar(source[index]))) }
        advance()
    }
}