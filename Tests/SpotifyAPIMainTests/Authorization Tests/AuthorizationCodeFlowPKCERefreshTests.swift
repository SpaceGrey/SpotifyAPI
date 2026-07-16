import Foundation
import XCTest
#if canImport(Combine)
import Combine
#else
import OpenCombine
import OpenCombineDispatch
import OpenCombineFoundation
#endif
@testable import SpotifyWebAPI
import SpotifyAPITestUtilities

final class AuthorizationCodeFlowPKCERefreshTests: SpotifyAPITestCase {

    static let allTests = [
        (
            "testRefreshRetainsExistingRefreshTokenWhenResponseDoesNotRotateIt",
            testRefreshRetainsExistingRefreshTokenWhenResponseDoesNotRotateIt
        )
    ]

    func testRefreshRetainsExistingRefreshTokenWhenResponseDoesNotRotateIt() {
        let authorizationManager = AuthorizationCodeFlowPKCEBackendManager(
            backend: NonRotatingPKCERefreshBackend(),
            accessToken: "expired-access-token",
            expirationDate: .distantPast,
            refreshToken: "existing-refresh-token",
            scopes: [.userReadPlaybackState]
        )
        let refreshFinished = expectation(description: "refresh finished")

        let cancellable = authorizationManager
            .refreshTokens(onlyIfExpired: false)
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                        case .finished:
                            XCTAssertEqual(
                                authorizationManager.accessToken,
                                "new-access-token"
                            )
                            XCTAssertEqual(
                                authorizationManager.refreshToken,
                                "existing-refresh-token"
                            )
                        case .failure(let error):
                            XCTFail("Unexpected refresh failure: \(error)")
                    }
                    refreshFinished.fulfill()
                },
                receiveValue: { }
            )

        wait(for: [refreshFinished], timeout: 1)
        _ = cancellable
    }
}

private struct NonRotatingPKCERefreshBackend: AuthorizationCodeFlowPKCEBackend {

    let clientId = "test-client-id"

    func requestAccessAndRefreshTokens(
        code: String,
        codeVerifier: String,
        redirectURIWithQuery: URL
    ) -> AnyPublisher<(data: Data, response: HTTPURLResponse), Error> {
        Fail(error: URLError(.unsupportedURL))
            .eraseToAnyPublisher()
    }

    func refreshTokens(
        refreshToken: String
    ) -> AnyPublisher<(data: Data, response: HTTPURLResponse), Error> {
        let data = Data(
            """
            {
                "access_token": "new-access-token",
                "expires_in": 3600
            }
            """.utf8
        )
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com/api/token")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!

        return Just((data: data, response: response))
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
}
