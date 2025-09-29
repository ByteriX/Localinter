#!/usr/bin/env xcrun --sdk macosx swift

import Foundation
import AppKit

/**
 LocaLinter.swift
 version 2.1.0

 Created by Sergey Balalaev on 23.09.22.
 Copyright (c) 2022-2025 ByteriX. All rights reserved.

 Using from build phase:
 ${SRCROOT}/Scripts/LocaLinter.swift
 */

//
//  Settings.swift
//  
//
//  Created by Sergey Balalaev on 20.03.2024.
//

import Foundation

struct Settings {

    /// For enable or disable this script
    var isEnabled = true

    var dir: String = defaultDir

    /// It language will come as general and ideal
    var masterLanguageCode = "en"

    /// Path of folder with localizations files. For example "/YouProject/Resources/Languages"
    private var relativeLocalizablePath = "" {
        didSet {
            localizablePath = dir + relativeLocalizablePath
        }
    }
    var localizablePath = ""

    /// Path of the source folder which will used in searching for localization keys you actually use in your project. For Example "/YouProject/Source"
    private var relativeSourcePath = "" {
        didSet {
            sourcePath = dir + relativeSourcePath
        }
    }
    var sourcePath = ""

    /// Using localizations type from code. If you use custom you need define regex pattern
    enum UsingType {
        case standart
        case swiftUI
        case l10n
        case localized
        /// Actualy you can chouse enumName as is in your yaml SwiftGen settings file + strings file name seporated '\.'.
        /// For example: in yaml enumName: "YourStrings", string file name is "Str.strings", then you should use swiftGen(enumName: "YourStrings\.Str")
        /// but in yaml you can chouse forceFileNameEnum for remove string file name from generated constants, then you should use swiftGen(enumName: "YourStrings")
        /// IMPORTANT: If you use "your.const.variable" string const in Str.strings file, SwiftGen generate "Your.Const.variable" with uppercased enum names. Localinter case sensitive and not found using from code this. Then I sugest to use "Your.Const.variable" string const in Str.strings file.
        case swiftGen(enumName: String = "Localizable")
        case custom(pattern: String)
    }

    /// yuo can use many types
    var usingTypes: [UsingType] = [
        .standart,
        .swiftUI,
        .swiftGen(enumName: #"Strings\.Localizable"#),
    ]

    /**
     If you want to exclude unused keys from checking, you can define they this

     Example:
     let ignoredUnusedKeys = [
     "CFBundleDisplayName",
     "NSCameraUsageDescription"
     ]
     */
    var ignoredUnusedKeys: Set<String> = [ ]

    /// If you want to exclude untranslated keys from checking, you can define they this
    var ignoredUntranslatedKeys: Set<String> = [ ]

    /// For sources code analysis
    var sourcesExtensions = Set<String>(["swift", "mm", "m"].map{$0.uppercased()})

    var isThrowingErrorForUntranslated = true
    var isThrowingErrorForUnused = true
    var isClearWhitespasesInLocalizableFiles = false
    var isOnlyOneLanguage = false
    /// Cleaning localizable files. Will remove comments, empty lines and order your keys by alphabetical.
    var isCleaningFiles = false

    init(){
        load()
    }

}

extension Settings {

    private static let extensions = ["yml", "yaml"]
    private static let fileName = "localinter"
    private static let defaultDir = FileManager.default.currentDirectoryPath

    private enum Key: String {
        case isEnabled
        case masterLanguageCode
        case relativeLocalizablePath
        case relativeSourcePath

        case usingTypes

        case ignoredUnusedKeys
        case ignoredUntranslatedKeys
        case sourcesExtensions

        case isThrowingErrorForUntranslated
        case isThrowingErrorForUnused
        case isClearWhitespasesInLocalizableFiles
        case isOnlyOneLanguage
        case isCleaningFiles

        enum UsingType: String {
            case standart = "standart"
            case swiftUI = "swiftUI"
            case l10n = "l10n"
            case localized = "localized"
            case swiftGen = "swiftGen"
            case custom = "custom"
        }
    }

