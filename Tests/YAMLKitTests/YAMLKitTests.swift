// YAMLKitTests
//
// SPDX-License-Identifier: Apache-2.0
//
// Copyright (c) 2026 YAMLKit contributors

import Testing
@testable import YAMLKit

struct YAMLParserScalarTests {
    @Test func parsesNull() throws {
        let parser = YAMLParser()
        let value = try parser.parse("null")
        #expect(value == .null)
    }

    @Test func parsesNullWithTrailingCommentDelimiter() throws {
        let parser = YAMLParser()
        let value = try parser.parse("null#comment")
        #expect(value == .null)
    }

    @Test func doesNotTreatNullPrefixAsNull() throws {
        let parser = YAMLParser()
        let value = try parser.parse("nulla")
        #expect(value == .string("nulla"))
    }

    @Test func parsesBooleanTrue() throws {
        let parser = YAMLParser()
        let value = try parser.parse("true")
        #expect(value == .bool(true))
    }

    @Test func parsesBooleanFalse() throws {
        let parser = YAMLParser()
        let value = try parser.parse("false")
        #expect(value == .bool(false))
    }

    @Test func doesNotTreatTruePrefixAsBool() throws {
        let parser = YAMLParser()
        let value = try parser.parse("trueish")
        #expect(value == .string("trueish"))
    }

    @Test func doesNotTreatFalsePrefixAsBool() throws {
        let parser = YAMLParser()
        let value = try parser.parse("falsey")
        #expect(value == .string("falsey"))
    }

    @Test func parsesInteger() throws {
        let parser = YAMLParser()
        let value = try parser.parse("42")
        #expect(value == .int(42))
    }

    @Test func parsesZero() throws {
        let parser = YAMLParser()
        let value = try parser.parse("0")
        #expect(value == .int(0))
    }

    @Test func parsesNegativeZeroAsInt() throws {
        let parser = YAMLParser()
        let value = try parser.parse("-0")
        #expect(value == .int(0))
    }

    @Test func parsesNegativeInteger() throws {
        let parser = YAMLParser()
        let value = try parser.parse("-7")
        #expect(value == .int(-7))
    }

    @Test func parsesBareDashAsString() throws {
        let parser = YAMLParser()
        let value = try parser.parse("-")
        #expect(value == .array([.null]))
    }

    @Test func parsesDouble() throws {
        let parser = YAMLParser()
        let value = try parser.parse("3.14")
        #expect(value == .double(3.14))
    }

    @Test func parsesNegativeDouble() throws {
        let parser = YAMLParser()
        let value = try parser.parse("-2.5")
        #expect(value == .double(-2.5))
    }

    @Test func parsesIntegerWithTrailingComment() throws {
        let parser = YAMLParser()
        let value = try parser.parse("123 # comment")
        #expect(value == .int(123))
    }

    @Test func parsesDoubleWithTrailingWhitespace() throws {
        let parser = YAMLParser()
        let value = try parser.parse("9.5   \n")
        #expect(value == .double(9.5))
    }

    @Test func parsesQuotedString() throws {
        let parser = YAMLParser()
        let value = try parser.parse("\"hello\"")
        #expect(value == .styledString("hello", .doubleQuoted))
    }

    @Test func parsesSingleQuotedString() throws {
        let parser = YAMLParser()
        let value = try parser.parse("'world'")
        #expect(value == .styledString("world", .singleQuoted))
    }

    @Test func parsesDoubleQuotedEscapes() throws {
        let parser = YAMLParser()
        let value = try parser.parse("\"line\\n\\tindent\\\\\"")
        #expect(value == .styledString("line\n\tindent\\", .doubleQuoted))
    }

    @Test func parsesQuotedStringWithHash() throws {
        let parser = YAMLParser()
        let value = try parser.parse("\"hash#inside\"")
        #expect(value == .styledString("hash#inside", .doubleQuoted))
    }

    @Test func parsesSingleQuotedWithHash() throws {
        let parser = YAMLParser()
        let value = try parser.parse("'hash#inside'")
        #expect(value == .styledString("hash#inside", .singleQuoted))
    }

    @Test func parsesBareString() throws {
        let parser = YAMLParser()
        let value = try parser.parse("alpha")
        #expect(value == .string("alpha"))
    }

