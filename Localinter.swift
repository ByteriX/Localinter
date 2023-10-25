#!/usr/bin/env xcrun --sdk macosx swift
/**
 Localinter.swift
 version 1.3
 
 Created by Sergey Balalaev on 31.08.22.
 Copyright (c) 2022 ByteriX. All rights reserved.
 
 Script allows:
 1. Checking the localizable file from masterLanguageCode and find missing keys in other localizable files
 2. Searching potentially untranslated keys from localizable files
 3. Checking duplicate keys from localizable files
 4. Checking unused keys from localizable files
 
 Using from build phase:
 ${SRCROOT}/Scripts/Localinter.swift
 */

import Foundation

// MARK: begin of settings the script

/// For enable or disable this script
let isEnabled = true

/// It language will come as general and ideal
let masterLanguageCode = "en"

/// Path of folder with localizations files. For example "/YouProject/Resources/Languages"
let relativeLocalizablePath = ""

/// Path of the source folder which will used in searching for localization keys you actually use in your project. For Example "/YouProject/Source"
let relativeSourcePath = "/Strings/Src"

/// Using localizations type from code. If you use custom you need define regex pattern
enum UsingType {
    case standart
    case swiftUI
    case l10n
    case localized
    case swiftGen(enumName: String = "Localizable")
    case custom(pattern: String)
}