    fileprivate mutating func load() {
        var dirs = [Self.defaultDir]

        var argIndex = 1
        while argIndex < CommandLine.arguments.count {
            if CommandLine.arguments[argIndex] == "--settingsPath" {
                argIndex += 1
                if argIndex < CommandLine.arguments.count {
                    dirs.append(CommandLine.arguments[argIndex])
                }
            }
            argIndex += 1
        }
        for dir in dirs {
            for ext in Self.extensions {
                load(dir: dir, ext: ext)
            }
        }
    }

    fileprivate mutating func load(dir: String, ext: String) {

        let filePath = (dir as NSString).appendingPathComponent(Self.fileName + "." + ext)
        guard let stringData = try? String(contentsOfFile: filePath) else {
            print("Settings file '\(filePath)' not found")
            return
        }
        self.dir = dir
        print("Parse settings file '\(filePath)':")

        let lines = stringData.components(separatedBy: .newlines)

        var currentKey: Key? = nil
        var isStartKey: Bool = false
        var lineIndex = 0

        while lineIndex < lines.count {
            let line = lines[lineIndex].trimmingCharacters(in: .whitespaces)
            lineIndex += 1

            if line.hasPrefix("#") {
                continue
            }

            var currentValue: String? = nil
            if let value = Self.getArrayValue(line: line) {
                currentValue = value
            } else if let object = Self.getObject(line: line) {
                if let key = Key(rawValue: object.name) {
                    currentKey = key
                    currentValue = object.value
                    isStartKey = true
                }
            }

            guard let currentKey else { continue }
            switch currentKey {
            case .isEnabled:
                if let value = currentValue, let isEnabled = Bool(value) {
                    self.isEnabled = isEnabled
                }
            case .masterLanguageCode:
                if let masterLanguageCode = currentValue {
                    self.masterLanguageCode = masterLanguageCode
                }
            case .relativeLocalizablePath:
                if let relativeLocalizablePath = currentValue {
                    self.relativeLocalizablePath = relativeLocalizablePath
                }
            case .relativeSourcePath:
                if let relativeSourcePath = currentValue {
                    self.relativeSourcePath = relativeSourcePath
                }
            case .usingTypes:
                if let value = currentValue, value.isEmpty == false {
                    if let object = Self.getObject(line: value), object.name == "case" {
                        if let usingType = Key.UsingType(rawValue: object.value) {
                            switch usingType {
                            case .standart:
                                self.usingTypes.append(.standart)
                            case .swiftUI:
                                self.usingTypes.append(.swiftUI)
                            case .l10n:
                                self.usingTypes.append(.l10n)
                            case .localized:
                                self.usingTypes.append(.localized)
                            case .swiftGen:
                                guard lineIndex < lines.count else {
                                    break
                                }
                                let line = lines[lineIndex].trimmingCharacters(in: .whitespaces)
                                if line.hasPrefix("#") == false,
                                   let object = Self.getObject(line: line),
                                   object.name == "enumName"
                                {
                                    lineIndex += 1
                                    self.usingTypes.append(.swiftGen(enumName: object.value))
                                }
                            case .custom:
                                guard lineIndex < lines.count else {
                                    break
                                }
                                let line = lines[lineIndex].trimmingCharacters(in: .whitespaces)
                                if line.hasPrefix("#") == false,
                                   let object = Self.getObject(line: line),
                                   object.name == "pattern"
                                {
                                    lineIndex += 1
                                    self.usingTypes.append(.custom(pattern: object.value))
                                }
                            }
                        }
                    }
                } else if isStartKey {
                    self.usingTypes = []
                }
            case .ignoredUnusedKeys:
                if let value = currentValue, value.isEmpty == false {
                    self.ignoredUnusedKeys.insert(value)
                } else if isStartKey {
                    self.ignoredUnusedKeys = []
                }
            case .ignoredUntranslatedKeys:
                if let value = currentValue, value.isEmpty == false {
                    self.ignoredUntranslatedKeys.insert(value)
                } else if isStartKey {
                    self.ignoredUntranslatedKeys = []
                }
            case .sourcesExtensions:
                if let value = currentValue, value.isEmpty == false {
                    self.sourcesExtensions.insert(value.uppercased())
                } else if isStartKey {
                    self.sourcesExtensions = []
                }
            case .isThrowingErrorForUntranslated:
                if let value = currentValue, let isThrowingErrorForUntranslated = Bool(value) {
                    self.isThrowingErrorForUntranslated = isThrowingErrorForUntranslated
                }
            case .isThrowingErrorForUnused:
                if let value = currentValue, let isThrowingErrorForUnused = Bool(value) {
                    self.isThrowingErrorForUnused = isThrowingErrorForUnused
                }
            case .isClearWhitespasesInLocalizableFiles:
                if let value = currentValue, let isClearWhitespasesInLocalizableFiles = Bool(value) {
                    self.isClearWhitespasesInLocalizableFiles = isClearWhitespasesInLocalizableFiles
                }
            case .isOnlyOneLanguage:
                if let value = currentValue, let isOnlyOneLanguage = Bool(value) {
                    self.isOnlyOneLanguage = isOnlyOneLanguage
                }
            case .isCleaningFiles:
                if let value = currentValue, let isCleaningFiles = Bool(value) {
                    self.isCleaningFiles = isCleaningFiles
                }
            }
            isStartKey = false
        }
        print("\(self)")
    }