    @Test func parsesBareStringUntilComment() throws {
        let parser = YAMLParser()
        let value = try parser.parse("alpha#beta")
        #expect(value == .string("alpha"))
    }

    @Test func parsesBareStringStopsAtWhitespace() throws {
        let parser = YAMLParser()
        #expect(throws: YAMLParseError.trailingCharacters) {
            try parser.parse("alpha beta")
        }
    }

    @Test func parsesBareStringStopsAtComma() throws {
        let parser = YAMLParser()
        #expect(throws: YAMLParseError.trailingCharacters) {
            try parser.parse("alpha, beta")
        }
    }

    @Test func parsesBareStringStopsAtClosingBrace() throws {
        let parser = YAMLParser()
        #expect(throws: YAMLParseError.trailingCharacters) {
            try parser.parse("alpha}")
        }
    }

    @Test func ignoresWhitespaceAndComments() throws {
        let parser = YAMLParser()
        let value = try parser.parse("  true  # trailing\n")
        #expect(value == .bool(true))
    }
}
struct YAMLParserErrorTests {
    @Test func emptyDocumentThrows() {
        let parser = YAMLParser()
        #expect(throws: YAMLParseError.emptyDocument) {
            try parser.parse("\n\t  ")
        }
    }

    @Test func trailingCharactersThrows() {
        let parser = YAMLParser()
        #expect(throws: YAMLParseError.trailingCharacters) {
            try parser.parse("true false")
        }
    }

    @Test func trailingCommaThrows() {
        let parser = YAMLParser()
        #expect(throws: YAMLParseError.trailingCharacters) {
            try parser.parse("null,")
        }
    }

    @Test func flowSequenceTrailingCommaThrows() {
        let parser = YAMLParser()
        #expect(throws: YAMLParseError.expectedFlowSequenceEnd) {
            try parser.parse("[1,]")
        }
    }

    @Test func flowMappingTrailingCommaThrows() {
        let parser = YAMLParser()
        #expect(throws: YAMLParseError.expectedFlowMappingEnd) {
            try parser.parse("{a: 1,}")
        }
    }

    @Test func flowMappingMissingColonThrows() {
        let parser = YAMLParser()
        #expect(throws: YAMLParseError.expectedMappingSeparator) {
            try parser.parse("{a 1}")
        }
    }

    @Test func flowMappingNonStringKeyThrows() {
        let parser = YAMLParser()
        #expect(throws: YAMLParseError.nonStringKey) {
            try parser.parse("{1: a}")
        }
    }

    @Test func invalidScalarThrows() {
        let parser = YAMLParser()
        #expect(throws: YAMLParseError.invalidScalar) {
            try parser.parse("\"unterminated")
        }
    }

    @Test func invalidNumberThrows() throws {
        let parser = YAMLParser()
        let value = try parser.parse("1.")
        #expect(value == .string("1."))
    }

    @Test func incompleteDoubleQuotedEscapeThrows() {
        let parser = YAMLParser()
        #expect(throws: YAMLParseError.invalidScalar) {
            try parser.parse("\"bad\\")
        }
    }

    @Test func unsupportedEscapeThrows() {
        let parser = YAMLParser()
        #expect(throws: YAMLParseError.invalidScalar) {
            try parser.parse("\"bad\\r\"")
        }
    }

    @Test func invalidBareStringThrows() {
        let parser = YAMLParser()
        #expect(throws: YAMLParseError.emptyDocument) {
            try parser.parse("# just a comment")
        }
    }
}

struct YAMLParserFlowCollectionTests {
    @Test func parsesEmptyFlowSequence() throws {
        let parser = YAMLParser()
        let value = try parser.parse("[]")
        #expect(value == .array([]))
    }

    @Test func parsesFlowSequence() throws {
        let parser = YAMLParser()
        let value = try parser.parse("[1, 2, 3]")
        #expect(value == .array([.int(1), .int(2), .int(3)]))
    }

    @Test func parsesNestedFlowSequence() throws {
        let parser = YAMLParser()
        let value = try parser.parse("[true, [false, null]]")
        #expect(value == .array([.bool(true), .array([.bool(false), .null])]))
    }

