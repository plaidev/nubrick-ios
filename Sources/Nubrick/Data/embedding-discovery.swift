import Foundation

private typealias EmbeddingIdsFunc = @convention(c) () -> UnsafeMutablePointer<CChar>?

func discoverBuildTimeEmbeddingIds() -> [String] {
    guard let handle = dlopen(nil, RTLD_LAZY) else { return [] }
    defer { dlclose(handle) }
    guard let sym = dlsym(handle, "_nubrick_embedding_ids") else { return [] }
    let fn = unsafeBitCast(sym, to: EmbeddingIdsFunc.self)
    guard let cStr = fn() else { return [] }
    defer { free(cStr) }
    let joined = String(cString: cStr)
    guard !joined.isEmpty else { return [] }
    return joined.components(separatedBy: ",").filter { !$0.isEmpty }
}
