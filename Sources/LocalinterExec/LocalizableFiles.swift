//
//  LocalizableFiles.swift
//
//
//  Created by Sergey Balalaev on 20.03.2024.
//

import Foundation

/// This structure encapsulate information by using string keys from localizable files with localization code
struct LocalizableFiles {
    private(set) var code: String
    private(set) var keyValue: [String: String]
    private(set) var linesNumbers: [String: Int]
    private(set) var fileNames: [String]
    private(set) var keyFileNames: [String: String]

    init(code: String) {
        self.code = code
        keyValue = [:]
        linesNumbers = [:]
        fileNames = []
        keyFileNames = [:]
        processFiles()
    }

    private func checkCode(for fileName: String) -> Bool {
        if settings.isOnlyOneLanguage {
            return true
        }
        if fileName.contains("\(code).lproj/") {
            return true
        }
        return false
    }

    private mutating func processAllStringsFiles(ignoredTranslation: inout [String]) {
        let path = localizablePath
        if !FileManager.default.fileExists(atPath: path) {
            print("Invalid path of localizable files: \(path) does not exist.")
            exit(1)
        }
        let fileEnumerator = FileManager.default.enumerator(atPath: path)
        while let fileName = fileEnumerator?.nextObject() as? String {
            if fileName.hasSuffix(".xcstrings") {
                fileNames.append(fileName)
                checkCatalogFile(fileName: fileName, ignoredTranslation: &ignoredTranslation)
            } else if fileName.hasSuffix(".strings"), checkCode(for: fileName) {
                fileNames.append(fileName)
                processStringsFile(fileName: fileName, ignoredTranslation: &ignoredTranslation)
            } else if fileName.hasSuffix(".stringsdict"), checkCode(for: fileName) {
                fileNames.append(fileName)
                checkDictionaryFile(fileName: fileName, ignoredTranslation: &ignoredTranslation)
            }
        }
    }

    private mutating func processFiles() {
        keyValue = [:]
        var ignoredTranslation: [String] = []

        processAllStringsFiles(ignoredTranslation: &ignoredTranslation)

        ignoredFromSameTranslation[code] = ignoredTranslation
        for key in settings.ignoredUntranslatedKeys {
            keyValue[key] = ""
        }
    }

    private func getFilePath(fileName: String) -> String {
        return getLocalizableFilePath(fileName: fileName, code: code)
    }

    private mutating func processStringsFile(fileName: String, ignoredTranslation: inout [String]) {
        if settings.isCleaningFiles {
            removeCommentsFromFile(fileName: fileName)
            removeEmptyLinesFromFile(fileName: fileName)
            sortLinesByAlphabetical(fileName: fileName)
        }
        checkStringsFile(fileName: fileName, ignoredTranslation: &ignoredTranslation)
    }

    private mutating func checkStringsFile(fileName: String, ignoredTranslation: inout [String]) {
        let filePath = getFilePath(fileName: fileName)
        guard let string = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            return
        }

        let lines = string.components(separatedBy: .newlines)

