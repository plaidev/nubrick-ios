//
//  network.swift
//  Nubrick
//
//  Created by Takuma Jimbo on 2025/03/14.
//

import Foundation

import XCTest
@testable import NubrickLocal

final class GetDataTests: XCTestCase {
    func testGetDataReturnsResponse() async {
        let url = URL(string: "https://example.com")!
        let result = await getData(url: url)

        switch result {
        case .success(let data):
            XCTAssertFalse(data.isEmpty)
        case .failure(let error):
            XCTFail("Expected a response, got \(error)")
        }
    }
}