    private struct Object {
        let name: String
        let value: String
    }

    private static let regexObject = try! NSRegularExpression(pattern: #"^([A-z0-9]+?)\s*:"#, options: [.caseInsensitive])

    private static func getObject(line: String) -> Object? {
        let results = regexObject.matches(in: line, range: NSRange(line.startIndex..., in: line))
        if let result = results.first {
            let name = String(line[Range(result.range, in: line)!]).dropLast().trimmingCharacters(in: .whitespaces)
            let value = line.suffix(from: Range(result.range, in: line)!.upperBound).trimmingCharacters(in: .whitespaces)
            return Object(name: name, value: value)
        }
        return nil
    }

    private static func getArrayValue(line: String) -> String? {
        guard line.first == "-" else {
            return nil
        }
        return line.dropFirst().trimmingCharacters(in: .whitespaces)
    }

    private static func getArrayObject(line: String) -> Object? {
        guard let value = getArrayValue(line: line) else {
            return nil
        }
        return getObject(line: value)
    }
}
//
//  main.swift
//
//
//  Created by Sergey Balalaev on 19.03.2024.
//

import Foundation

// MARK: begin of settings the script

let settings = Settings()

// MARK: end of settings the script

let startDate = Date()

extension String {
    var stringByRemovingWhitespaces: String {
        return components(separatedBy: .whitespacesAndNewlines).joined()
    }
}

func getLocalizableFilePath(fileName: String, code: String) -> String {
    return "\(settings.localizablePath)/\(fileName)"
}

var searchUsingRegexPatterns: [String] = []
for usingType in settings.usingTypes {
    switch usingType {
    case .custom(let pattern):
        searchUsingRegexPatterns.append(pattern)
    case .standart:
        searchUsingRegexPatterns.append("NSLocalized(Format)?String\\(\\s*@?\"([\\w\\.]+)\"")
    case .swiftUI:
        searchUsingRegexPatterns.append(#"\bText\(\s*"(.*?)"\s*[\)|,]"#)
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
    if !FileManager.default.fileExists(atPath: settings.localizablePath) {
        print("Invalid configuration: \(settings.localizablePath) does not exist.")
        exit(1)
    }
    let fileEnumerator = FileManager.default.enumerator(atPath: settings.localizablePath)
    let extensionName = "lproj"
    print("Found next languages:")
    while let fileName = fileEnumerator?.nextObject() as? String {
        if fileName.hasSuffix(extensionName) {
            let code = (fileName.replacingOccurrences(of: ".\(extensionName)", with: "") as NSString).lastPathComponent
            print(code)
            result.append(code)
        }
    }
    return result
}

// MARK: detection resources of localization

let supportedLanguages = supportedLanguagesList()
var ignoredFromSameTranslation: [String: [String]] = [:]
var warningsCount = 0
var errorsCount = 0

// MARK: start analyze

if settings.isEnabled == false {
    let firstArgument = CommandLine.arguments[0]
    print("\(firstArgument):\(#line): warning: localization check cancelled")
    exit(000)
}

func printError(fileName: String = masterLocalizableFiles.fileNames.first ?? "", code: String = settings.masterLanguageCode, message: String,
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



// MARK: - make localization files

let masterLocalizableFiles = LocalizableFiles(code: settings.masterLanguageCode)
let localizableFiles = supportedLanguages
    .filter { $0 != settings.masterLanguageCode }
    .map { LocalizableFiles(code: $0) }

// MARK: - detect unused Keys

let sourcesRegex = searchUsingRegexPatterns.compactMap { regexPattern in
    let regex = try? NSRegularExpression(pattern: regexPattern, options: [])
    if regex == nil {
        printError(fileName: #file, message: "Not right pattern for regex: \(regexPattern)", line: #line)
    }
    return regex
}

let swiftFileEnumerator = FileManager.default.enumerator(atPath: settings.sourcePath)
var localizedStringKeys: [String] = []
while let sourceFileName = swiftFileEnumerator?.nextObject() as? String {
    let fileExtension = (sourceFileName as NSString).pathExtension.uppercased()
    // checks the extension
    if settings.sourcesExtensions.contains(fileExtension) {
        let sourceFilePath = "\(settings.sourcePath)/\(sourceFileName)"
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
    if settings.isClearWhitespasesInLocalizableFiles {
        value = value.stringByRemovingWhitespaces
    }
    localizedStringKeys.append(value)
}

let masterKeys = Set(masterLocalizableFiles.keyValue.keys)
let usedKeys = Set(localizedStringKeys)
let unusedKeys = masterKeys.subtracting(usedKeys).subtracting(settings.ignoredUnusedKeys)
let untranslatedKeys = usedKeys.subtracting(masterKeys)

// MARK: - compare each translation file against master

for file in localizableFiles {
    for key in masterLocalizableFiles.keyValue.keys {
        if let stringValue = file.keyValue[key] {
            if stringValue == masterLocalizableFiles.keyValue[key], settings.ignoredUntranslatedKeys.contains(key) == false {
                if (ignoredFromSameTranslation[file.code]?.contains(key) ?? false) == false {
                    printError(
                        fileName: file.keyFileNames[key] ?? "",
                        code: file.code,
                        message: "[Potentially Untranslated] \"\(key)\" in \(file.code.uppercased()) file doesn't seem to be localized",
                        line: file.linesNumbers[key],
                        isWarning: true
                    )
                }
            }
        } else {
            printError(
                code: masterLocalizableFiles.code,
                message: "[Missing] \"\(key)\" missing from \(file.code.uppercased()) file",
                line: masterLocalizableFiles.linesNumbers[key]
            )
        }
    }

    let redundantKeys = file.keyValue.keys.filter { !masterLocalizableFiles.keyValue.keys.contains($0) }

    for key in redundantKeys {
        printError(
            fileName: file.keyFileNames[key] ?? "",
            code: file.code,
            message: "[Redundant key] \"\(key)\" redundant in \(file.code.uppercased()) file",
            line: file.linesNumbers[key]
        )
    }
}

for key in untranslatedKeys {
    printError(message: "[Missing Translation] \(key) is not translated", line: 1, isWarning: settings.isThrowingErrorForUntranslated == false)
}

for key in unusedKeys {
    printError(message: "[Unused cases] \(key) is not used from code", line: masterLocalizableFiles.linesNumbers[key], isWarning: settings.isThrowingErrorForUnused == false)
}

print("Number of warnings: \(warningsCount)")
print("Number of errors: \(errorsCount)")
print("Time: \(Date().timeIntervalSince(startDate)) sec.")

if errorsCount > 0 {
    exit(1)
}
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
        let path = settings.localizablePath
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

        let filePath = settings.localizablePath + "/" + fileName
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
