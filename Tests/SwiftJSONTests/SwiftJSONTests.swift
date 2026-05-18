import Testing
@testable import SwiftJSON

@Test func example() async throws {
    let test1 = "null"
    let test2 = "true"
    let test3 = "42"
    let test4 = "[1, 2, 3]"
    let test5 = "{\"a\": 1}"
    let fullJSON = """
    {
        "1": null,
        "2": true,
        "3": 42,
        "4": [1, 2, 3],
        "5": {
            "a": 1,
            "b": 2
        }
    }
    """
    let value1 = JSONValue.null
    let value2 = JSONValue.bool(true)
    let value3 = JSONValue.number(42)
    let value4 = JSONValue.array([.number(1), .number(2), .number(3)])
    let value5 = JSONValue.object(["a" : .number(1)])
    let fullValue = JSONValue.object(["1": .null, 
                                             "2": .bool(true),
                                             "3": .number(42),
                                             "4": .array([.number(1), .number(2), .number(3)]),
                                             "5": .object(["a" : .number(1), "b": .number(2)])])
    var parser = JSONParser(test1)
    #expect(try parser.parse() == value1)
    parser = JSONParser(test2)
    #expect(try parser.parse() == value2)
    parser = JSONParser(test3)
    #expect(try parser.parse() == value3)
    parser = JSONParser(test4)
    #expect(try parser.parse() == value4)
    parser = JSONParser(test5)
    #expect(try parser.parse() == value5)
    parser = JSONParser(fullJSON)
    #expect(try parser.parse() == fullValue)
}
