// YAMLKit
//
// SPDX-License-Identifier: Apache-2.0
//
// Copyright (c) 2026 YAMLKit contributors
//
// Native YAML 1.2 implementation in Swift.

import Foundation
import OrderedCollections

public typealias YAMLObject = OrderedDictionary<String, YAMLValue>
public typealias YAMLArray = [YAMLValue]

public enum YAMLValue: Equatable, Sendable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array(YAMLArray)
    case object(YAMLObject)

    public subscript(key: String) -> YAMLValue? {
        guard case .object(let object) = self else {
            return nil
        }
        return object[key]
    }

    public subscript(index: Int) -> YAMLValue? {
        guard case .array(let array) = self, array.indices.contains(index) else {
            return nil
        }
        return array[index]
    }

    public var stringValue: String? {
        guard case .string(let value) = self else {
            return nil
        }
        return value
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
            object[key] = value
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
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
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
        case .array(let array):
            return serializeArray(array, indent: indent)
        case .object(let object):
            return serializeObject(object, indent: indent, allowFlow: allowFlow)
        }
    }

    private func serializeArray(_ array: [YAMLValue], indent: Int) -> String {
        guard !array.isEmpty else {
            return "[]"
        }
        let prefix = String(repeating: " ", count: indent)
        let childIndent = indent + 2
        return array.map { value in
            if isSimpleScalar(value) {
                return "\(prefix)- \(serializeValue(value, indent: childIndent, allowFlow: false))"
            }
            if case .string(let string) = value, string.contains("\n") {
                return serializeMultilineStringInSequence(string, indent: indent)
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
            return isSimpleScalar(value) && isBareKey(key)
        })
        if canFlow {
            let pairs = keys.map { key in
                "\(key): \(serializeValue(object[key]!, indent: indent, allowFlow: false))"
            }.joined(separator: ", ")
            return "{\(pairs)}"
        }
        let prefix = String(repeating: " ", count: indent)
        let childIndent = indent + 2
        return keys.map { key in
            let value = object[key]!
            let keyText = isBareKey(key) ? key : serializeString(key, indent: indent)
            if isSimpleScalar(value) {
                return "\(prefix)\(keyText): \(serializeValue(value, indent: childIndent, allowFlow: false))"
            }
            let nested = serializeValue(value, indent: childIndent, allowFlow: false)
            return "\(prefix)\(keyText):\n\(indentLines(nested, indent: childIndent))"
        }.joined(separator: "\n")
    }

    private func serializeString(_ string: String, indent: Int) -> String {
        if string.contains("\n") {
            let prefix = String(repeating: " ", count: indent)
            let indented = string
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map { "\(prefix)  \($0)" }
                .joined(separator: "\n")
            return "|\n\(indented)"
        }
        if isBareString(string) {
            return string
        }
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

    private func serializeMultilineStringInSequence(_ string: String, indent: Int) -> String {
        let prefix = String(repeating: " ", count: indent)
        let childIndent = String(repeating: " ", count: indent + 2)
        let indented = string
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { "\(childIndent)\($0)" }
            .joined(separator: "\n")
        return "\(prefix)- |\n\(indented)"
    }

    private func isSimpleScalar(_ value: YAMLValue) -> Bool {
        switch value {
        case .null, .bool, .int, .double:
            return true
        case .string(let string):
            return !string.contains("\n")
        case .array, .object:
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

    private func isBareKey(_ key: String) -> Bool {
        isBareString(key)
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
    var allKeys: [Key] { object.keys.compactMap { Key(stringValue: $0) } }

    func contains(_ key: Key) -> Bool {
        object[key.stringValue] != nil
    }

    func decodeNil(forKey key: Key) throws -> Bool {
        guard let value = object[key.stringValue] else { return true }
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
        guard let value = object[key.stringValue] else {
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
        object[key.stringValue] = .null
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
        object[key.stringValue] = encoded
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
        object[key.stringValue] = value
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
        guard !input.isEmpty else {
            throw YAMLParseError.emptyDocument
        }
        let value = try parseValue(&input)
        consumeWhitespaceAndComments(&input)
        if !input.isEmpty {
            throw YAMLParseError.trailingCharacters
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
                guard let string = parseQuotedString(&input) else {
                    throw YAMLParseError.invalidScalar
                }
                return .string(string)
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
        if let string = parseBareString(&input) {
            return .string(string)
        }
        throw YAMLParseError.invalidScalar
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
            let keyValue = try parseScalar(&input)
            guard case .string(let key) = keyValue else {
                throw YAMLParseError.nonStringKey
            }
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
        guard let first = peekNonEmptyLine(cursor) else {
            return nil
        }
        if isBlockSequenceLine(first, indent: first.indent) || isBlockMappingLine(first, indent: first.indent) {
            let value = try parseBlockValue(&cursor, indent: first.indent)
            advanceToNextNonEmptyLine(&cursor)
            if cursor.index < cursor.lines.count {
                throw YAMLParseError.trailingCharacters
            }
            return value
        }
        return nil
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
        cursor.index += 1
        return try parseInlineValue(inline)
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
                if let blockScalar = try parseInlineBlockScalar(&cursor, indent: indent, remainder: remainder) {
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
        guard !input.isEmpty else {
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
            guard let string = parseQuotedString(&input) else {
                throw YAMLParseError.invalidScalar
            }
            consumeWhitespaceAndComments(&input)
            if !input.isEmpty {
                throw YAMLParseError.trailingCharacters
            }
            return .string(string)
        }
        let stripped = stripInlineComment(input)
        let trimmed = stripTrailingSpaces(stripped)
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

    private func isAnchorOnly(_ input: Substring) -> Bool {
        let trimmed = trimLeadingSpaces(input)
        guard let first = trimmed.first, first == "&" || first == "*" else {
            return false
        }
        var cursor = trimmed.index(after: trimmed.startIndex)
        if cursor >= trimmed.endIndex {
            return false
        }
        while cursor < trimmed.endIndex, !trimmed[cursor].isWhitespace {
            cursor = trimmed.index(after: cursor)
        }
        return isOnlyWhitespace(trimmed[cursor...])
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

    private func parseInlineMappingPair(_ content: Substring) throws -> (key: String, value: YAMLValue)? {
        let trimmed = trimLeadingSpaces(content)
        if trimmed.first == "[" || trimmed.first == "{" {
            return nil
        }
        guard let colonIndex = trimmed.firstIndex(of: ":") else {
            return nil
        }
        let afterColon = trimmed.index(after: colonIndex)
        if afterColon < trimmed.endIndex, !trimmed[afterColon].isWhitespace {
            return nil
        }
        let keyPart = trimmed[..<colonIndex]
        let valuePart = trimmed[afterColon...]
        let keyValue = try parseInlineValue(keyPart)
        guard case .string(let key) = keyValue else {
            throw YAMLParseError.nonStringKey
        }
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
        let afterStyle = trimmed.index(after: trimmed.startIndex)
        if afterStyle < trimmed.endIndex, !trimmed[afterStyle].isWhitespace {
            return nil
        }
        cursor.index += 1
        let scalarIndent = nextNonEmptyIndent(cursor, minimum: indent + 1) ?? (indent + 1)
        let content = collectBlockScalarLines(&cursor, indent: scalarIndent)
        let value = style == "|" ? content : foldBlockScalar(content)
        return .string(value)
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
            guard let colonIndex = content.firstIndex(of: ":") else {
                throw YAMLParseError.expectedMappingSeparator
            }
            let keyPart = content[..<colonIndex]
            let valuePart = content[content.index(after: colonIndex)...]
            let keyValue = try parseInlineValue(keyPart)
            guard case .string(let key) = keyValue else {
                throw YAMLParseError.nonStringKey
            }
            let value: YAMLValue
            let trimmedValue = trimLeadingSpaces(valuePart)
            if isOnlyWhitespace(valuePart) || isAnchorOnly(trimmedValue) {
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
                    cursor.index += 1
                    value = try parseInlineValue(valuePart)
                }
            }
            object[key] = value
        }
        return object
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
        guard let colonIndex = content.firstIndex(of: ":") else {
            return false
        }
        let afterColon = content.index(after: colonIndex)
        return afterColon == content.endIndex || content[afterColon].isWhitespace
    }
}
