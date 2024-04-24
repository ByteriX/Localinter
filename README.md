# Localinter

Check localizable files for Swift

## Script allows

 1. Checking the localizable file from masterLanguageCode and find missing keys in other localizable files
 2. Searching potentially untranslated keys from localizable files
 3. Checking duplicate keys from localizable files
 4. Checking unused keys from localizable files

![](Screens/3.png)

## Accessibility

1. Support .strings, .stringsdict and new .xcstrings formats
2. Support any use notation: classic, l10n, localized, SwiftGen, SwiftUI, and custom Regex
3. You can ignore system keys
4. Any settings for generation errors or warnings at YAML settings file
5. Support for multi-module projects.

## Install

From 2.0 version we support SPM plugin.

### Swift Package Manager (SPM)

The [Swift Package Manager](https://swift.org/package-manager/) is a tool for automating the distribution of Swift code and is integrated into the `swift` compiler. `Localinter` supports its use on supported platforms as plugin tool. 

Once you have your Swift package set up, adding `Localinter` as a dependency is as easy as adding it to the `dependencies` value of your `Package.swift`. Then you need call from your target plugin like this:

```swift

    dependencies: [
        .Package(url: "https://github.com/ByteriX/Localinter.git", majorVersion: 2)
    ],
    targets: [
        .target(
            name: "YourTarget",
            plugins: [
                .plugin(name: "LocalinterPlugin", package: "Localinter"),
            ]
        )
    ]
    
```

### Old 1.3 version instalation

1. Just copy Localinter.swift to project.
2. Exclude from "Build Phases" -> "Compile Sources"
3. Add to "Build Phases" run script:
```bash
${SRCROOT}/Localinter.swift
```
![](Screens/1.png)

## Setup:

You need to add a settings file named `imagelinter.yaml` or/and `imagelinter.yml` to a `target` or/and `the root of the library` `dir` of the package.
imagesPath and sourcePath are calculated from dir of this package. 

Supports more settings files with rewrite properties with priority: first a `target` then `the root of library `dir`, first `imagelinter.yaml` then `imagelinter.yml`.

### Example of Settings file format

```yaml
isEnabled: true
masterLanguageCode: en
relativeLocalizablePath: /Sources
relativeSourcePath: /Sources
usingTypes: 
  - case: standart
  - case: swiftUI
  - case: l10n
  - case: localized
  - case: swiftGen
    enumName: Localizable
  - case: custom
    pattern: "(.*)".localized
ignoredUnusedKeys:
  - CFBundleDisplayName
  - NSCameraUsageDescription
ignoredUntranslatedKeys:
  - Special.Untranslated
sourcesExtensions:
  - swift
  - cpp
isThrowingErrorForUntranslated: true
isThrowingErrorForUnused: true
isClearWhitespasesInLocalizableFiles: false
isOnlyOneLanguage: false
isCleaningFiles: true
```
