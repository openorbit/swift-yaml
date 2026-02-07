// YAMLKit
//
// SPDX-License-Identifier: Apache-2.0
//
// Copyright (c) 2026 YAMLKit contributors
//
// Native YAML 1.2 implementation in Swift.

import Foundation
import OrderedCollections

public struct YAMLKey: Hashable, Sendable, ExpressibleByStringLiteral, Codable {
    public enum Style: Sendable, Codable {
        case plain
        case singleQuoted
        case doubleQuoted
    }

    public let rawValue: String
    public let style: Style
    public let anchor: String?

    public init(rawValue: String, style: Style = .plain, anchor: String? = nil) {
        self.rawValue = rawValue
        self.style = style
        self.anchor = anchor
    }

    public init(stringLiteral value: String) {
        self.init(rawValue: value, style: .plain, anchor: nil)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self.init(rawValue: rawValue, style: .plain, anchor: nil)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public static func == (lhs: YAMLKey, rhs: YAMLKey) -> Bool {
        lhs.rawValue == rhs.rawValue
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(rawValue)
    }
}

public typealias YAMLObject = OrderedDictionary<YAMLKey, YAMLValue>
public typealias YAMLArray = [YAMLValue]

public enum YAMLStringStyle: Sendable {
    case plain
    case singleQuoted
    case doubleQuoted
    case literalBlock
    case foldedBlock
}

public indirect enum YAMLValue: Equatable, Sendable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case styledString(String, YAMLStringStyle)
    case array(YAMLArray)
    case object(YAMLObject)
    case tagged(String, YAMLValue)
    case anchored(String, YAMLValue)
    case documentStart(YAMLValue, inline: Bool)
    case documentStream([YAMLValue])

    public subscript(key: String) -> YAMLValue? {
        guard case .object(let object) = self else {
            return nil
        }
        return object[YAMLKey(rawValue: key)]
    }

    public subscript(index: Int) -> YAMLValue? {
        guard case .array(let array) = self, array.indices.contains(index) else {
            return nil
        }
        return array[index]
    }

    public var stringValue: String? {
        switch self {
        case .string(let value):
            return value
        case .styledString(let value, _):
            return value
        default:
            return nil
        }
    }

    public var intValue: Int? {
        guard case .int(let value) = self else {
            return nil
        }
        return value
    }

    public var doubleValue: Double? {
        switch self {
        case .double(let value):
            return value
        case .int(let value):
            return Double(value)
        default:
            return nil
        }
    }

    public var boolValue: Bool? {
        guard case .bool(let value) = self else {
            return nil
        }
        return value
    }

    public var arrayValue: YAMLArray? {
        guard case .array(let value) = self else {
            return nil
        }
        return value
    }

    public var objectValue: YAMLObject? {
        guard case .object(let value) = self else {
            return nil
        }
        return value
    }
}

extension YAMLValue: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self = .null
    }
}

extension YAMLValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

extension YAMLValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .int(value)
    }
}

extension YAMLValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .double(value)
    }
}

extension YAMLValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension YAMLValue: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: YAMLValue...) {
        self = .array(elements)
    }
}

extension YAMLValue: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, YAMLValue)...) {
        var object: YAMLObject = [:]
        object.reserveCapacity(elements.count)
        for (key, value) in elements {
            object[YAMLKey(rawValue: key)] = value
        }
        self = .object(object)
    }
}
public enum YAMLCodingError: Error {
    case unsupportedValue
}

extension YAMLValue: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
            return
        }
        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
            return
        }
        if let value = try? container.decode(Int.self) {
            self = .int(value)
            return
        }
        if let value = try? container.decode(Double.self) {
            self = .double(value)
            return
        }
        if let value = try? container.decode(String.self) {
            self = .string(value)
            return
        }
        if let value = try? container.decode(YAMLArray.self) {
            self = .array(value)
            return
        }
        if let value = try? container.decode(YAMLObject.self) {
            self = .object(value)
            return
        }

        throw DecodingError.typeMismatch(
            YAMLValue.self,
            DecodingError.Context(
                codingPath: container.codingPath,
                debugDescription: "Unsupported YAML value."
            )
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .styledString(let value, _):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .tagged(_, let value):
            try container.encode(value)
        case .anchored(_, let value):
            try container.encode(value)
        case .documentStart(let value, _):
            try container.encode(value)
        case .documentStream(let values):
            try container.encode(values)
        }
    }
}

public struct YAMLDecoder {
    public init() {}

    public func decode<T: Decodable>(_ type: T.Type, from value: YAMLValue) throws -> T {
        let decoder = _YAMLDecoder(value: value, codingPath: [])
        return try T(from: decoder)
    }

    public func decode<T: Decodable>(_ type: T.Type, from string: String) throws -> T {
        let value = try YAMLParser().parse(string)
        return try decode(type, from: value)
    }
}

public struct YAMLEncoder {
    public init() {}

    public func encode<T: Encodable>(_ value: T) throws -> YAMLValue {
        let encoder = _YAMLEncoder(codingPath: [])
        try value.encode(to: encoder)
        guard let result = encoder.value else {
            throw YAMLCodingError.unsupportedValue
        }
        return result
    }

    public func encodeToString<T: Encodable>(_ value: T) throws -> String {
        let yamlValue = try encode(value)
        return YAMLSerializer().serialize(yamlValue)
    }
}

public struct YAMLSerializer {
    public init() {}

    public func serialize(_ value: YAMLValue) -> String {
        serializeValue(value, indent: 0, allowFlow: true) + "\n"
    }

    private func serializeValue(_ value: YAMLValue, indent: Int, allowFlow: Bool) -> String {
        switch value {
        case .null:
            return "null"
        case .bool(let bool):
            return bool ? "true" : "false"
        case .int(let int):
            return String(int)
        case .double(let double):
            return String(double)
        case .string(let string):
            return serializeString(string, indent: indent)
        case .styledString(let string, let style):
            return serializeStyledString(string, style: style, indent: indent)
        case .array(let array):
            return serializeArray(array, indent: indent)
        case .object(let object):
            return serializeObject(object, indent: indent, allowFlow: allowFlow)
        case .tagged(let tag, let value):
            return serializeTaggedValue(tag: tag, value: value, indent: indent)
        case .anchored(let anchor, let value):
            return serializeAnchoredValue(anchor: anchor, value: value, indent: indent)
        case .documentStart(let value, let inline):
            return serializeDocumentStart(value, inline: inline)
        case .documentStream(let documents):
            return serializeDocumentStream(documents)
        }
    }

    private func serializeArray(_ array: [YAMLValue], indent: Int) -> String {
        guard !array.isEmpty else {
            return "[]"
        }
        let prefix = String(repeating: " ", count: indent)
        let childIndent = indent + 2
        return array.map { value in
            if case .anchored(let anchor, let anchoredValue) = value {
                return serializeAnchoredSequenceItem(anchor: anchor, value: anchoredValue, indent: indent)
            }
            if isSimpleScalar(value) {
                return "\(prefix)- \(serializeValue(value, indent: childIndent, allowFlow: false))"
            }
            let nested = serializeValue(value, indent: childIndent, allowFlow: false)
            let (first, rest) = splitFirstLine(nested)
            if let first {
                let trimmedFirst = trimLeadingSpacesString(first)
                var lines = ["\(prefix)- \(trimmedFirst)"]
                if let rest {
                    lines.append(rest)
                }
                return lines.joined(separator: "\n")
            }
            return "\(prefix)-"
        }.joined(separator: "\n")
    }

    private func serializeObject(_ object: YAMLObject, indent: Int, allowFlow: Bool) -> String {
        guard !object.isEmpty else {
            return "{}"
        }
        let keys = Array(object.keys)
        let canFlow = allowFlow && indent == 0 && keys.allSatisfy({ key in
            guard let value = object[key] else { return false }
            return isSimpleScalar(value) && isBareKey(key) && !containsLineBreaks(value)
        })
        if canFlow {
            let pairs = keys.map { key in
                "\(serializeKey(key, indent: indent)): \(serializeValue(object[key]!, indent: indent, allowFlow: false))"
            }.joined(separator: ", ")
            return "{\(pairs)}"
        }
        let prefix = String(repeating: " ", count: indent)
        let childIndent = indent + 2
        return keys.map { key in
            let value = object[key]!
            let keyText = serializeKey(key, indent: indent)
            let inlineSeparator = needsSpaceBeforeColon(key) ? " : " : ": "
            let blockSeparator = needsSpaceBeforeColon(key) ? " :\n" : ":\n"
            if case .null = value {
                return "\(prefix)\(keyText):"
            }
            if case .object(let nested) = value, nested.count == 1,
               let nestedPair = nested.first(where: { _ in true }),
               isNullLike(nestedPair.value) {
                let nestedKeyText = serializeKey(nestedPair.key, indent: indent)
                return "\(prefix)\(keyText)\(inlineSeparator)\(nestedKeyText):"
            }
            if case .anchored(let anchor, let anchoredValue) = value {
                return serializeAnchoredMappingValue(
                    anchor: anchor,
                    value: anchoredValue,
                    keyText: keyText,
                    prefix: prefix,
                    inlineSeparator: inlineSeparator,
                    blockSeparator: blockSeparator,
                    indent: childIndent
                )
            }
            if isSimpleScalar(value) {
                return "\(prefix)\(keyText)\(inlineSeparator)\(serializeValue(value, indent: childIndent, allowFlow: false))"
            }
            let nested = serializeValue(value, indent: childIndent, allowFlow: false)
            return "\(prefix)\(keyText)\(blockSeparator)\(nested)"
        }.joined(separator: "\n")
    }

    private func serializeString(_ string: String, indent: Int) -> String {
        if string.contains("\n") {
            return serializeSingleQuotedString(string)
        }
        if isBareString(string) {
            return string
        }
        return serializeDoubleQuotedString(string)
    }

