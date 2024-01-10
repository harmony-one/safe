//
//  KeychainServiceIntegrationTests.swift
//  MultisigIntegrationTests
//
//  Created by Andrey Scherbovich on 10.09.20.
//  Copyright © 2020 Gnosis Ltd. All rights reserved.
//

import XCTest
@testable import Multisig

class KeychainServiceIntegrationTests: XCTestCase {
    let data = Data(repeating: 7, count: 32)
    let keychainService = KeychainService(identifier: "KeychainIntegrationTest")

    override func setUp() {
        super.setUp()
        try? keychainService.destroy()
    }

    func test_whenCreated_thenCanBeDestroyed() {
        XCTAssertNoThrow(try keychainService.save(data: data, forKey: "testKey"))
        XCTAssertNoThrow(try keychainService.save(data: data, forKey: "testKey1"))
        XCTAssertNoThrow(try keychainService.destroy())
        XCTAssertNil(try keychainService.data(forKey: "testKey"))
        XCTAssertNil(try keychainService.data(forKey: "testKey1"))
    }

    func test_whenSaved_thenCanFetch() {
        XCTAssertNoThrow(try keychainService.save(data: data, forKey: "testKey"))
        var savedData: Data? = nil
        XCTAssertNoThrow(savedData = try keychainService.data(forKey: "testKey"))
        XCTAssertEqual(savedData, data)
    }

    func test_whenRemoved_thenCanNotFind() {
        XCTAssertNoThrow(try keychainService.save(data: data, forKey: "testKey"))
        XCTAssertNoThrow(try keychainService.removeData(forKey: "testKey"))
        XCTAssertNil(try keychainService.data(forKey: "testKey"))
    }

    func test_whenUpdatesExistingValue_thenItIsUpdated() {
        XCTAssertNoThrow(try keychainService.save(data: data, forKey: "testKey"))
        let otherData = Data(repeating: 3, count: 33)
        XCTAssertThrowsError(try keychainService.save(data: otherData, forKey: "testKey"))
    }

    func test_whenRemovesInexistingKey_thenItIsOK() {
        XCTAssertNoThrow(try keychainService.removeData(forKey: "SOME_KEY"))
    }
}
