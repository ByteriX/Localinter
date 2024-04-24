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