    private func serializeStyledString(_ string: String, style: YAMLStringStyle, indent: Int) -> String {
        switch style {
        case .plain:
            return serializeString(string, indent: indent)
        case .singleQuoted:
            return serializeSingleQuotedString(string)
        case .doubleQuoted:
            return serializeDoubleQuotedString(string)
        case .literalBlock:
            return serializeBlockScalar(string, indent: indent, indicator: "|")
        case .foldedBlock:
            return serializeBlockScalar(string, indent: indent, indicator: ">")
        }
    }

    private func serializeBlockScalar(_ string: String, indent: Int, indicator: String) -> String {
        let prefix = String(repeating: " ", count: indent)
        let indented = string
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { "\(prefix)  \($0)" }
            .joined(separator: "\n")
        return "\(prefix)\(indicator)\n\(indented)"
    }

    private func serializeMultilineStringInSequence(_ string: String, indent: Int) -> String {
        let prefix = String(repeating: " ", count: indent)
        let childIndent = String(repeating: " ", count: indent + 2)
        let indented = string
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { "\(childIndent)\($0)" }
            .joined(separator: "\n")
        return "\(prefix)- |\n\(indented)"
    }

    private func serializeDocumentStart(_ value: YAMLValue, inline: Bool) -> String {
        if case .tagged(let tag, let inner) = value {
            let serializedInner = serializeValue(inner, indent: 0, allowFlow: false)
            if !serializedInner.contains("\n"), (inline || isSimpleScalar(inner)) {
                return "--- \(tag) \(serializedInner)"
            }
            return "--- \(tag)\n\(serializedInner)"
        }
        if case .styledString(let string, let style) = value, style == .literalBlock || style == .foldedBlock {
            let indicator = style == .literalBlock ? "|" : ">"
            return "--- \(serializeBlockScalar(string, indent: 0, indicator: indicator))"
        }
        let serialized = serializeValue(value, indent: 0, allowFlow: true)
        if inline, !serialized.contains("\n") {
            return "--- \(serialized)"
        }
        if case .string(let string) = value, isBareString(string), !serialized.contains("\n") {
            return "--- \(serialized)"
        }
        return "---\n\(serialized)"
    }

    private func serializeDocumentStream(_ documents: [YAMLValue]) -> String {
        let parts = documents.map { document in
            switch document {
            case .documentStart(let value, let inline):
                return serializeDocumentStart(value, inline: inline)
            default:
                return serializeDocumentStart(document, inline: false)
            }
        }
        return parts.joined(separator: "\n")
    }

    private func serializeAnchoredValue(anchor: String, value: YAMLValue, indent: Int) -> String {
        if isSimpleScalar(value) {
            return "&\(anchor) \(serializeValue(value, indent: indent, allowFlow: false))"
        }
        let nested = serializeValue(value, indent: indent, allowFlow: false)
        return "&\(anchor)\n\(nested)"
    }

    private func serializeTaggedValue(tag: String, value: YAMLValue, indent: Int) -> String {
        if isSimpleScalar(value) {
            return "\(tag) \(serializeValue(value, indent: indent, allowFlow: false))"
        }
        let nested: String
        switch value {
        case .object(let object):
            nested = serializeObject(object, indent: indent, allowFlow: false)
        case .array(let array):
            nested = serializeArray(array, indent: indent)
        default:
            nested = serializeValue(value, indent: indent, allowFlow: false)
        }
        return "\(tag)\n\(nested)"
    }

    private func serializeAnchoredMappingValue(
        anchor: String,
        value: YAMLValue,
        keyText: String,
        prefix: String,
        inlineSeparator: String,
        blockSeparator: String,
        indent: Int
    ) -> String {
        if isSimpleScalar(value) {
            return "\(prefix)\(keyText)\(inlineSeparator)&\(anchor) \(serializeValue(value, indent: indent, allowFlow: false))"
        }
        let nested = serializeValue(value, indent: indent, allowFlow: false)
        return "\(prefix)\(keyText)\(inlineSeparator)&\(anchor)\n\(nested)"
    }

    private func serializeAnchoredSequenceItem(anchor: String, value: YAMLValue, indent: Int) -> String {
        let prefix = String(repeating: " ", count: indent)
        let childIndent = indent + 2
        if isSimpleScalar(value) {
            return "\(prefix)- &\(anchor) \(serializeValue(value, indent: childIndent, allowFlow: false))"
        }
        let nested = serializeValue(value, indent: childIndent, allowFlow: false)
        return "\(prefix)- &\(anchor)\n\(nested)"
    }

    private func isSimpleScalar(_ value: YAMLValue) -> Bool {
        switch value {
        case .null, .bool, .int, .double:
            return true
        case .string:
            return true
        case .styledString(_, let style):
            if style == .literalBlock || style == .foldedBlock {
                return false
            }
            return true
        case .tagged(_, let value):
            return isSimpleScalar(value)
        case .array, .object, .anchored, .documentStart, .documentStream:
            return false
        }
    }

    private func containsLineBreaks(_ value: YAMLValue) -> Bool {
        switch value {
        case .string(let string):
            return string.contains("\n")
        case .styledString(let string, _):
            return string.contains("\n")
        case .tagged(_, let nested):
            return containsLineBreaks(nested)
        case .anchored(_, let nested):
            return containsLineBreaks(nested)
        default:
            return false
        }
    }

    private func isBareString(_ string: String) -> Bool {
        guard !string.isEmpty else { return false }
        if string.first?.isWhitespace == true || string.last?.isWhitespace == true {
            return false
        }
        for character in string {
            if character == ":" || character == "#" || character == "," ||
                character == "[" || character == "]" || character == "{" || character == "}" {
                return false
            }
        }
        return true
    }

    private func isBareKey(_ key: YAMLKey) -> Bool {
        key.style == .plain && isBareString(key.rawValue)
    }

    private func isNullLike(_ value: YAMLValue) -> Bool {
        if case .null = value {
            return true
        }
        if case .anchored(_, let nested) = value, case .null = nested {
            return true
        }
        return false
    }

    private func serializeKey(_ key: YAMLKey, indent: Int) -> String {
        let base: String
        switch key.style {
        case .plain:
            base = key.rawValue
        case .singleQuoted:
            base = serializeSingleQuotedString(key.rawValue)
        case .doubleQuoted:
            base = serializeDoubleQuotedString(key.rawValue)
        }
        if let anchor = key.anchor {
            return "&\(anchor) \(base)"
        }
        return base
    }

    private func needsSpaceBeforeColon(_ key: YAMLKey) -> Bool {
        guard key.style == .plain else {
            return false
        }
        return key.rawValue.first == "*"
    }

    private func serializeSingleQuotedString(_ string: String) -> String {
        let escaped = string.replacingOccurrences(of: "'", with: "''")
        return "'\(escaped)'"
    }

    private func serializeDoubleQuotedString(_ string: String) -> String {
        var escaped = ""
        for character in string {
            switch character {
            case "\"": escaped.append("\\\"")
            case "\\": escaped.append("\\\\")
            case "\n": escaped.append("\\n")
            case "\t": escaped.append("\\t")
            default: escaped.append(character)
            }
        }
        return "\"\(escaped)\""
    }

    private func indentLines(_ string: String, indent: Int) -> String {
        let prefix = String(repeating: " ", count: indent)
        return string
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { "\(prefix)\($0)" }
            .joined(separator: "\n")
    }

    private func splitFirstLine(_ string: String) -> (String?, String?) {
        guard let newlineIndex = string.firstIndex(of: "\n") else {
            return string.isEmpty ? (nil, nil) : (string, nil)
        }
        let first = String(string[..<newlineIndex])
        let restStart = string.index(after: newlineIndex)
        let rest = restStart <= string.endIndex ? String(string[restStart...]) : ""
        return (first, rest.isEmpty ? nil : rest)
    }

    private func trimLeadingSpacesString(_ string: String) -> String {
        var index = string.startIndex
        while index < string.endIndex, string[index].isWhitespace {
            index = string.index(after: index)
        }
        return String(string[index...])
    }

}


private final class _YAMLDecoder: Decoder {
    let value: YAMLValue
    var codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey: Any] = [:]

    init(value: YAMLValue, codingPath: [CodingKey]) {
        self.value = value
        self.codingPath = codingPath
    }

    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        guard case .object(let object) = value else {
            throw DecodingError.typeMismatch(
                [String: YAMLValue].self,
                DecodingError.Context(codingPath: codingPath, debugDescription: "Expected mapping.")
            )
        }
        let container = YAMLKeyedDecodingContainer<Key>(decoder: self, object: object)
        return KeyedDecodingContainer(container)
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        guard case .array(let array) = value else {
            throw DecodingError.typeMismatch(
                [YAMLValue].self,
                DecodingError.Context(codingPath: codingPath, debugDescription: "Expected sequence.")
            )
        }
        return YAMLUnkeyedDecodingContainer(decoder: self, array: array)
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        return YAMLSingleValueDecodingContainer(decoder: self, value: value)
    }
}

private struct YAMLKeyedDecodingContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
    let decoder: _YAMLDecoder
    let object: YAMLObject

    var codingPath: [CodingKey] { decoder.codingPath }
    var allKeys: [Key] { object.keys.compactMap { Key(stringValue: $0.rawValue) } }

    func contains(_ key: Key) -> Bool {
        object[YAMLKey(rawValue: key.stringValue)] != nil
    }

    func decodeNil(forKey key: Key) throws -> Bool {
        guard let value = object[YAMLKey(rawValue: key.stringValue)] else { return true }
        if case .null = value { return true }
        return false
    }

    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
        try decodeValue(forKey: key, as: Bool.self)
    }

    func decode(_ type: String.Type, forKey key: Key) throws -> String {
        try decodeValue(forKey: key, as: String.self)
    }

    func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
        try decodeValue(forKey: key, as: Double.self)
    }

    func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
        Float(try decodeValue(forKey: key, as: Double.self))
    }

    func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
        try decodeValue(forKey: key, as: Int.self)
    }

    func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
        try decodeFixedWidth(forKey: key, as: Int8.self)
    }

    func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
        try decodeFixedWidth(forKey: key, as: Int16.self)
    }

    func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
        try decodeFixedWidth(forKey: key, as: Int32.self)
    }

    func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
        try decodeFixedWidth(forKey: key, as: Int64.self)
    }

    func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
        try decodeFixedWidth(forKey: key, as: UInt.self)
    }

    func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
        try decodeFixedWidth(forKey: key, as: UInt8.self)
    }

    func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
        try decodeFixedWidth(forKey: key, as: UInt16.self)
    }

    func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
        try decodeFixedWidth(forKey: key, as: UInt32.self)
    }

    func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
        try decodeFixedWidth(forKey: key, as: UInt64.self)
    }

    func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T: Decodable {
        let value = try valueForKey(key)
        let nestedDecoder = _YAMLDecoder(value: value, codingPath: codingPath + [key])
        return try T(from: nestedDecoder)
    }

    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> {
        let value = try valueForKey(key)
        let decoder = _YAMLDecoder(value: value, codingPath: codingPath + [key])
        return try decoder.container(keyedBy: type)
    }

    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        let value = try valueForKey(key)
        let decoder = _YAMLDecoder(value: value, codingPath: codingPath + [key])
        return try decoder.unkeyedContainer()
    }

    func superDecoder() throws -> Decoder {
        _YAMLDecoder(value: .object(object), codingPath: codingPath)
    }

    func superDecoder(forKey key: Key) throws -> Decoder {
        let value = try valueForKey(key)
        return _YAMLDecoder(value: value, codingPath: codingPath + [key])
    }

    private func valueForKey(_ key: Key) throws -> YAMLValue {
        guard let value = object[YAMLKey(rawValue: key.stringValue)] else {
            throw DecodingError.keyNotFound(
                key,
                DecodingError.Context(codingPath: codingPath, debugDescription: "No value for key.")
            )
        }
        return value
    }

    private func decodeValue<T>(forKey key: Key, as type: T.Type) throws -> T {
        let value = try valueForKey(key)
        return try yamlDecodeScalar(value, as: type, codingPath: codingPath + [key])
    }

    private func decodeFixedWidth<T: FixedWidthInteger>(forKey key: Key, as type: T.Type) throws -> T {
        let value = try valueForKey(key)
        return try yamlDecodeInteger(value, as: type, codingPath: codingPath + [key])
    }
}

private struct YAMLUnkeyedDecodingContainer: UnkeyedDecodingContainer {
    let decoder: _YAMLDecoder
    let array: [YAMLValue]
    var codingPath: [CodingKey] { decoder.codingPath }
    var count: Int? { array.count }
    var isAtEnd: Bool { currentIndex >= array.count }
    var currentIndex: Int = 0

    mutating func decodeNil() throws -> Bool {
        guard !isAtEnd else { return true }
        if case .null = array[currentIndex] {
            currentIndex += 1
            return true
        }
        return false
    }

    mutating func decode(_ type: Bool.Type) throws -> Bool {
        try decodeScalar(as: Bool.self)
    }

    mutating func decode(_ type: String.Type) throws -> String {
        try decodeScalar(as: String.self)
    }

    mutating func decode(_ type: Double.Type) throws -> Double {
        try decodeScalar(as: Double.self)
    }

    mutating func decode(_ type: Float.Type) throws -> Float {
        Float(try decodeScalar(as: Double.self))
    }

    mutating func decode(_ type: Int.Type) throws -> Int {
        try decodeScalar(as: Int.self)
    }

    mutating func decode(_ type: Int8.Type) throws -> Int8 {
        try decodeInteger(as: Int8.self)
    }

    mutating func decode(_ type: Int16.Type) throws -> Int16 {
        try decodeInteger(as: Int16.self)
    }

    mutating func decode(_ type: Int32.Type) throws -> Int32 {
        try decodeInteger(as: Int32.self)
    }

    mutating func decode(_ type: Int64.Type) throws -> Int64 {
        try decodeInteger(as: Int64.self)
    }

    mutating func decode(_ type: UInt.Type) throws -> UInt {
        try decodeInteger(as: UInt.self)
    }

    mutating func decode(_ type: UInt8.Type) throws -> UInt8 {
        try decodeInteger(as: UInt8.self)
    }

    mutating func decode(_ type: UInt16.Type) throws -> UInt16 {
        try decodeInteger(as: UInt16.self)
    }

    mutating func decode(_ type: UInt32.Type) throws -> UInt32 {
        try decodeInteger(as: UInt32.self)
    }

    mutating func decode(_ type: UInt64.Type) throws -> UInt64 {
        try decodeInteger(as: UInt64.self)
    }

    mutating func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
        let value = try nextValue()
        let nestedDecoder = _YAMLDecoder(value: value, codingPath: codingPath + [YAMLIndexKey(intValue: currentIndex - 1)])
        return try T(from: nestedDecoder)
    }

    mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> {
        let value = try nextValue()
        let decoder = _YAMLDecoder(value: value, codingPath: codingPath + [YAMLIndexKey(intValue: currentIndex - 1)])
        return try decoder.container(keyedBy: type)
    }

    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        let value = try nextValue()
        let decoder = _YAMLDecoder(value: value, codingPath: codingPath + [YAMLIndexKey(intValue: currentIndex - 1)])
        return try decoder.unkeyedContainer()
    }

    mutating func superDecoder() throws -> Decoder {
        let value = try nextValue()
        return _YAMLDecoder(value: value, codingPath: codingPath + [YAMLIndexKey(intValue: currentIndex - 1)])
    }

    private mutating func nextValue() throws -> YAMLValue {
        guard !isAtEnd else {
            throw DecodingError.valueNotFound(
                YAMLValue.self,
                DecodingError.Context(codingPath: codingPath, debugDescription: "Unkeyed container is at end.")
            )
        }
        let value = array[currentIndex]
        currentIndex += 1
        return value
    }

    private mutating func decodeScalar<T>(as type: T.Type) throws -> T {
        let value = try nextValue()
        return try yamlDecodeScalar(value, as: type, codingPath: codingPath + [YAMLIndexKey(intValue: currentIndex - 1)])
    }

    private mutating func decodeInteger<T: FixedWidthInteger>(as type: T.Type) throws -> T {
        let value = try nextValue()
        return try yamlDecodeInteger(value, as: type, codingPath: codingPath + [YAMLIndexKey(intValue: currentIndex - 1)])
    }
}

private struct YAMLSingleValueDecodingContainer: SingleValueDecodingContainer {
    let decoder: _YAMLDecoder
    let value: YAMLValue
    var codingPath: [CodingKey] { decoder.codingPath }

    func decodeNil() -> Bool {
        if case .null = value { return true }
        return false
    }

    func decode(_ type: Bool.Type) throws -> Bool {
        try yamlDecodeScalar(value, as: Bool.self, codingPath: codingPath)
    }

    func decode(_ type: String.Type) throws -> String {
        try yamlDecodeScalar(value, as: String.self, codingPath: codingPath)
    }

    func decode(_ type: Double.Type) throws -> Double {
        try yamlDecodeScalar(value, as: Double.self, codingPath: codingPath)
    }

    func decode(_ type: Float.Type) throws -> Float {
        Float(try yamlDecodeScalar(value, as: Double.self, codingPath: codingPath))
    }

    func decode(_ type: Int.Type) throws -> Int {
        try yamlDecodeScalar(value, as: Int.self, codingPath: codingPath)
    }

    func decode(_ type: Int8.Type) throws -> Int8 {
        try yamlDecodeInteger(value, as: Int8.self, codingPath: codingPath)
    }

    func decode(_ type: Int16.Type) throws -> Int16 {
        try yamlDecodeInteger(value, as: Int16.self, codingPath: codingPath)
    }

    func decode(_ type: Int32.Type) throws -> Int32 {
        try yamlDecodeInteger(value, as: Int32.self, codingPath: codingPath)
    }

    func decode(_ type: Int64.Type) throws -> Int64 {
        try yamlDecodeInteger(value, as: Int64.self, codingPath: codingPath)
    }

    func decode(_ type: UInt.Type) throws -> UInt {
        try yamlDecodeInteger(value, as: UInt.self, codingPath: codingPath)
    }

    func decode(_ type: UInt8.Type) throws -> UInt8 {
        try yamlDecodeInteger(value, as: UInt8.self, codingPath: codingPath)
    }

    func decode(_ type: UInt16.Type) throws -> UInt16 {
        try yamlDecodeInteger(value, as: UInt16.self, codingPath: codingPath)
    }

    func decode(_ type: UInt32.Type) throws -> UInt32 {
        try yamlDecodeInteger(value, as: UInt32.self, codingPath: codingPath)
    }

    func decode(_ type: UInt64.Type) throws -> UInt64 {
        try yamlDecodeInteger(value, as: UInt64.self, codingPath: codingPath)
    }

    func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
        let nestedDecoder = _YAMLDecoder(value: value, codingPath: codingPath)
        return try T(from: nestedDecoder)
    }
}

private final class _YAMLEncoder: Encoder {
    var codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey: Any] = [:]
    var value: YAMLValue?

    init(codingPath: [CodingKey]) {
        self.codingPath = codingPath
    }

    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        let container = YAMLKeyedEncodingContainer<Key>(encoder: self, codingPath: codingPath)
        return KeyedEncodingContainer(container)
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        YAMLUnkeyedEncodingContainer(encoder: self, codingPath: codingPath)
    }

    func singleValueContainer() -> SingleValueEncodingContainer {
        YAMLSingleValueEncodingContainer(encoder: self, codingPath: codingPath)
    }
}

private struct YAMLKeyedEncodingContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
    let encoder: _YAMLEncoder
    var codingPath: [CodingKey]
    private var object: YAMLObject = [:]

    init(encoder: _YAMLEncoder, codingPath: [CodingKey]) {
        self.encoder = encoder
        self.codingPath = codingPath
    }

    mutating func encodeNil(forKey key: Key) throws {
        object[YAMLKey(rawValue: key.stringValue)] = .null
        encoder.value = .object(object)
    }

    mutating func encode(_ value: Bool, forKey key: Key) throws { try set(.bool(value), forKey: key) }
    mutating func encode(_ value: String, forKey key: Key) throws { try set(.string(value), forKey: key) }
    mutating func encode(_ value: Double, forKey key: Key) throws { try set(.double(value), forKey: key) }
    mutating func encode(_ value: Float, forKey key: Key) throws { try set(.double(Double(value)), forKey: key) }
    mutating func encode(_ value: Int, forKey key: Key) throws { try set(.int(value), forKey: key) }
    mutating func encode(_ value: Int8, forKey key: Key) throws { try set(.int(Int(value)), forKey: key) }
    mutating func encode(_ value: Int16, forKey key: Key) throws { try set(.int(Int(value)), forKey: key) }
    mutating func encode(_ value: Int32, forKey key: Key) throws { try set(.int(Int(value)), forKey: key) }
    mutating func encode(_ value: Int64, forKey key: Key) throws { try set(.int(Int(value)), forKey: key) }
    mutating func encode(_ value: UInt, forKey key: Key) throws { try set(.int(Int(value)), forKey: key) }
    mutating func encode(_ value: UInt8, forKey key: Key) throws { try set(.int(Int(value)), forKey: key) }
    mutating func encode(_ value: UInt16, forKey key: Key) throws { try set(.int(Int(value)), forKey: key) }
    mutating func encode(_ value: UInt32, forKey key: Key) throws { try set(.int(Int(value)), forKey: key) }
    mutating func encode(_ value: UInt64, forKey key: Key) throws { try set(.int(Int(value)), forKey: key) }

    mutating func encode<T>(_ value: T, forKey key: Key) throws where T: Encodable {
        let nested = _YAMLEncoder(codingPath: codingPath + [key])
        try value.encode(to: nested)
        guard let encoded = nested.value else {
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(codingPath: codingPath + [key], debugDescription: "Unsupported value.")
            )
        }
        object[YAMLKey(rawValue: key.stringValue)] = encoded
        encoder.value = .object(object)
    }

    mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> {
        let nested = YAMLKeyedEncodingContainer<NestedKey>(encoder: encoder, codingPath: codingPath + [key])
        return KeyedEncodingContainer(nested)
    }

    mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        YAMLUnkeyedEncodingContainer(encoder: encoder, codingPath: codingPath + [key])
    }

    mutating func superEncoder() -> Encoder {
        _YAMLEncoder(codingPath: codingPath)
    }

    mutating func superEncoder(forKey key: Key) -> Encoder {
        _YAMLEncoder(codingPath: codingPath + [key])
    }

    private mutating func set(_ value: YAMLValue, forKey key: Key) throws {
        object[YAMLKey(rawValue: key.stringValue)] = value
        encoder.value = .object(object)
    }
}

private struct YAMLUnkeyedEncodingContainer: UnkeyedEncodingContainer {
    let encoder: _YAMLEncoder
    var codingPath: [CodingKey]
    private var array: [YAMLValue] = []

    init(encoder: _YAMLEncoder, codingPath: [CodingKey]) {
        self.encoder = encoder
        self.codingPath = codingPath
    }

    var count: Int { array.count }

    mutating func encodeNil() throws {
        array.append(.null)
        encoder.value = .array(array)
    }

    mutating func encode(_ value: Bool) throws { try append(.bool(value)) }
    mutating func encode(_ value: String) throws { try append(.string(value)) }
    mutating func encode(_ value: Double) throws { try append(.double(value)) }
    mutating func encode(_ value: Float) throws { try append(.double(Double(value))) }
    mutating func encode(_ value: Int) throws { try append(.int(value)) }
    mutating func encode(_ value: Int8) throws { try append(.int(Int(value))) }
    mutating func encode(_ value: Int16) throws { try append(.int(Int(value))) }
    mutating func encode(_ value: Int32) throws { try append(.int(Int(value))) }
    mutating func encode(_ value: Int64) throws { try append(.int(Int(value))) }
    mutating func encode(_ value: UInt) throws { try append(.int(Int(value))) }
    mutating func encode(_ value: UInt8) throws { try append(.int(Int(value))) }
    mutating func encode(_ value: UInt16) throws { try append(.int(Int(value))) }
    mutating func encode(_ value: UInt32) throws { try append(.int(Int(value))) }
    mutating func encode(_ value: UInt64) throws { try append(.int(Int(value))) }

    mutating func encode<T>(_ value: T) throws where T: Encodable {
        let nested = _YAMLEncoder(codingPath: codingPath + [YAMLIndexKey(intValue: array.count)])
        try value.encode(to: nested)
        guard let encoded = nested.value else {
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(codingPath: codingPath, debugDescription: "Unsupported value.")
            )
        }
        array.append(encoded)
        encoder.value = .array(array)
    }

    mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> {
        let nested = YAMLKeyedEncodingContainer<NestedKey>(encoder: encoder, codingPath: codingPath + [YAMLIndexKey(intValue: array.count)])
        return KeyedEncodingContainer(nested)
    }

    mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        YAMLUnkeyedEncodingContainer(encoder: encoder, codingPath: codingPath + [YAMLIndexKey(intValue: array.count)])
    }

    mutating func superEncoder() -> Encoder {
        _YAMLEncoder(codingPath: codingPath)
    }

    private mutating func append(_ value: YAMLValue) throws {
        array.append(value)
        encoder.value = .array(array)
    }
}

private struct YAMLSingleValueEncodingContainer: SingleValueEncodingContainer {
    let encoder: _YAMLEncoder
    var codingPath: [CodingKey]

    func encodeNil() throws { encoder.value = .null }
    func encode(_ value: Bool) throws { encoder.value = .bool(value) }
    func encode(_ value: String) throws { encoder.value = .string(value) }
    func encode(_ value: Double) throws { encoder.value = .double(value) }
    func encode(_ value: Float) throws { encoder.value = .double(Double(value)) }
    func encode(_ value: Int) throws { encoder.value = .int(value) }
    func encode(_ value: Int8) throws { encoder.value = .int(Int(value)) }
    func encode(_ value: Int16) throws { encoder.value = .int(Int(value)) }
    func encode(_ value: Int32) throws { encoder.value = .int(Int(value)) }
    func encode(_ value: Int64) throws { encoder.value = .int(Int(value)) }
    func encode(_ value: UInt) throws { encoder.value = .int(Int(value)) }
    func encode(_ value: UInt8) throws { encoder.value = .int(Int(value)) }
    func encode(_ value: UInt16) throws { encoder.value = .int(Int(value)) }
    func encode(_ value: UInt32) throws { encoder.value = .int(Int(value)) }
    func encode(_ value: UInt64) throws { encoder.value = .int(Int(value)) }

    func encode<T>(_ value: T) throws where T: Encodable {
        let nested = _YAMLEncoder(codingPath: codingPath)
        try value.encode(to: nested)
        guard let encoded = nested.value else {
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(codingPath: codingPath, debugDescription: "Unsupported value.")
            )
        }
        encoder.value = encoded
    }
}

private struct YAMLIndexKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init(intValue: Int) {
        self.intValue = intValue
        self.stringValue = "\(intValue)"
    }

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = Int(stringValue)
    }
}

private func yamlDecodeScalar<T>(_ value: YAMLValue, as type: T.Type, codingPath: [CodingKey]) throws -> T {
    switch type {
    case is Bool.Type:
        if case .bool(let bool) = value {
            return bool as! T
        }
    case is String.Type:
        if case .string(let string) = value {
            return string as! T
        }
    case is Double.Type:
        switch value {
        case .double(let double):
            return double as! T
        case .int(let int):
            return Double(int) as! T
        default:
            break
        }
    case is Int.Type:
        if case .int(let int) = value {
            return int as! T
        }
    default:
        break
    }
    throw DecodingError.typeMismatch(
        type,
        DecodingError.Context(codingPath: codingPath, debugDescription: "Type mismatch.")
    )
}

private func yamlDecodeInteger<T: FixedWidthInteger>(_ value: YAMLValue, as type: T.Type, codingPath: [CodingKey]) throws -> T {
    switch value {
    case .int(let intValue):
        guard let converted = T(exactly: intValue) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: codingPath, debugDescription: "Integer out of range.")
            )
        }
        return converted
    case .double(let doubleValue):
        let intValue = Int(doubleValue)
        guard Double(intValue) == doubleValue, let converted = T(exactly: intValue) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: codingPath, debugDescription: "Non-integer number.")
            )
        }
        return converted
    default:
        throw DecodingError.typeMismatch(
            type,
            DecodingError.Context(codingPath: codingPath, debugDescription: "Type mismatch.")
        )
    }
}

public enum YAMLParseError: Error, Equatable {
    case emptyDocument
    case invalidScalar
    case trailingCharacters
    case expectedFlowSequenceEnd
    case expectedFlowMappingEnd
    case expectedMappingSeparator
    case nonStringKey
    case invalidBlockIndentation
}

public struct YAMLParser {
    public init() {}

    public func parse(_ source: String) throws -> YAMLValue {
        if let blockValue = try parseBlockDocumentIfPresent(source) {
            return blockValue
        }
        var input = source[...]
        consumeWhitespaceAndComments(&input)
        let documentStart = skipDirectivesAndDocumentStart(&input)
        consumeWhitespaceAndComments(&input)
        guard !input.isEmpty else {
            throw YAMLParseError.emptyDocument
        }
        let value = try parseValue(&input)
        consumeWhitespaceAndComments(&input)
        if !input.isEmpty {
            throw YAMLParseError.trailingCharacters
        }
        if documentStart.saw {
            return .documentStart(value, inline: documentStart.inline)
        }
        return value
    }

    private func parseValue(_ input: inout Substring) throws -> YAMLValue {
        if let first = input.first {
            if first == "[" {
                return try parseFlowSequence(&input)
            }
            if first == "{" {
                return try parseFlowMapping(&input)
            }
        }
        return try parseScalar(&input)
    }

