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

        let results = cases.map { run(testCase: $0) }
        let reportURL = try writeHTMLReport(results: results)

        let failures = results.filter { !$0.passed }
        if !failures.isEmpty {
            for failure in failures.prefix(20) {
                print(failure.summaryLine)
            }
        }

        let summary = failures.prefix(20).map { $0.summaryLine }.joined(separator: "\n")
        let allowFailures = shouldAllowFailures()
        if allowFailures {
            print("YAMLTestSuite report: \(reportURL.path)")
        }
        #expect(allowFailures || failures.isEmpty, "YAMLTestSuite failures (showing up to 20):\n\(summary)\nReport: \(reportURL.path)")
    }

    private func run(testCase: YAMLTestCase) -> YAMLTestResult {
        let parser = YAMLParser()
        let serializer = YAMLSerializer()

        if testCase.expectsError {
            do {
                _ = try parser.parse(testCase.input)
                return YAMLTestResult(
                    identifier: testCase.identifier,
                    description: testCase.description,
                    passed: false,
                    message: "expected error, but parsing succeeded"
                )
            } catch {
                return YAMLTestResult(
                    identifier: testCase.identifier,
                    description: testCase.description,
                    passed: true,
                    message: ""
                )
            }
        }

        let parsed: YAMLValue
        do {
            parsed = try parser.parse(testCase.input)
        } catch {
            return YAMLTestResult(
                identifier: testCase.identifier,
                description: testCase.description,
                passed: false,
                message: "parse error \(error)"
            )
        }

        if let expectedOutput = testCase.expectedOutput {
            let actualOutput = serializer.serialize(parsed)
            let normalizedActual = normalizeOutput(actualOutput)
            let normalizedExpected = normalizeOutput(expectedOutput)
            if normalizedActual != normalizedExpected {
                return YAMLTestResult(
                    identifier: testCase.identifier,
                    description: testCase.description,
                    passed: false,
                    message: "output mismatch\nexpected: \(truncate(normalizedExpected))\nactual: \(truncate(normalizedActual))"
                )
            }
        }

        return YAMLTestResult(
            identifier: testCase.identifier,
            description: testCase.description,
            passed: true,
            message: ""
        )
    }
}

private struct YAMLTestCase: Sendable {
    let identifier: String
    let description: String
    let input: String
    let expectedOutput: String?
    let expectsError: Bool
}

private struct YAMLTestResult: Sendable {
    let identifier: String
    let description: String
    let passed: Bool
    let message: String

    var statusText: String {
        passed ? "PASS" : "FAIL"
    }

    var summaryLine: String {
        passed ? "\(identifier): pass" : "\(identifier): \(message)"
    }
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

            let descriptionURL = directory.appendingPathComponent("===")
            let description = manager.fileExists(atPath: descriptionURL.path)
                ? (try String(contentsOf: descriptionURL, encoding: .utf8)).trimmingCharacters(in: .whitespacesAndNewlines)
                : ""

            cases.append(
                YAMLTestCase(
                    identifier: identifier,
                    description: description,
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

private func shouldAllowFailures() -> Bool {
    let environment = ProcessInfo.processInfo.environment
    if environment["YAML_TEST_SUITE_ALLOW_FAILURES"] == "1" {
        return true
    }
    if environment["YAML_TEST_SUITE_NOFAIL"] == "1" {
        return true
    }
    return false
}

private func writeHTMLReport(results: [YAMLTestResult]) throws -> URL {
    let reportPath = ProcessInfo.processInfo.environment["YAML_TEST_SUITE_REPORT_PATH"]
    let outputURL: URL
    if let reportPath, !reportPath.isEmpty {
        outputURL = URL(fileURLWithPath: reportPath)
    } else {
        let filename = "yaml-test-suite-report.html"
        outputURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(filename)
    }

    let passedCount = results.filter { $0.passed }.count
    let failedCount = results.count - passedCount
    var rows: [String] = []
    rows.reserveCapacity(results.count)

    for result in results {
        let statusClass = result.passed ? "pass" : "fail"
        let description = result.description.isEmpty ? "" : escapeHTML(result.description)
        let message = result.message.isEmpty ? "" : escapeHTML(result.message)
        rows.append(
            "<tr class=\"\(statusClass)\">" +
            "<td>\(escapeHTML(result.identifier))</td>" +
            "<td>\(result.statusText)</td>" +
            "<td><pre>\(description)</pre></td>" +
            "<td><pre>\(message)</pre></td>" +
            "</tr>"
        )
    }

    let html = """
    <!doctype html>
    <html lang=\"en\">
    <head>
      <meta charset=\"utf-8\">
      <title>YAML Test Suite Report</title>
      <style>
        body { font-family: -apple-system, Helvetica, Arial, sans-serif; margin: 24px; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; vertical-align: top; }
        th { background: #f5f5f5; text-align: left; }
        tr.pass { background: #f6ffed; }
        tr.fail { background: #fff1f0; }
        pre { white-space: pre-wrap; margin: 0; }
      </style>
    </head>
    <body>
      <h1>YAML Test Suite Report</h1>
      <p>Passed: \(passedCount) · Failed: \(failedCount) · Total: \(results.count)</p>
      <table>
        <thead>
          <tr>
            <th>Case</th>
            <th>Status</th>
            <th>Description (===)</th>
            <th>Message</th>
          </tr>
        </thead>
        <tbody>
          \(rows.joined(separator: "\n"))
        </tbody>
      </table>
    </body>
    </html>
    """

    try html.write(to: outputURL, atomically: true, encoding: .utf8)
    return outputURL
}

private func escapeHTML(_ value: String) -> String {
    var escaped = value
    escaped = escaped.replacingOccurrences(of: "&", with: "&amp;")
    escaped = escaped.replacingOccurrences(of: "<", with: "&lt;")
    escaped = escaped.replacingOccurrences(of: ">", with: "&gt;")
    return escaped
}

private enum ResourceError: Error {
    case missingResource(String)
}
