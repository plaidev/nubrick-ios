//
//  network.swift
//  Nubrick
//
//  Created by Takuma Jimbo on 2025/03/14.
//

import Foundation

import XCTest
@testable import Nubrick

final class CacheStoreTests: XCTestCase {
    private var cache: CacheStore!
    
    func testSetAndGetCache() {
        cache = CacheStore(policy: NativebrikCachePolicy())
        let data = "testData".data(using: .utf8)!
        cache.set(key: "testKey", data: data)
        let cacheObject = cache.get(key: "testKey")
        XCTAssertNotNil(cacheObject)
        XCTAssertEqual(cacheObject?.data, data)
    }
    
//    func testCacheExpired() {
//        cache = CacheStore(policy: NativebrikCachePolicy())
//        let data = "testData".data(using: .utf8)!
//        cache.set(key: "testKey", data: data)
//        __for_test_sync_datetime_offset(offset: 33 * 60 * 60 * 1000) // FIXME: set +9:00 for ci runtime
//        let cacheObject = cache.get(key: "testKey")
//        XCTAssertNil(cacheObject)
//    }
//    
//    func testInvalidateCache() {
//        cache = CacheStore(policy: NativebrikCachePolicy())
//        let data = "testData".data(using: .utf8)!
//        cache.set(key: "testKey", data: data)
//        cache.invalidate(key: "testKey")
//        let cacheObject = cache.get(key: "testKey")
//        XCTAssertNil(cacheObject)
//    }
}

final class GetDataTest: XCTestCase {
    func testGetDataAndCached() async {
        let cache = CacheStore(policy: NativebrikCachePolicy(staleTime: 60))
        let url = URL(string: "https://example.com")!
        let _ = await getData(url: url, cache: cache)
        let cached = cache.get(key: url.absoluteString)
        XCTAssertNotNil(cached)
        XCTAssertEqual(cached?.isStale(), false)
        
        __for_test_sync_datetime_offset(offset: 60 * 1000 + 9 * 60 * 60 * 1000) // FIXME: set +9:00 for ci runtime
        XCTAssertEqual(cached?.isStale(), true)
    }
}