    private func parseScalar(_ input: inout Substring) throws -> YAMLValue {
        if input.hasPrefix("null") && isDelimiter(after: input, prefixCount: 4) {
            input.removeFirst(4)
            return .null
        }
        if input.hasPrefix("true") && isDelimiter(after: input, prefixCount: 4) {
            input.removeFirst(4)
            return .bool(true)
        }
        if input.hasPrefix("false") && isDelimiter(after: input, prefixCount: 5) {
            input.removeFirst(5)
            return .bool(false)
        }
        if let first = input.first {
            if first == "\"" || first == "'" {
                let style: YAMLStringStyle = first == "'" ? .singleQuoted : .doubleQuoted
                guard let string = parseQuotedString(&input) else {
                    throw YAMLParseError.invalidScalar
                }
                return .styledString(string, style)
            }
            if first.isNumber || (first == "-" && input.dropFirst().first?.isNumber == true) {
                let original = input
                if let number = parseNumber(&input) {
                    if isValueTerminator(input.first) {
                        return number
                    }
                }
                input = original
            }
        }
        if let anchored = try parseAnchoredInline(&input) {
            return anchored
        }
        if let anchored = try parseAnchoredInline(&input) {
            return anchored
        }
        if let string = parseBareString(&input) {
            return .string(string)
        }
        throw YAMLParseError.invalidScalar
    }

    private func parseAnchoredInline(_ input: inout Substring) throws -> YAMLValue? {
        let trimmed = trimLeadingSpaces(input)
        guard let first = trimmed.first, first == "&" else {
            return nil
        }
        let start = trimmed.index(after: trimmed.startIndex)
        var cursor = start
        while cursor < trimmed.endIndex, !trimmed[cursor].isWhitespace {
            cursor = trimmed.index(after: cursor)
        }
        guard cursor > start else {
            return nil
        }
        let anchor = String(trimmed[start..<cursor])
        let remainder = trimmed[cursor...]
        if isOnlyWhitespace(remainder) {
            input = input[input.endIndex...]
            return .anchored(anchor, .null)
        }
        let remainderInput = remainder
        let value = try parseInlineValue(remainderInput)
        input = input[input.endIndex...]
        return .anchored(anchor, value)
    }

    private func parseNumber(_ input: inout Substring) -> YAMLValue? {
        let original = input
        var cursor = input.startIndex
        if cursor < input.endIndex, input[cursor] == "-" {
            cursor = input.index(after: cursor)
        }

        let integerStart = cursor
        while cursor < input.endIndex, input[cursor].isASCII, input[cursor].isNumber {
            cursor = input.index(after: cursor)
        }
        if integerStart == cursor {
            return nil
        }

        var isDouble = false
        if cursor < input.endIndex, input[cursor] == "." {
            isDouble = true
            cursor = input.index(after: cursor)
            let fractionStart = cursor
            while cursor < input.endIndex, input[cursor].isASCII, input[cursor].isNumber {
                cursor = input.index(after: cursor)
            }
            if fractionStart == cursor {
                return nil
            }
        }

        let valueString = String(original[..<cursor])
        if isDouble {
            guard let value = Double(valueString) else {
                return nil
            }
            input = original[cursor...]
            return .double(value)
        }

        guard let value = Int(valueString) else {
            return nil
        }
        input = original[cursor...]
        return .int(value)
    }

    private func parseQuotedString(_ input: inout Substring) -> String? {
        guard let quote = input.first, quote == "\"" || quote == "'" else {
            return nil
        }
        let original = input
        var cursor = input.index(after: input.startIndex)
        var result = ""
        while cursor < input.endIndex {
            let next = input[cursor]
            if next == quote {
                let nextIndex = input.index(after: cursor)
                input = input[nextIndex...]
                return result
            }
            if quote == "\"" && next == "\\" {
                let escapeIndex = input.index(after: cursor)
                guard escapeIndex < input.endIndex else {
                    return nil
                }
                let escaped = input[escapeIndex]
                switch escaped {
                case "\"": result.append("\"")
                case "\\": result.append("\\")
                case "n": result.append("\n")
                case "t": result.append("\t")
                default: return nil
                }
                cursor = input.index(after: escapeIndex)
                continue
            }
            result.append(next)
            cursor = input.index(after: cursor)
        }
        input = original
        return nil
    }

    private func parseBareString(_ input: inout Substring) -> String? {
        let start = input.startIndex
        var cursor = input.startIndex
        while cursor < input.endIndex,
              !input[cursor].isWhitespace,
              input[cursor] != "#",
              input[cursor] != ",",
              input[cursor] != "]",
              input[cursor] != "}",
              input[cursor] != ":" {
            cursor = input.index(after: cursor)
        }
        guard start != cursor else {
            return nil
        }
        let value = String(input[start..<cursor])
        input = input[cursor...]
        return value
    }

    private func consumeWhitespaceAndComments(_ input: inout Substring) {
        while true {
            var advanced = false
            while let first = input.first, first.isWhitespace {
                input.removeFirst()
                advanced = true
            }
            if input.first == "#" {
                while let first = input.first, first != "\n" {
                    input.removeFirst()
                }
                advanced = true
                continue
            }
            if !advanced {
                break
            }
        }
    }

    private func skipDirectivesAndDocumentStart(_ input: inout Substring) -> (saw: Bool, inline: Bool) {
        var sawDocumentStart = false
        var sawInlineDocumentStart = false
        while true {
            if input.hasPrefix("%") {
                consumeLine(&input)
                consumeWhitespaceAndComments(&input)
                continue
            }
            if input.hasPrefix("---") {
                let after = input.index(input.startIndex, offsetBy: 3)
                if after == input.endIndex || input[after].isWhitespace {
                    let remainder = input[after...]
                    var cursor = remainder.startIndex
                    while cursor < remainder.endIndex,
                          remainder[cursor].isWhitespace,
                          remainder[cursor] != "\n" {
                        cursor = remainder.index(after: cursor)
                    }
                    if cursor < remainder.endIndex,
                       remainder[cursor] != "\n",
                       remainder[cursor] != "#" {
                        sawInlineDocumentStart = true
                    }
                    input = input[after...]
                    sawDocumentStart = true
                    if sawInlineDocumentStart {
                        return (true, true)
                    }
                    consumeWhitespaceAndComments(&input)
                    continue
                }
            }
            break
        }
        return (sawDocumentStart, sawInlineDocumentStart)
    }

    private func consumeLine(_ input: inout Substring) {
        while let first = input.first, first != "\n" {
            input.removeFirst()
        }
        if input.first == "\n" {
            input.removeFirst()
        }
    }

    private func isDelimiter(after input: Substring, prefixCount: Int) -> Bool {
        guard input.count >= prefixCount else {
            return false
        }
        let index = input.index(input.startIndex, offsetBy: prefixCount)
        guard index < input.endIndex else {
            return true
        }
        let next = input[index]
        return next.isWhitespace || next == "#" || next == "," || next == "]" || next == "}"
    }

    private func isValueTerminator(_ character: Character?) -> Bool {
        guard let character else { return true }
        return character.isWhitespace || character == "#" || character == "," || character == "]" || character == "}" || character == ":"
    }

    private func parseFlowSequence(_ input: inout Substring) throws -> YAMLValue {
        guard input.first == "[" else {
            throw YAMLParseError.invalidScalar
        }
        input.removeFirst()
        consumeWhitespaceAndComments(&input)
        var elements: [YAMLValue] = []
        if input.first == "]" {
            input.removeFirst()
            return .array(elements)
        }
        while true {
            let value = try parseValue(&input)
            elements.append(value)
            consumeWhitespaceAndComments(&input)
            if input.first == "," {
                input.removeFirst()
                consumeWhitespaceAndComments(&input)
                if input.first == "]" {
                    throw YAMLParseError.expectedFlowSequenceEnd
                }
                continue
            }
            if input.first == "]" {
                input.removeFirst()
                return .array(elements)
            }
            throw YAMLParseError.expectedFlowSequenceEnd
        }
    }

    private func parseFlowMapping(_ input: inout Substring) throws -> YAMLValue {
        guard input.first == "{" else {
            throw YAMLParseError.invalidScalar
        }
        input.removeFirst()
        consumeWhitespaceAndComments(&input)
        var object: YAMLObject = [:]
        if input.first == "}" {
            input.removeFirst()
            return .object(object)
        }
        while true {
            let key = try parseKeyScalar(&input)
            consumeWhitespaceAndComments(&input)
            guard input.first == ":" else {
                throw YAMLParseError.expectedMappingSeparator
            }
            input.removeFirst()
            consumeWhitespaceAndComments(&input)
            let value = try parseValue(&input)
            object[key] = value
            consumeWhitespaceAndComments(&input)
            if input.first == "," {
                input.removeFirst()
                consumeWhitespaceAndComments(&input)
                if input.first == "}" {
                    throw YAMLParseError.expectedFlowMappingEnd
                }
                continue
            }
            if input.first == "}" {
                input.removeFirst()
                return .object(object)
            }
            throw YAMLParseError.expectedFlowMappingEnd
        }
    }

    private struct Line {
        let indent: Int
        let content: Substring
    }

    private struct LineCursor {
        let lines: [Line]
        var index: Int
    }