    @Test func parsesEmptyFlowMapping() throws {
        let parser = YAMLParser()
        let value = try parser.parse("{}")
        #expect(value == .object([:]))
    }

    @Test func parsesFlowMapping() throws {
        let parser = YAMLParser()
        let value = try parser.parse("{a: 1, b: true}")
        #expect(value == .object(["a": .int(1), "b": .bool(true)]))
    }

    @Test func parsesNestedFlowMapping() throws {
        let parser = YAMLParser()
        let value = try parser.parse("{a: [1, 2], b: {c: null}}")
        #expect(value == .object(["a": .array([.int(1), .int(2)]), "b": .object(["c": .null])]))
    }

    @Test func parsesFlowMappingWithQuotedKeys() throws {
        let parser = YAMLParser()
        let value = try parser.parse("{\"a-b\": 1}")
        #expect(value == .object(["a-b": .int(1)]))
    }

    @Test func parsesFlowSequenceWithComments() throws {
        let parser = YAMLParser()
        let value = try parser.parse("[1, # first\n 2]")
        #expect(value == .array([.int(1), .int(2)]))
    }
}

struct YAMLParserBlockCollectionTests {
    @Test func parsesBlockSequence() throws {
        let parser = YAMLParser()
        let value = try parser.parse("- a\n- b\n- c\n")
        #expect(value == .array([.string("a"), .string("b"), .string("c")]))
    }

    @Test func parsesBlockMapping() throws {
        let parser = YAMLParser()
        let value = try parser.parse("a: 1\nb: true\nc: null\n")
        #expect(value == .object(["a": .int(1), "b": .bool(true), "c": .null]))
    }

    @Test func parsesBlockSequenceWithNestedBlockMapping() throws {
        let parser = YAMLParser()
        let value = try parser.parse("- a: 1\n  b: 2\n- c: 3\n")
        #expect(value == .array([.object(["a": .int(1), "b": .int(2)]), .object(["c": .int(3)])]))
    }

    @Test func parsesBlockMappingWithNestedSequence() throws {
        let parser = YAMLParser()
        let value = try parser.parse("a:\n  - 1\n  - 2\n")
        #expect(value == .object(["a": .array([.int(1), .int(2)])]))
    }

    @Test func parsesNestedBlockMapping() throws {
        let parser = YAMLParser()
        let value = try parser.parse("a:\n  b:\n    c: 3\n")
        #expect(value == .object(["a": .object(["b": .object(["c": .int(3)])])]))
    }

    @Test func parsesBlockMappingWithFlowValue() throws {
        let parser = YAMLParser()
        let value = try parser.parse("a: [1, 2]\n")
        #expect(value == .object(["a": .array([.int(1), .int(2)])]))
    }

    @Test func parsesBlockSequenceWithFlowValue() throws {
        let parser = YAMLParser()
        let value = try parser.parse("- {a: 1}\n- [2, 3]\n")
        #expect(value == .array([.object(["a": .int(1)]), .array([.int(2), .int(3)])]))
    }

    @Test func parsesBlockMappingWithNullValue() throws {
        let parser = YAMLParser()
        let value = try parser.parse("a:\n")
        #expect(value == .object(["a": .null]))
    }
}
struct YAMLParserBlockScalarTests {
    @Test func parsesLiteralBlockScalarInMapping() throws {
        let parser = YAMLParser()
        let value = try parser.parse("a: |\n  line1\n  line2\n")
        #expect(value == .object(["a": .styledString("line1\nline2\n", .literalBlock)]))
    }

    @Test func parsesFoldedBlockScalarInMapping() throws {
        let parser = YAMLParser()
        let value = try parser.parse("a: >\n  line1\n  line2\n")
        #expect(value == .object(["a": .styledString("line1\nline2\n", .foldedBlock)]))
    }

    @Test func parsesLiteralBlockScalarInSequence() throws {
        let parser = YAMLParser()
        let value = try parser.parse("- |\n  hello\n")
        #expect(value == .array([.styledString("hello\n", .literalBlock)]))
    }

    @Test func parsesFoldedBlockScalarWithBlankLines() throws {
        let parser = YAMLParser()
        let value = try parser.parse("a: >\n  hello\n\n  world\n")
        #expect(value == .object(["a": .styledString("hello\n\nworld\n", .foldedBlock)]))
    }
}

