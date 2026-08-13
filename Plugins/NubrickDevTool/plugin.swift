import PackagePlugin
import Foundation

@main
struct NubrickDevTool: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        guard let sourceTarget = target as? SourceModuleTarget else { return [] }
        let swiftFiles = sourceTarget.sourceFiles(withSuffix: "swift").map(\.path)
        guard !swiftFiles.isEmpty else { return [] }

        let tool = try context.tool(named: "NubrickDevToolRunner")
        let output = context.pluginWorkDirectory.appending("NubrickEmbeddingIds.generated.swift")

        return [
            .buildCommand(
                displayName: "NubrickDevTool: Extracting embedding IDs",
                executable: tool.path,
                arguments: ["--output", output.string] + swiftFiles.map { $0.string },
                inputFiles: swiftFiles,
                outputFiles: [output]
            )
        ]
    }
}