        let pattern = "\"(.*)\" = \"(.+)\";"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])

        // Ignored pattern
        let ignoredPattern = "\"(.*)\" = \"(.+)\"; *\\/\\/ *ignore-same-translation-warning"
        let ignoredRegex = try? NSRegularExpression(pattern: ignoredPattern, options: [])

        for (lineNumber, line) in lines.enumerated() {
            let range = NSRange(location: 0, length: (line as NSString).length)

            if let ignoredMatch = ignoredRegex?.firstMatch(in: line,
                                                           options: [],
                                                           range: range) {
                let key = (line as NSString).substring(with: ignoredMatch.range(at: 1))
                ignoredTranslation.append(key)
            }

            if let firstMatch = regex?.firstMatch(in: line, options: [], range: range) {
                let stringLine = line as String
                if stringLine.trimmingCharacters(in: .whitespaces).hasPrefix("//") {
                    continue
                }
                let key = (line as NSString).substring(with: firstMatch.range(at: 1))
                let value = (line as NSString).substring(with: firstMatch.range(at: 2))

                if keyValue[key] != nil {
                    printError(
                        fileName: fileName,
                        code: code,
                        message: "[Duplication] \"\(key)\" is duplicated in \(code.uppercased()) file",
                        line: linesNumbers[key]
                    )
                } else {
                    keyValue[key] = value
                    linesNumbers[key] = lineNumber + 1
                    keyFileNames[key] = fileName
                }
            }
        }
    }

    private mutating func checkDictionaryFile(fileName: String, ignoredTranslation: inout [String]) {
        let filePath = getFilePath(fileName: fileName)
        guard let dictionary = NSDictionary(contentsOfFile: filePath) else {
            return
        }

        func notFoundKey(key: String, value: String, lineNumber: Int) {
#warning("Please check [Not found] for zero. Not show file from stringsdict.")
            printError(
                fileName: fileName,
                code: code,
                message: "[Not found] \"\(key)\" \(value) is not found key from \(code.uppercased()) dictionary file",
                line: lineNumber
            )
        }

        for (lineNumber, keyItem) in dictionary.allKeys.enumerated() {
            let key = keyItem as! String

            let valueFormat = (dictionary[key] as? [String: Any?])?["NSStringLocalizedFormatKey"] as! String

            if let items = (dictionary[key] as? [String: Any?])?["items"] as? [String: String] {
                var value = valueFormat
                if let zero = items["zero"] {
                    value += zero
                } else {
                    notFoundKey(key: key, value: "zero", lineNumber: lineNumber)
                }
                if let one = items["one"] {
                    value += one
                } else {
                    notFoundKey(key: key, value: "one", lineNumber: lineNumber)
                }
                if let other = items["other"] {
                    value += other
                } else {
                    notFoundKey(key: key, value: "other", lineNumber: lineNumber)
                }

                if code.lowercased() == "ru" {
                    if let few = items["few"] {
                        value += few
                    } else {
                        notFoundKey(key: key, value: "few", lineNumber: lineNumber)
                    }
                    if let many = items["many"] {
                        value += many
                    } else {
                        notFoundKey(key: key, value: "many", lineNumber: lineNumber)
                    }
                }

                if keyValue[key] != nil {
                    printError(
                        fileName: fileName,
                        code: code,
                        message: "[Duplication] \"\(key)\"  is duplicated in \(code.uppercased()) file",
                        line: linesNumbers[key]
                    )
                } else {
                    keyValue[key] = value
                    linesNumbers[key] = lineNumber + 1
                    keyFileNames[key] = fileName
                }
            }
        }
    }

    private mutating func checkCatalogFile(fileName: String, ignoredTranslation: inout [String]) {

        struct XCUnit: Decodable {
            let state: String
            let value: String
        }

        struct XCValue: Decodable {
            let stringUnit: XCUnit
        }

        struct XCItem: Decodable {
            let localizations: [String: XCValue]
        }

        struct XCRoot: Decodable {
            let sourceLanguage: String
            let strings: [String: XCItem]
        }

        let filePath = localizablePath + "/" + fileName
        let url = URL(fileURLWithPath: filePath)
        guard let data = try? Data(contentsOf: url),
              let root = try? JSONDecoder().decode(XCRoot.self, from: data)
        else {

            return
        }

        for (lineNumber, keyItem) in root.strings.keys.enumerated() {
            let key = keyItem

            let valueFormat = root.strings[key]?.localizations[code]?.stringUnit.value

            let value = valueFormat

            if keyValue[key] != nil {
                printError(
                    fileName: fileName,
                    code: code,
                    message: "[Duplication] \"\(key)\"  is duplicated in \(code.uppercased()) file",
                    line: linesNumbers[key]
                )
            } else {
                keyValue[key] = value
                linesNumbers[key] = lineNumber + 1
                keyFileNames[key] = fileName
            }

        }
    }

    private func rebuildFileString(from lines: [String]) -> String {
        return lines.reduce("") { (r: String, s: String) -> String in
            (r == "") ? (r + s) : (r + "\n" + s)
        }
    }

    private func removeEmptyLinesFromFile(fileName: String) {
        let filePath = getFilePath(fileName: fileName)
        if let string = try? String(contentsOfFile: filePath, encoding: .utf8) {
            var lines = string.components(separatedBy: .newlines)
            lines = lines.filter { $0.trimmingCharacters(in: .whitespaces) != "" }
            let result = rebuildFileString(from: lines)
            try? result.write(toFile: filePath, atomically: false, encoding: .utf8)
        }
    }

    private func removeCommentsFromFile(fileName: String) {
        let filePath = getFilePath(fileName: fileName)
        if let string = try? String(contentsOfFile: filePath, encoding: .utf8) {
            var lines = string.components(separatedBy: .newlines)
            lines = lines.filter { !$0.hasPrefix("//") }
            let result = rebuildFileString(from: lines)
            try? result.write(toFile: filePath, atomically: false, encoding: .utf8)
        }
    }

    private func sortLinesByAlphabetical(fileName: String) {
        let filePath = getFilePath(fileName: fileName)
        if let string = try? String(contentsOfFile: filePath, encoding: .utf8) {
            let lines = string.components(separatedBy: .newlines)

            var result = ""
            for (lineNumber, stringLine) in sortByAlphabetical(lines).enumerated() {
                result += stringLine
                if lineNumber != lines.count - 1 {
                    result += "\n"
                }
            }
            try? result.write(toFile: filePath, atomically: false, encoding: .utf8)
        }
    }

    private func sortByAlphabetical(_ lines: [String]) -> [String] {
        return lines.sorted()
    }
}