    private func parseBlockDocumentIfPresent(_ source: String) throws -> YAMLValue? {
        let lines = makeLines(from: source)
        var cursor = LineCursor(lines: lines, index: 0)
        var documents: [YAMLValue] = []
        advanceToNextNonEmptyLine(&cursor)

        while true {
            if cursor.index >= cursor.lines.count {
                break
            }
            var sawDocumentStart = false
            var didAppendDocument = false
            while cursor.index < cursor.lines.count {
                let line = cursor.lines[cursor.index]
                let trimmed = trimLeadingSpaces(line.content)
                if isDirectiveLine(trimmed) {
                    cursor.index += 1
                    advanceToNextNonEmptyLine(&cursor)
                    continue
                }
                if isDocumentStartLine(trimmed) {
                    sawDocumentStart = true
                    if let inlineContent = inlineContentAfterDocumentStart(trimmed) {
                        if let tagName = parseTagName(from: inlineContent), isTagOnlyLine(inlineContent) {
                            cursor.index += 1
                            advanceToNextNonEmptyLine(&cursor)
                            if let first = peekNonEmptyLine(cursor) {
                                let value = try parseBlockValue(&cursor, indent: first.indent)
                                documents.append(.documentStart(.tagged(tagName, value), inline: false))
                                advanceToNextNonEmptyLine(&cursor)
                                didAppendDocument = true
                                break
                            }
                            documents.append(.documentStart(.tagged(tagName, .null), inline: false))
                            advanceToNextNonEmptyLine(&cursor)
                            didAppendDocument = true
                            break
                        }
                        if isBlockScalarIndicator(inlineContent) {
                            if let blockScalar = try parseInlineBlockScalar(&cursor, indent: line.indent, remainder: inlineContent) {
                                documents.append(.documentStart(blockScalar, inline: false))
                                advanceToNextNonEmptyLine(&cursor)
                                didAppendDocument = true
                                break
                            }
                        }
                        let value = try parseInlineValue(inlineContent)
                        documents.append(.documentStart(value, inline: true))
                        cursor.index += 1
                        advanceToNextNonEmptyLine(&cursor)
                        didAppendDocument = true
                        break
                    }
                    cursor.index += 1
                    advanceToNextNonEmptyLine(&cursor)
                    continue
                }
                break
            }

            if didAppendDocument {
                continue
            }

            guard let first = peekNonEmptyLine(cursor) else {
                break
            }
            let firstTrimmed = trimLeadingSpaces(first.content)
            if isDocumentStartLine(firstTrimmed) || isDirectiveLine(firstTrimmed) {
                continue
            }
            if isBlockSequenceLine(first, indent: first.indent) ||
                isBlockMappingLine(first, indent: first.indent) ||
                anchorNameIfOnly(firstTrimmed) != nil {
                let value = try parseBlockValue(&cursor, indent: first.indent)
                let documentValue = sawDocumentStart ? .documentStart(value, inline: false) : value
                documents.append(documentValue)
                advanceToNextNonEmptyLine(&cursor)
                if cursor.index < cursor.lines.count {
                    let next = cursor.lines[cursor.index]
                    let trimmed = trimLeadingSpaces(next.content)
                    if !isDocumentStartLine(trimmed) && !isDirectiveLine(trimmed) {
                        throw YAMLParseError.trailingCharacters
                    }
                }
                continue
            }

            if documents.isEmpty {
                return nil
            }
            break
        }

        if documents.isEmpty {
            return nil
        }
        if documents.count == 1 {
            return documents[0]
        }
        if let next = peekNonEmptyLine(cursor) {
            let trimmed = trimLeadingSpaces(next.content)
            if !isDocumentStartLine(trimmed) && !isDirectiveLine(trimmed) {
                throw YAMLParseError.trailingCharacters
            }
        }
        return .documentStream(documents)
    }

    private func makeLines(from source: String) -> [Line] {
        var result: [Line] = []
        var index = source.startIndex
        while index <= source.endIndex {
            let lineEnd = source[index...].firstIndex(of: "\n") ?? source.endIndex
            let line = source[index..<lineEnd]
            var indentCount = 0
            var cursor = line.startIndex
            while cursor < line.endIndex, line[cursor] == " " {
                indentCount += 1
                cursor = line.index(after: cursor)
            }
            let content = line[cursor...]
            result.append(Line(indent: indentCount, content: content))
            if lineEnd == source.endIndex {
                break
            }
            index = source.index(after: lineEnd)
        }
        return result
    }

    private func isDirectiveLine(_ content: Substring) -> Bool {
        return content.hasPrefix("%")
    }

    private func isDocumentStartLine(_ content: Substring) -> Bool {
        guard content.hasPrefix("---") else {
            return false
        }
        if content.count == 3 {
            return true
        }
        let index = content.index(content.startIndex, offsetBy: 3)
        return index < content.endIndex ? content[index].isWhitespace : true
    }

