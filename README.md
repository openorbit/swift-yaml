# YAMLKit

A native YAML 1.2 implementation in Swift with Codable support.

Repository: https://github.com/openorbit/swift-yaml

## Features

- YAML 1.2 scalar parsing (null, booleans, integers, doubles, strings)
- Flow collections (`[a, b]`, `{a: 1}`)
- Block collections (indentation-based sequences and mappings)
- Block scalars (`|` literal, `>` folded)
- Native `YAMLValue` tree for direct inspection
- Codable bridging with `YAMLEncoder` and `YAMLDecoder`

## Usage

### Parse YAML

```swift
import YAMLKit

let parser = YAMLParser()
let value = try parser.parse("""
name: Ava
age: 32
isAdmin: true
""")

print(value["name"]?.stringValue ?? "")
```

### Work with YAMLValue

```swift
let config: YAMLValue = [
    "server": [
        "host": "localhost",
        "port": 8080
    ],
    "features": ["alpha", "beta"]
]

if let port = config["server"]?["port"]?.intValue {
    print(port)
}
```

### Codable

```swift
struct Person: Codable {
    let name: String
    let age: Int
    let isAdmin: Bool
}

let encoder = YAMLEncoder()
let decoder = YAMLDecoder()

let yamlValue = try encoder.encode(Person(name: "Ava", age: 32, isAdmin: true))
let person = try decoder.decode(Person.self, from: yamlValue)
```

### Decode from String

```swift
let decoder = YAMLDecoder()
let person = try decoder.decode(Person.self, from: """
name: Ava
age: 32
isAdmin: true
""")
```

### Serialize YAML

```swift
let serializer = YAMLSerializer()
let yamlString = serializer.serialize(["a": 1, "b": [2, 3]])
print(yamlString)
```

### Encode to String

```swift
let encoder = YAMLEncoder()
let yamlString = try encoder.encodeToString(Person(name: "Ava", age: 32, isAdmin: true))
print(yamlString)
```

## Status

YAMLKit is under active development. The current implementation focuses on correctness and clarity for core YAML 1.2 structures before adding the full conformance suite.
