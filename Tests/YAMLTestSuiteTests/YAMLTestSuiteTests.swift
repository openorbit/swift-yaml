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
        let dataURL = try resourceURL(named: "YAMLTestSuite/data")
        let cases = try discoverTestCases(root: dataURL)
        #expect(!cases.isEmpty)

        for testCase in cases {
            try run(testCase: testCase)
        }
    }

    private func run(testCase: YAMLTestCase) throws {
        let parser = YAMLParser()
        let serializer = YAMLSerializer()

        if testCase.expectsError {
            #expect(throws: Error.self) {
                _ = try parser.parse(testCase.input)
            }
            return
        }

        let parsed = try parser.parse(testCase.input)

        if let expectedOutput = testCase.expectedOutput {
            let actualOutput = serializer.serialize(parsed)
            let normalizedActual = normalizeOutput(actualOutput)
            let normalizedExpected = normalizeOutput(expectedOutput)
            #expect(normalizedActual == normalizedExpected)
        }
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
            let identifier = directory.lastPathComponent
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

private enum ResourceError: Error {
    case missingResource(String)
}