struct YAMLCodableTests {
    struct Person: Codable, Equatable {
        let name: String
        let age: Int
        let isAdmin: Bool
    }
    struct Container: Codable, Equatable {
        let people: [Person]
        let tags: [String]
    }

    @Test func decodesFromYAMLValue() throws {
        let value: YAMLValue = .object([
            "name": .string("Ava"),
            "age": .int(32),
            "isAdmin": .bool(true)
        ])
        let decoder = YAMLDecoder()
        let person = try decoder.decode(Person.self, from: value)
        #expect(person == Person(name: "Ava", age: 32, isAdmin: true))
    }

    @Test func decodesFromString() throws {
        let decoder = YAMLDecoder()
        let input = """
        name: Ava
        age: 32
        isAdmin: true
        """
        let person = try decoder.decode(Person.self, from: input)
        #expect(person == Person(name: "Ava", age: 32, isAdmin: true))
    }

    @Test func encodesToYAMLValue() throws {
        let encoder = YAMLEncoder()
        let person = Person(name: "Ben", age: 28, isAdmin: false)
        let value = try encoder.encode(person)
        #expect(value == .object([
            "name": .string("Ben"),
            "age": .int(28),
            "isAdmin": .bool(false)
        ]))
    }

    @Test func encodesToString() throws {
        let encoder = YAMLEncoder()
        let person = Person(name: "Ben", age: 28, isAdmin: false)
        let yaml = try encoder.encodeToString(person)
        #expect(yaml.contains("name: Ben"))
        #expect(yaml.contains("age: 28"))
        #expect(yaml.contains("isAdmin: false"))
    }

    @Test func roundTripNestedCodable() throws {
        let encoder = YAMLEncoder()
        let decoder = YAMLDecoder()
        let input = Container(
            people: [
                Person(name: "Ivy", age: 25, isAdmin: false),
                Person(name: "Max", age: 41, isAdmin: true)
            ],
            tags: ["swift", "yaml"]
        )
        let encoded = try encoder.encode(input)
        let decoded = try decoder.decode(Container.self, from: encoded)
        #expect(decoded == input)
    }
}

struct YAMLSerializationTests {
    @Test func serializesFlowScalars() {
        let serializer = YAMLSerializer()
        let value: YAMLValue = .object(["a": .int(1), "b": .bool(false)])
        let output = serializer.serialize(value).trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(output.contains("a: 1"))
        #expect(output.contains("b: false"))
    }

    @Test func serializesBlockSequence() {
        let serializer = YAMLSerializer()
        let value: YAMLValue = .array([.int(1), .array([.int(2), .int(3)])])
        let result = serializer.serialize(value)
        #expect(result.contains("- 1"))
        #expect(result.contains("- 2"))
        #expect(result.contains("- 3"))
    }

    @Test func serializesLiteralString() {
        let serializer = YAMLSerializer()
        let value: YAMLValue = .styledString("line1\nline2\n", .literalBlock)
        let result = serializer.serialize(value)
        #expect(result.contains("|\n"))
        #expect(result.contains("line1"))
        #expect(result.contains("line2"))
    }
}


@Test func failingString() throws {
    let failingString =
        """
        name: test-component
        version: 1.0.0
        title: Test Component
        nav:
          - modules/ROOT/nav.adoc
        """

    let parser = YAMLParser()
    let value = try parser.parse(failingString)
    #expect(value == .object([
        "name": .string("test-component"),
        "version": .string("1.0.0"),
        "title": .string("Test Component"),
        "nav": .array([.string("modules/ROOT/nav.adoc")])
    ]))

}
@Test func anotherFailingString() throws {
    let antoraYml = """
    name: test-component
    version: 1.0.0
    title: Test Component
    nav:
    - modules/ROOT/nav.adoc
    """

    let parser = YAMLParser()
    let value = try parser.parse(antoraYml)
    #expect(value == .object([
        "name": .string("test-component"),
        "version": .string("1.0.0"),
        "title": .string("Test Component"),
        "nav": .array([.string("modules/ROOT/nav.adoc")])
    ]))

}
