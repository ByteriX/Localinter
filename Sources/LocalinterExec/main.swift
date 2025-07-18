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
