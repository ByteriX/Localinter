// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command file_length implicit_return

// MARK: - Strings

// swiftlint:disable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:disable nesting type_body_length type_name vertical_whitespace_opening_braces
public enum Strings {
  public enum InfoPlist {
    public static let cfBundleDisplayName = Strings.tr("InfoPlist", "CFBundleDisplayName")
    public static let nsCameraUsageDescription = Strings.tr("InfoPlist", "NSCameraUsageDescription")
  }
  public enum Localizable {
    public enum Hello {
      public static let world = Strings.tr("Localizable", "Hello.world")
      public static func worlds(_ p1: Int) -> String {
        return Strings.tr("Localizable", "Hello.worlds", p1)
      }
    }
    public enum Help {
      public static let me = Strings.tr("Localizable", "Help.me")
    }
  }
}
// swiftlint:enable explicit_type_interface function_parameter_count identifier_name line_length
// swiftlint:enable nesting type_body_length type_name vertical_whitespace_opening_braces

// MARK: - Implementation Details

extension Strings {
  private static func tr(_ table: String, _ key: String, _ args: CVarArg...) -> String {
    let format = BundleToken.bundle.localizedString(forKey: key, value: nil, table: table)
    return String(format: format, locale: Locale.current, arguments: args)
  }
}

// swiftlint:disable convenience_type
private final class BundleToken {
  static let bundle: Bundle = {
    #if SWIFT_PACKAGE
    return Bundle.module
    #else
    return Bundle(for: BundleToken.self)
    #endif
  }()
}
// swiftlint:enable convenience_type