/// yuo can use many types
let usingTypes: [UsingType] = [
    .swiftGen(enumName: #"Strings\.Localizable"#),
    .swiftUI
]

/**
 If you want to exclude unused keys from checking, you can define they this

 Example:
  let ignoredUnusedKeys = [
     "CFBundleDisplayName",
     "NSCameraUsageDescription"
  ]
 */
let ignoredUnusedKeys: Set<String> = [
    "CFBundleDisplayName",
    "NSCameraUsageDescription"
]

/// If you want to exclude untranslated keys from checking, you can define they this
let ignoredUntranslatedKeys: Set<String> = [
]

let sourcesExtensions = ["swift", "mm", "m"]
let sourcesSetExtensions = Set<String>(sourcesExtensions.map{$0.uppercased()})

let isThrowingErrorForUntranslated = true
let isThrowingErrorForUnused = true
let isClearWhitespasesInLocalizableFiles = false
let isOnlyOneLanguage = false
/// Cleaning localizable files. Will remove comments, empty lines and order your keys by alphabetical.
let isCleaningFiles = false

// MARK: end of settings the script

let startDate = Date()

extension String {
    var stringByRemovingWhitespaces: String {
        return components(separatedBy: .whitespacesAndNewlines).joined()
    }
}

let localizablePath = FileManager.default.currentDirectoryPath + relativeLocalizablePath

func getLocalizableFilePath(fileName: String, code: String) -> String {
    return isOnlyOneLanguage ? "\(localizablePath)/\(fileName)" : "\(localizablePath)/\(code).lproj/\(fileName)"
}

var searchUsingRegexPatterns: [String] = []
for usingType in usingTypes {
    switch usingType {
    case .custom(let pattern):
        searchUsingRegexPatterns.append(pattern)
    case .standart:
        searchUsingRegexPatterns.append("NSLocalized(Format)?String\\(\\s*@?\"([\\w\\.]+)\"")
    case .swiftUI:
        searchUsingRegexPatterns.append(#"\bText\(\s*"(.*)"\s*\)"#)
    case .swiftGen(let enumName):
        searchUsingRegexPatterns.append(enumName + #"\s*\.((?:\.*[A-Z]{1}[A-z0-9]*)*)\s*((?:\.*[a-z]{1}[A-z0-9]*))"#)
    case .l10n:
        searchUsingRegexPatterns.append("L10n.tr\\(key: \"(\\w+)\"")
    case .localized:
        searchUsingRegexPatterns.append("\"(.*)\".localized")
    }
}

/// Detect supported languages
func supportedLanguagesList() -> [String] {
    var result: [String] = []
    if !FileManager.default.fileExists(atPath: localizablePath) {
        print("Invalid configuration: \(localizablePath) does not exist.")
        exit(1)
    }
    let fileEnumerator = FileManager.default.enumerator(atPath: localizablePath)
    let extensionName = "lproj"
    print("Found next languages:")
    while let fileName = fileEnumerator?.nextObject() as? String {
        if fileName.hasSuffix(extensionName) {
            let code = fileName.replacingOccurrences(of: ".\(extensionName)", with: "")
            print(code)
            result.append(code)
        }
    }
    return result
}

/// Detect names of localizable files
func localizableFileNamesList() -> [String] {
    var result: [String] = []
    let path = getLocalizableFilePath(fileName: "", code: masterLanguageCode)
    if !FileManager.default.fileExists(atPath: path) {
        print("Invalid path of localizable files: \(path) does not exist.")
        exit(1)
    }
    let fileEnumerator = FileManager.default.enumerator(atPath: path)
    print("Found next localizable files:")
    while let fileName = fileEnumerator?.nextObject() as? String {
        print(fileName)
        result.append(fileName)
    }
    return result
}

// MARK: detection resources of localization

let supportedLanguages = supportedLanguagesList()
let localizableFileNames = localizableFileNamesList()
var ignoredFromSameTranslation: [String: [String]] = [:]
var warningsCount = 0
var errorsCount = 0

// MARK: start analyze

if isEnabled == false {
    let firstArgument = CommandLine.arguments[0]
    print("\(firstArgument):\(#line): warning: localization check cancelled")
    exit(000)
}

func printError(fileName: String = localizableFileNames.first ?? "", code: String = masterLanguageCode, message: String,
                line: Int? = nil, isWarning: Bool = false) {
    var result = getLocalizableFilePath(fileName: fileName, code: code)
    if let line = line {
        result += ":\(line): "
    } else {
        result += ": "
    }
    result += isWarning ? "warning: " : "error: "
    print(result + message)
    if isWarning {
        warningsCount += 1
    } else {
        errorsCount += 1
    }
}

/// This structure encapsulate information by using string keys from localizable files with localization code
struct LocalizableFiles {
    private(set) var code: String
    private(set) var keyValue: [String: String]
    private(set) var linesNumbers: [String: Int]

    init(code: String) {
        self.code = code
        keyValue = [:]
        linesNumbers = [:]
        processFiles()
    }

    private mutating func processCatalogStringsFiles(ignoredTranslation: inout [String]) {
        let path = localizablePath
        if !FileManager.default.fileExists(atPath: path) {
            print("Invalid path of localizable files: \(path) does not exist.")
            exit(1)
        }
        let fileEnumerator = FileManager.default.enumerator(atPath: path)
        while let fileName = fileEnumerator?.nextObject() as? String {
            if fileName.hasSuffix(".xcstrings") {
                checkCatalogFile(fileName: fileName, ignoredTranslation: &ignoredTranslation)
            }
        }
    }

    private mutating func processFiles() {
        keyValue = [:]
        var ignoredTranslation: [String] = []

        for fileName in localizableFileNames {
            if fileName.hasSuffix(".strings") {
                processStringsFile(fileName: fileName, ignoredTranslation: &ignoredTranslation)
            } else if fileName.hasSuffix(".stringsdict") {
                checkDictionaryFile(fileName: fileName, ignoredTranslation: &ignoredTranslation)
            } else {
                printError(fileName: fileName, message: "Not understand localizable file with name: \(fileName)", isWarning: true)
            }
        }

        processCatalogStringsFiles(ignoredTranslation: &ignoredTranslation)

        ignoredFromSameTranslation[code] = ignoredTranslation
        for key in ignoredUntranslatedKeys {
            keyValue[key] = ""
        }
    }

    private func getFilePath(fileName: String) -> String {
        return getLocalizableFilePath(fileName: fileName, code: code)
    }

    private mutating func processStringsFile(fileName: String, ignoredTranslation: inout [String]) {
        if isCleaningFiles {
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
            printError(
                fileName: fileName,
                code: code,
                message: "error: [Not found] \"\(key)\" \(value) is not found key from \(code.uppercased()) dictionary file",
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

// MARK: - make localization files

let masterLocalizableFiles = LocalizableFiles(code: masterLanguageCode)
let localizableFiles = supportedLanguages
    .filter { $0 != masterLanguageCode }
    .map { LocalizableFiles(code: $0) }

// MARK: - detect unused Keys

let sourcesRegex = searchUsingRegexPatterns.compactMap { regexPattern in
    let regex = try? NSRegularExpression(pattern: regexPattern, options: [])
    if regex == nil {
        printError(fileName: #file, message: "Not right pattern for regex: \(regexPattern)", line: #line)
    }
    return regex
}
let sourcePath = FileManager.default.currentDirectoryPath + relativeSourcePath
let swiftFileEnumerator = FileManager.default.enumerator(atPath: sourcePath)
var localizedStringKeys: [String] = []
while let sourceFileName = swiftFileEnumerator?.nextObject() as? String {
    let fileExtension = (sourceFileName as NSString).pathExtension.uppercased()
    // checks the extension
    if sourcesSetExtensions.contains(fileExtension) {
        let sourceFilePath = "\(sourcePath)/\(sourceFileName)"
        if let string = try? String(contentsOfFile: sourceFilePath, encoding: .utf8) {
            let range = NSRange(location: 0, length: (string as NSString).length)
            sourcesRegex.forEach{ regex in
                regex.enumerateMatches(in: string,
                                        options: [],
                                        range: range) { result, _, _ in
                    addLocalizedStringKey(from: string, result: result)
                }
            }
        }
    }
}

func addLocalizedStringKey(from string: String, result: NSTextCheckingResult?) {
    guard let result = result else {
        return
    }
    // first range is matching, all next is groups
    var value = (1...result.numberOfRanges - 1).map { index in
        (string as NSString).substring(with: result.range(at: index))
    }.joined()
    if isClearWhitespasesInLocalizableFiles {
        value = value.stringByRemovingWhitespaces
    }
    localizedStringKeys.append(value)
}

let masterKeys = Set(masterLocalizableFiles.keyValue.keys)
let usedKeys = Set(localizedStringKeys)
let unusedKeys = masterKeys.subtracting(usedKeys).subtracting(ignoredUnusedKeys)
let untranslatedKeys = usedKeys.subtracting(masterKeys)

// MARK: - compare each translation file against master

for file in localizableFiles {
    for key in masterLocalizableFiles.keyValue.keys {
        if let stringValue = file.keyValue[key] {
            if stringValue == masterLocalizableFiles.keyValue[key], ignoredUntranslatedKeys.contains(key) == false {
                if (ignoredFromSameTranslation[file.code]?.contains(key) ?? false) == false {
                    printError(
                        code: file.code,
                        message: "[Potentially Untranslated] \"\(key)\" in \(file.code.uppercased()) file doesn't seem to be localized",
                        line: file.linesNumbers[key],
                        isWarning: true
                    )
                }
            }
        } else {
            printError(
                code: file.code,
                message: "[Missing] \"\(key)\" missing from \(file.code.uppercased()) file",
                line: masterLocalizableFiles.linesNumbers[key]
            )
        }
    }

    let redundantKeys = file.keyValue.keys.filter { !masterLocalizableFiles.keyValue.keys.contains($0) }

    for key in redundantKeys {
        printError(
            code: file.code,
            message: "[Redundant key] \"\(key)\" redundant in \(file.code.uppercased()) file",
            line: file.linesNumbers[key]
        )
    }
}

if isThrowingErrorForUntranslated {
    for key in untranslatedKeys {
        printError(message: "[Missing Translation] \(key) is not translated", line: 1)
    }
}

if isThrowingErrorForUnused {
    for key in unusedKeys {
        printError(message: "[Unused cases] \(key) is not used from code", line: masterLocalizableFiles.linesNumbers[key])
    }
}

print("Number of warnings: \(warningsCount)")
print("Number of errors: \(errorsCount)")
print("Time: \(Date().timeIntervalSince(startDate)) sec.")

if errorsCount > 0 {
    exit(1)
}
