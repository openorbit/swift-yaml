// YAMLTestSuiteTests
//
// SPDX-License-Identifier: Apache-2.0
//
// Copyright (c) 2026 YAMLKit contributors

import Foundation
import Testing
@testable import YAMLKit

struct YAMLTestSuiteTests {
    @Test func runsYamlTestSuite() throws {
        let dataURL = try resourceURL(named: "data")
        let cases = try discoverTestCases(root: dataURL)
        #expect(!cases.isEmpty)

        var failures: [String] = []
        for testCase in cases {
            if let failure = run(testCase: testCase) {
                failures.append(failure)
            }
        }

        if !failures.isEmpty {
            for failure in failures.prefix(20) {
                print(failure)
            }
        }
        let summary = failures.prefix(20).joined(separator: "\n")
        #expect(failures.isEmpty, "YAMLTestSuite failures (showing up to 20):\n\(summary)")
    }

    private func run(testCase: YAMLTestCase) -> String? {
        let parser = YAMLParser()
        let serializer = YAMLSerializer()

        if testCase.expectsError {
            do {
                _ = try parser.parse(testCase.input)
                return "\(testCase.identifier): expected error, but parsing succeeded"
            } catch {
                return nil
            }
        }

        let parsed: YAMLValue
        do {
            parsed = try parser.parse(testCase.input)
        } catch {
            return "\(testCase.identifier): parse error \(error)"
        }

        if let expectedOutput = testCase.expectedOutput {
            let actualOutput = serializer.serialize(parsed)
            let normalizedActual = normalizeOutput(actualOutput)
            let normalizedExpected = normalizeOutput(expectedOutput)
            if normalizedActual != normalizedExpected {
                return "\(testCase.identifier): output mismatch\nexpected: \(truncate(normalizedExpected))\nactual: \(truncate(normalizedActual))"
            }
        }

        return nil
    }
}

private struct YAMLTestCase: Sendable {
    let identifier: String
    let input: String
    let expectedOutput: String?
    let expectsError: Bool
}

private func resourceURL(named name: String) throws -> URL {
    guard let url = Bundle.module.resourceURL?.appendingPathComponent(name) else {
        throw ResourceError.missingResource(name)
    }
    return url
}

private func discoverTestCases(root: URL) throws -> [YAMLTestCase] {
    let manager = FileManager.default
    guard let enumerator = manager.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey]) else {
        return []
    }

    var cases: [YAMLTestCase] = []
    for case let url as URL in enumerator {
        if url.lastPathComponent == "in.yaml" {
            let directory = url.deletingLastPathComponent()
            let identifier = relativeIdentifier(for: directory, root: root)
            let input = try String(contentsOf: url, encoding: .utf8)

            let errorURL = directory.appendingPathComponent("error")
            let expectsError = manager.fileExists(atPath: errorURL.path)

            let outURL = directory.appendingPathComponent("out.yaml")
            let expectedOutput = manager.fileExists(atPath: outURL.path)
                ? try String(contentsOf: outURL, encoding: .utf8)
                : nil

            cases.append(
                YAMLTestCase(
                    identifier: identifier,
                    input: input,
                    expectedOutput: expectedOutput,
                    expectsError: expectsError
                )
            )
        }
    }

    return cases.sorted { $0.identifier < $1.identifier }
}

private func normalizeOutput(_ value: String) -> String {
    var normalized = value.replacingOccurrences(of: "\r\n", with: "\n")
    normalized = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
    return normalized + "\n"
}

private func truncate(_ value: String, limit: Int = 200) -> String {
    if value.count <= limit {
        return value
    }
    let index = value.index(value.startIndex, offsetBy: limit)
    return String(value[..<index]) + "…"
}

private func relativeIdentifier(for directory: URL, root: URL) -> String {
    let rootPath = root.standardizedFileURL.path
    let dirPath = directory.standardizedFileURL.path
    if dirPath.hasPrefix(rootPath) {
        var trimmed = dirPath.dropFirst(rootPath.count)
        if trimmed.hasPrefix("/") {
            trimmed = trimmed.dropFirst()
        }
        return String(trimmed)
    }
    return directory.lastPathComponent
}

private enum ResourceError: Error {
    case missingResource(String)
}