    private func inlineContentAfterDocumentStart(_ content: Substring) -> Substring? {
        guard content.hasPrefix("---") else {
            return nil
        }
        let after = content.index(content.startIndex, offsetBy: 3)
        guard after < content.endIndex else {
            return nil
        }
        var remainder = content[after...]
        while let first = remainder.first, first.isWhitespace, first != "\n" {
            remainder.removeFirst()
        }
        guard let first = remainder.first, first != "#" else {
            return nil
        }
        let stripped = stripInlineComment(remainder)
        let trimmed = stripTrailingSpaces(stripped)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func isTagOnlyLine(_ content: Substring) -> Bool {
        return parseTagName(from: content) != nil && !content.contains(where: { $0.isWhitespace })
    }

    private func isBlockScalarIndicator(_ content: Substring) -> Bool {
        let trimmed = trimLeadingSpaces(content)
        guard let first = trimmed.first, first == "|" || first == ">" else {
            return false
        }
        var index = trimmed.index(after: trimmed.startIndex)
        var sawChomp = false
        var sawIndent = false
        while index < trimmed.endIndex, !trimmed[index].isWhitespace {
            let character = trimmed[index]
            if (character == "+" || character == "-") && !sawChomp {
                sawChomp = true
                index = trimmed.index(after: index)
                continue
            }
            if character.isNumber && !sawIndent {
                if character == "0" {
                    return false
                }
                sawIndent = true
                index = trimmed.index(after: index)
                continue
            }
            return false
        }
        while index < trimmed.endIndex, trimmed[index].isWhitespace {
            index = trimmed.index(after: index)
        }
        if index == trimmed.endIndex {
            return true
        }
        return trimmed[index] == "#"
    }

    private func parseTagName(from content: Substring) -> String? {
        let trimmed = trimLeadingSpaces(content)
        guard trimmed.first == "!" else {
            return nil
        }
        var cursor = trimmed.startIndex
        while cursor < trimmed.endIndex, !trimmed[cursor].isWhitespace {
            cursor = trimmed.index(after: cursor)
        }
        let tag = trimmed[..<cursor]
        return tag.isEmpty ? nil : String(tag)
    }

    private func peekNonEmptyLine(_ cursor: LineCursor) -> Line? {
        var index = cursor.index
        while index < cursor.lines.count {
            let line = cursor.lines[index]
            let trimmed = trimLeadingSpaces(line.content)
            if trimmed.isEmpty || trimmed.first == "#" {
                index += 1
                continue
            }
            return line
        }
        return nil
    }

    private func advanceToNextNonEmptyLine(_ cursor: inout LineCursor) {
        while cursor.index < cursor.lines.count {
            let line = cursor.lines[cursor.index]
            let trimmed = trimLeadingSpaces(line.content)
            if trimmed.isEmpty || trimmed.first == "#" {
                cursor.index += 1
                continue
            }
            break
        }
    }

    private func parseBlockValue(_ cursor: inout LineCursor, indent: Int) throws -> YAMLValue {
        advanceToNextNonEmptyLine(&cursor)
        guard cursor.index < cursor.lines.count else {
            throw YAMLParseError.emptyDocument
        }
        let line = cursor.lines[cursor.index]
        if line.indent < indent {
            throw YAMLParseError.invalidBlockIndentation
        }
        if isBlockSequenceLine(line, indent: indent) {
            return try parseBlockSequence(&cursor, indent: indent)
        }
        if isBlockMappingLine(line, indent: indent) {
            return try parseBlockMapping(&cursor, indent: indent)
        }
        let inline = trimLeadingSpaces(line.content)
        if let anchor = anchorNameIfOnly(inline) {
            cursor.index += 1
            if let nestedIndent = nextNonEmptyIndent(cursor, minimum: indent) {
                return .anchored(anchor, try parseBlockValue(&cursor, indent: nestedIndent))
            }
            return .anchored(anchor, .null)
        }
        return try parsePlainScalar(&cursor, indent: indent)
    }

    private func parsePlainScalar(_ cursor: inout LineCursor, indent: Int) throws -> YAMLValue {
        guard cursor.index < cursor.lines.count else {
            throw YAMLParseError.emptyDocument
        }
        let line = cursor.lines[cursor.index]
        let trimmed = trimLeadingSpaces(line.content)
        cursor.index += 1
        return try parsePlainScalarContinuation(&cursor, indent: indent, initialLine: trimmed)
    }

    private func parsePlainScalarContinuation(
        _ cursor: inout LineCursor,
        indent: Int,
        initialLine: Substring
    ) throws -> YAMLValue {
        var lines: [String] = [String(initialLine)]
        while cursor.index < cursor.lines.count {
            let line = cursor.lines[cursor.index]
            let trimmed = trimLeadingSpaces(line.content)
            if line.indent < indent, !trimmed.isEmpty {
                break
            }
            if line.indent == indent {
                if isDocumentStartLine(trimmed) || isDirectiveLine(trimmed) {
                    break
                }
                if isBlockSequenceLine(line, indent: indent) || isBlockMappingLine(line, indent: indent) {
                    break
                }
            }
            if trimmed.first == "#" {
                break
            }
            if trimmed.isEmpty {
                lines.append("")
                cursor.index += 1
                continue
            }
            let extraIndent = max(0, line.indent - indent)
            let prefix = extraIndent > 0 ? String(repeating: " ", count: extraIndent) : ""
            lines.append(prefix + String(line.content))
            cursor.index += 1
        }
        let joined = lines.joined(separator: "\n")
        var folded = foldBlockScalar(joined)
        if folded.hasSuffix("\n") {
            folded.removeLast()
        }
        return .string(folded)
    }

    private func parseBlockSequence(_ cursor: inout LineCursor, indent: Int) throws -> YAMLValue {
        var elements: [YAMLValue] = []
        while cursor.index < cursor.lines.count {
            advanceToNextNonEmptyLine(&cursor)
            guard cursor.index < cursor.lines.count else {
                break
            }
            let line = cursor.lines[cursor.index]
            if line.indent < indent || !isBlockSequenceLine(line, indent: indent) {
                break
            }
            let content = trimLeadingSpaces(line.content)
            let afterDash = content.index(after: content.startIndex)
            let remainder = content[afterDash...]
            let value: YAMLValue
            if isOnlyWhitespace(remainder) {
                cursor.index += 1
                if let nestedIndent = nextNonEmptyIndent(cursor, minimum: indent + 1) {
                    value = try parseBlockValue(&cursor, indent: nestedIndent)
                } else {
                    value = .null
                }
            } else {
                let trimmedRemainder = trimLeadingSpaces(remainder)
                if let anchor = anchorNameIfOnly(trimmedRemainder) {
                    cursor.index += 1
                    if let nestedIndent = nextNonEmptyIndent(cursor, minimum: indent + 1) {
                        value = .anchored(anchor, try parseBlockValue(&cursor, indent: nestedIndent))
                    } else {
                        value = .anchored(anchor, .null)
                    }
                } else if let blockScalar = try parseInlineBlockScalar(&cursor, indent: indent, remainder: remainder) {
                    value = blockScalar
                } else if let inlinePair = try parseInlineMappingPair(remainder) {
                    var object: YAMLObject = [inlinePair.key: inlinePair.value]
                    cursor.index += 1
                    if let nestedIndent = nextNonEmptyIndent(cursor, minimum: indent + 1),
                       nestedIndent > indent,
                       cursor.index < cursor.lines.count,
                       isBlockMappingLine(cursor.lines[cursor.index], indent: nestedIndent) {
                        let additional = try parseBlockMappingEntries(&cursor, indent: nestedIndent)
                        for (key, value) in additional {
                            object[key] = value
                        }
                    }
                    value = .object(object)
                } else {
                    cursor.index += 1
                    value = try parseInlineValue(remainder)
                }
            }
            elements.append(value)
        }
        return .array(elements)
    }

    private func parseBlockMapping(_ cursor: inout LineCursor, indent: Int) throws -> YAMLValue {
        let object = try parseBlockMappingEntries(&cursor, indent: indent)
        return .object(object)
    }

    private func parseInlineValue(_ content: Substring) throws -> YAMLValue {
        var input = content[...]
        consumeWhitespaceAndComments(&input)
        if input.isEmpty {
            throw YAMLParseError.invalidScalar
        }
        if let first = input.first, first == "[" || first == "{" {
            let value = try parseValue(&input)
            consumeWhitespaceAndComments(&input)
            if !input.isEmpty {
                throw YAMLParseError.trailingCharacters
            }
            return value
        }
        if let first = input.first, first == "\"" || first == "'" {
            let style: YAMLStringStyle = first == "'" ? .singleQuoted : .doubleQuoted
            guard let string = parseQuotedString(&input) else {
                throw YAMLParseError.invalidScalar
            }
            consumeWhitespaceAndComments(&input)
            if !input.isEmpty {
                throw YAMLParseError.trailingCharacters
            }
            return .styledString(string, style)
        }
        let stripped = stripInlineComment(input)
        let trimmed = stripTrailingSpaces(stripped)
        if let first = trimmed.first, first == "|" || first == ">" {
            throw YAMLParseError.invalidScalar
        }
        if let first = trimmed.first, first == "&" {
            var anchoredInput = trimmed[...]
            if let anchored = try parseAnchoredInline(&anchoredInput) {
                return anchored
            }
        }
        if trimmed.contains(where: { $0.isWhitespace }) {
            return .string(String(trimmed))
        }
        var temp = trimmed[...]
        let value = try parseScalar(&temp)
        consumeWhitespaceAndComments(&temp)
        if !temp.isEmpty {
            throw YAMLParseError.trailingCharacters
        }
        if case .string = value,
           let numericInfo = numericLikeInfo(trimmed),
           numericInfo.dotCount <= 1 {
            throw YAMLParseError.invalidScalar
        }
        return value
    }

    private func parseInlineKey(_ content: Substring) throws -> YAMLKey {
        var input = content[...]
        consumeWhitespaceAndComments(&input)
        if input.isEmpty {
            return YAMLKey(rawValue: "", style: .plain, anchor: nil)
        }
        if let (anchor, remainder) = parseAnchorPrefix(input) {
            input = remainder
            if input.first == ":" {
                input = input.dropFirst()
            }
            consumeWhitespaceAndComments(&input)
            let key = try parseInlineKey(input)
            return YAMLKey(rawValue: key.rawValue, style: key.style, anchor: anchor)
        }
        if let first = input.first, first == "\"" || first == "'" {
            guard let string = parseQuotedString(&input) else {
                throw YAMLParseError.invalidScalar
            }
            consumeWhitespaceAndComments(&input)
            if !input.isEmpty {
                throw YAMLParseError.trailingCharacters
            }
            let style: YAMLKey.Style = first == "'" ? .singleQuoted : .doubleQuoted
            return YAMLKey(rawValue: string, style: style, anchor: nil)
        }
        let trimmed = stripTrailingSpaces(input)
        guard !trimmed.isEmpty else {
            throw YAMLParseError.invalidScalar
        }
        return YAMLKey(rawValue: String(trimmed), style: .plain, anchor: nil)
    }

    private func parseKeyScalar(_ input: inout Substring) throws -> YAMLKey {
        if let (anchor, remainder) = parseAnchorPrefix(input) {
            input = remainder
            if input.first == ":" {
                input = input.dropFirst()
            }
            consumeWhitespaceAndComments(&input)
            let key = try parseKeyScalar(&input)
            return YAMLKey(rawValue: key.rawValue, style: key.style, anchor: anchor)
        }
        if let first = input.first, first == "\"" || first == "'" {
            guard let string = parseQuotedString(&input) else {
                throw YAMLParseError.invalidScalar
            }
            let style: YAMLKey.Style = first == "'" ? .singleQuoted : .doubleQuoted
            return YAMLKey(rawValue: string, style: style, anchor: nil)
        }
        var cursor = input.startIndex
        while cursor < input.endIndex, input[cursor] != ":" {
            cursor = input.index(after: cursor)
        }
        if cursor == input.startIndex {
            input = input[cursor...]
            return YAMLKey(rawValue: "", style: .plain, anchor: nil)
        }
        let keyPart = stripTrailingSpaces(input[..<cursor])
        guard !keyPart.isEmpty else {
            throw YAMLParseError.nonStringKey
        }
        var scalarInput = keyPart[...]
        let scalarValue = try parseScalar(&scalarInput)
        if scalarInput.isEmpty {
            switch scalarValue {
            case .string, .styledString:
                break
            default:
                throw YAMLParseError.nonStringKey
            }
        }
        input = input[cursor...]
        return YAMLKey(rawValue: String(keyPart), style: .plain, anchor: nil)
    }

    private func parseAnchorPrefix(_ input: Substring) -> (String, Substring)? {
        let trimmed = trimLeadingSpaces(input)
        guard trimmed.first == "&" else {
            return nil
        }
        var cursor = trimmed.index(after: trimmed.startIndex)
        let start = cursor
        while cursor < trimmed.endIndex, !trimmed[cursor].isWhitespace {
            cursor = trimmed.index(after: cursor)
        }
        guard cursor > start else {
            return nil
        }
        let anchor = String(trimmed[start..<cursor])
        let remainder = trimmed[cursor...]
        return (anchor, remainder)
    }

    private func trimLeadingSpaces(_ input: Substring) -> Substring {
        var cursor = input.startIndex
        while cursor < input.endIndex, input[cursor] == " " {
            cursor = input.index(after: cursor)
        }
        return input[cursor...]
    }

    private func stripTrailingSpaces(_ input: Substring) -> Substring {
        var end = input.endIndex
        while end > input.startIndex {
            let before = input.index(before: end)
            if input[before] == " " || input[before] == "\t" {
                end = before
                continue
            }
            break
        }
        return input[..<end]
    }

    private func stripInlineComment(_ input: Substring) -> Substring {
        var index = input.startIndex
        var previousWasWhitespace = false
        while index < input.endIndex {
            let character = input[index]
            if character == "#" && previousWasWhitespace {
                return input[..<index]
            }
            previousWasWhitespace = character.isWhitespace
            index = input.index(after: index)
        }
        return input
    }

    private func isOnlyWhitespace(_ input: Substring) -> Bool {
        var cursor = input.startIndex
        while cursor < input.endIndex {
            if !input[cursor].isWhitespace {
                return false
            }
            cursor = input.index(after: cursor)
        }
        return true
    }

    private func anchorNameIfOnly(_ input: Substring) -> String? {
        let trimmed = trimLeadingSpaces(input)
        guard trimmed.first == "&" else {
            return nil
        }
        var cursor = trimmed.index(after: trimmed.startIndex)
        if cursor >= trimmed.endIndex {
            return nil
        }
        let start = cursor
        while cursor < trimmed.endIndex, !trimmed[cursor].isWhitespace {
            cursor = trimmed.index(after: cursor)
        }
        guard cursor > start else {
            return nil
        }
        let anchor = String(trimmed[start..<cursor])
        return isOnlyWhitespace(trimmed[cursor...]) ? anchor : nil
    }

    private func numericLikeInfo(_ input: Substring) -> (dotCount: Int, digitCount: Int)? {
        var dotCount = 0
        var digitCount = 0
        var index = input.startIndex
        while index < input.endIndex {
            let character = input[index]
            if character == "." {
                dotCount += 1
            } else if character == "-" {
                if index != input.startIndex {
                    return nil
                }
            } else if character.isNumber {
                digitCount += 1
            } else {
                return nil
            }
            index = input.index(after: index)
        }
        return digitCount > 0 ? (dotCount, digitCount) : nil
    }

    private func parseInlineMappingPair(_ content: Substring) throws -> (key: YAMLKey, value: YAMLValue)? {
        let trimmed = trimLeadingSpaces(content)
        if trimmed.first == "[" || trimmed.first == "{" {
            return nil
        }
        guard let colonIndex = mappingSeparatorIndex(in: trimmed) else {
            return nil
        }
        let afterColon = trimmed.index(after: colonIndex)
        let keyPart = trimmed[..<colonIndex]
        let valuePart = trimmed[afterColon...]
        let key = try parseInlineKey(keyPart)
        let value: YAMLValue
        if isOnlyWhitespace(valuePart) {
            value = .null
        } else {
            value = try parseInlineValue(valuePart)
        }
        return (key, value)
    }

    private func parseInlineBlockScalar(
        _ cursor: inout LineCursor,
        indent: Int,
        remainder: Substring
    ) throws -> YAMLValue? {
        let trimmed = trimLeadingSpaces(remainder)
        guard let style = trimmed.first, style == "|" || style == ">" else {
            return nil
        }
        var index = trimmed.index(after: trimmed.startIndex)
        var chompingIndicator: Character?
        var indentIndicator: Int?
        while index < trimmed.endIndex {
            let character = trimmed[index]
            if (character == "+" || character == "-") && chompingIndicator == nil {
                chompingIndicator = character
                index = trimmed.index(after: index)
                continue
            }
            if character.isNumber, indentIndicator == nil {
                if character == "0" {
                    return nil
                }
                indentIndicator = Int(String(character))
                index = trimmed.index(after: index)
                continue
            }
            break
        }
        let rest = trimmed[index...]
        if let first = rest.first, !first.isWhitespace, first != "#" {
            return nil
        }
        _ = chompingIndicator
        cursor.index += 1
        let scalarIndent: Int
        if let indentIndicator {
            scalarIndent = indent + indentIndicator
        } else {
            scalarIndent = nextNonEmptyIndent(cursor, minimum: indent + 1) ?? (indent + 1)
        }
        let content = collectBlockScalarLines(&cursor, indent: scalarIndent)
        let stringStyle: YAMLStringStyle = style == "|" ? .literalBlock : .foldedBlock
        return .styledString(content, stringStyle)
    }

    private func collectBlockScalarLines(_ cursor: inout LineCursor, indent: Int) -> String {
        var lines: [String] = []
        while cursor.index < cursor.lines.count {
            let line = cursor.lines[cursor.index]
            if line.indent < indent {
                if line.content.isEmpty {
                    if cursor.index == cursor.lines.count - 1 {
                        break
                    } else {
                        lines.append("")
                        cursor.index += 1
                        continue
                    }
                }
                break
            }
            var slice = line.content[...]
            let extraIndent = max(0, line.indent - indent)
            if extraIndent > 0 {
                var dropped = 0
                var cursorIndex = slice.startIndex
                while cursorIndex < slice.endIndex, dropped < extraIndent, slice[cursorIndex] == " " {
                    dropped += 1
                    cursorIndex = slice.index(after: cursorIndex)
                }
                slice = slice[cursorIndex...]
            }
            lines.append(String(slice))
            cursor.index += 1
        }
        let joined = lines.joined(separator: "\n")
        guard !joined.isEmpty else {
            return ""
        }
        if joined.hasSuffix("\n") {
            return joined
        }
        return joined + "\n"
    }

    private func foldBlockScalar(_ value: String) -> String {
        let parts = value.split(separator: "\n", omittingEmptySubsequences: false)
        var result = ""
        for index in parts.indices {
            let line = parts[index]
            if index == parts.startIndex {
                result.append(contentsOf: line)
                continue
            }
            if line.isEmpty {
                result.append("\n")
            } else {
                if !result.isEmpty, result.last != "\n" {
                    result.append(" ")
                }
                result.append(contentsOf: line)
            }
        }
        if !result.hasSuffix("\n") {
            result.append("\n")
        }
        return result
    }

    private func parseBlockMappingEntries(_ cursor: inout LineCursor, indent: Int) throws -> YAMLObject {
        var object: YAMLObject = [:]
        while cursor.index < cursor.lines.count {
            advanceToNextNonEmptyLine(&cursor)
            guard cursor.index < cursor.lines.count else {
                break
            }
            let line = cursor.lines[cursor.index]
            if line.indent < indent || !isBlockMappingLine(line, indent: indent) {
                break
            }
            let content = trimLeadingSpaces(line.content)
            if let first = content.first, first == "?" {
                let after = content.index(after: content.startIndex)
                if after == content.endIndex || content[after].isWhitespace {
                    let keyPart = trimLeadingSpaces(content[after...])
                    let key = keyPart.isEmpty ? YAMLKey(rawValue: "", style: .plain, anchor: nil) : try parseInlineKey(keyPart)
                    cursor.index += 1
                    advanceToNextNonEmptyLine(&cursor)
                    if cursor.index < cursor.lines.count {
                        let valueLine = cursor.lines[cursor.index]
                        if valueLine.indent == indent {
                            let valueContent = trimLeadingSpaces(valueLine.content)
                            if valueContent.first == ":" {
                                let valuePart = valueContent[valueContent.index(after: valueContent.startIndex)...]
                                let value = try parseExplicitValuePart(&cursor, indent: indent, valuePart: valuePart)
                                object[key] = value
                                continue
                            }
                        }
                    }
                    object[key] = .null
                    continue
                }
            }
            guard let colonIndex = mappingSeparatorIndex(in: content) else {
                throw YAMLParseError.expectedMappingSeparator
            }
            let keyPart = content[..<colonIndex]
            let valuePart = content[content.index(after: colonIndex)...]
            let key = try parseInlineKey(keyPart)
            let value: YAMLValue
            let trimmedValue = trimLeadingSpaces(valuePart)
            if let anchor = anchorNameIfOnly(trimmedValue) {
                cursor.index += 1
                if let nestedIndent = nextNonEmptyIndent(cursor, minimum: indent + 1) {
                    value = .anchored(anchor, try parseBlockValue(&cursor, indent: nestedIndent))
                } else {
                    value = .anchored(anchor, .null)
                }
            } else if isOnlyWhitespace(valuePart) {
                cursor.index += 1
                if let nestedIndent = nextNonEmptyIndent(cursor, minimum: indent + 1) {
                    value = try parseBlockValue(&cursor, indent: nestedIndent)
                } else {
                    value = .null
                }
            } else {
                if let blockScalar = try parseInlineBlockScalar(&cursor, indent: indent, remainder: valuePart) {
                    value = blockScalar
                } else {
                    var lookahead = cursor
                    lookahead.index += 1
                    if let nextIndent = nextNonEmptyIndent(lookahead, minimum: indent + 1), nextIndent > indent {
                        let initial = trimLeadingSpaces(valuePart)
                        cursor.index += 1
                        value = try parsePlainScalarContinuation(&cursor, indent: indent, initialLine: initial)
                    } else {
                        cursor.index += 1
                        value = try parseInlineValue(valuePart)
                    }
                }
            }
            object[key] = value
        }
        return object
    }

    private func parseExplicitValuePart(
        _ cursor: inout LineCursor,
        indent: Int,
        valuePart: Substring
    ) throws -> YAMLValue {
        let trimmedValue = trimLeadingSpaces(valuePart)
        if let anchor = anchorNameIfOnly(trimmedValue) {
            cursor.index += 1
            if let nestedIndent = nextNonEmptyIndent(cursor, minimum: indent + 1) {
                return .anchored(anchor, try parseBlockValue(&cursor, indent: nestedIndent))
            }
            return .anchored(anchor, .null)
        }
        if isOnlyWhitespace(valuePart) {
            cursor.index += 1
            if let nestedIndent = nextNonEmptyIndent(cursor, minimum: indent + 1) {
                return try parseBlockValue(&cursor, indent: nestedIndent)
            }
            return .null
        }
        if let blockScalar = try parseInlineBlockScalar(&cursor, indent: indent, remainder: valuePart) {
            return blockScalar
        }
        cursor.index += 1
        return try parseInlineValue(valuePart)
    }

    private func nextNonEmptyIndent(_ cursor: LineCursor, minimum: Int) -> Int? {
        var index = cursor.index
        while index < cursor.lines.count {
            let line = cursor.lines[index]
            let trimmed = trimLeadingSpaces(line.content)
            if trimmed.isEmpty || trimmed.first == "#" {
                index += 1
                continue
            }
            return line.indent >= minimum ? line.indent : nil
        }
        return nil
    }

    private func isBlockSequenceLine(_ line: Line, indent: Int) -> Bool {
        guard line.indent == indent else {
            return false
        }
        let content = trimLeadingSpaces(line.content)
        guard content.first == "-" else {
            return false
        }
        let afterDash = content.index(after: content.startIndex)
        return afterDash == content.endIndex || content[afterDash].isWhitespace
    }

    private func isBlockMappingLine(_ line: Line, indent: Int) -> Bool {
        guard line.indent == indent else {
            return false
        }
        let content = trimLeadingSpaces(line.content)
        if content.first == "[" || content.first == "{" {
            return false
        }
        if let first = content.first, first == "?" {
            let after = content.index(after: content.startIndex)
            if after == content.endIndex || content[after].isWhitespace {
                return true
            }
        }
        guard let colonIndex = mappingSeparatorIndex(in: content) else {
            return false
        }
        let afterColon = content.index(after: colonIndex)
        return afterColon == content.endIndex || content[afterColon].isWhitespace
    }

    private func mappingSeparatorIndex(in content: Substring) -> String.Index? {
        var startIndex = content.startIndex
        if content.first == "&" {
            var cursor = content.index(after: content.startIndex)
            while cursor < content.endIndex, !content[cursor].isWhitespace, content[cursor] != ":" {
                cursor = content.index(after: cursor)
            }
            if cursor < content.endIndex, content[cursor] == ":" {
                let after = content.index(after: cursor)
                if after == content.endIndex || content[after].isWhitespace {
                    var lookahead = after
                    while lookahead < content.endIndex, content[lookahead].isWhitespace {
                        lookahead = content.index(after: lookahead)
                    }
                    startIndex = lookahead
                }
            }
        }
        var index = startIndex
        while index < content.endIndex {
            if content[index] == ":" {
                let after = content.index(after: index)
                if after == content.endIndex || content[after].isWhitespace {
                    return index
                }
            }
            index = content.index(after: index)
        }
        return nil
    }
}
