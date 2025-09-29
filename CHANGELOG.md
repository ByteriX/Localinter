 
# Changelog

Any significant changes made to this project will be documented in this file.

## [2.1.0] - 2025-07-20

#### Added

- Updating script version `LocaLinter.swift` from release script.
- Actualization both examples for using with a Plugin and a Script.
- For False value of isThrowingErrorForUntranslated and isThrowingErrorForUnused going to showing warning.

## [2.0.2] - 2024-04-24

#### Added

- Supporting Settings with more yaml/yml extension from Root Library/target with inherited. Priority: target/root, yaml/yml.
- Documentation of Settings file format.

## [2.0.1] - 2024-03-22

#### Added

- Tests to release.

#### Fixed

- Documentation with intallation and setup settings sections.

## [2.0.0] - 2024-03-21

#### Added

- Supporting SPM plugin.
- Settings from YAML.
- Changelog.

#### Fixed

- Regular expression for SwiftUI bundle/tableName support.
- Recursive searching of .strings and .stringsdict files as .xcstrings.
- True error and warning position in .strings file.


## [1.3.0] - 2023-10-25

#### Added

- Supporting .xcstrings format.

## [1.2.0] - 2023-07-23

#### Added

- Supporting SwiftUI pattern.
- Example with SwiftUI.

#### Fixed

- Multiply patterns mode.

## [1.1.1] - 2022-10-07

#### Fixed

- Issue with SwiftGen.

## [1.1.0] - 2022-09-07

#### Added

- Documentation, Readme
- Calculation execution time.
- isThrowingErrorForUnused setting

## [1.0.0] - 2022-08-31

#### Added

- Search general errors
- Common Settings: path, UsingType (standart, l10n, localized, SwiftGen. custom regex), ignoredUnusedKeys, ignoredUntranslatedKeys
- Addition Settings: isThrowingErrorForUntranslated, isClearWhitespasesInLocalizableFiles, isOnlyOneLanguage, isCleaningFiles
