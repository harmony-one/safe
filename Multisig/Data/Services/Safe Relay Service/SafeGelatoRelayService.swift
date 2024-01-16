//
//  SafeGelatoRelayService.swift
//  Multisig
//
//  Created by Vitaly on 05.03.23.
//  Copyright © 2023 Gnosis Ltd. All rights reserved.
//

import Foundation

class SafeGelatoRelayService {

    var url: URL

    private let httpClient: JSONHTTPClient
    private let mockHttpClient: MockJSONHttpClient

    var jsonDecoder: JSONDecoder {
        httpClient.jsonDecoder
    }

    init(url: URL, logger: Logger) {
        self.url = url
        httpClient = JSONHTTPClient(url: url, logger: logger)
        httpClient.jsonDecoder.dateDecodingStrategy = .millisecondsSince1970
        mockHttpClient = MockJSONHttpClient()
    }

    @discardableResult
    func execute<T: JSONRequest>(request: T) throws -> T.ResponseType {
        try httpClient.execute(request: request)
    }

    func asyncExecute<T: JSONRequest>(request: T, completion: @escaping (Result<T.ResponseType, Error>) -> Void) -> URLSessionTask? {
        httpClient.asyncExecute(request: request, completion: completion)
    }

    // Returns mocked response in completion
    func asyncExecuteMock<T: JSONRequest>(request: T, completion: @escaping (Result<T.ResponseType, Error>) -> Void) -> URLSessionTask? {
        mockHttpClient.asyncExecute(request: request, completion: completion)
    }
}
