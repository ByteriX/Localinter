//
//  plugin.swift
//
//
//  Created by Sergey Balalaev on 19.03.2024.
//

import PackagePlugin

@main
struct LocalinterPlugin: BuildToolPlugin {
    func createBuildCommands(context: PackagePlugin.PluginContext, target: Target) throws -> [PackagePlugin.Command] {
        let executable = try context.tool(named: "LocalinterExec").path

        return [
            .buildCommand(
                displayName: "Running Localinter",
                executable: executable,
                arguments: [
                    "--settingsPath", target.directory.string
                ]
            ),
        ]
    }
}

#if canImport(XcodeProjectPlugin)
    import XcodeProjectPlugin

    extension LocalinterPlugin: XcodeBuildToolPlugin {
        func createBuildCommands(context: XcodeProjectPlugin.XcodePluginContext, target: XcodeProjectPlugin.XcodeTarget) throws -> [PackagePlugin.Command] {
            let executable = try context.tool(named: "LocalinterExec").path

            return [
                .buildCommand(
                    displayName: "Running Localinter",
                    executable: executable,
                    arguments: [
                        "--settingsPath", context.pluginWorkDirectory.string
                    ]
                ),
            ]
        }
    }
#endif
