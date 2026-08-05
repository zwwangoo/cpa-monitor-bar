import Foundation
import XCTest
@testable import CPAMonitorBar

final class LocalCredentialTOMLTests: XCTestCase {
    func testRoundTripsEscapedAndUnicodeCredentials() throws {
        let document = LocalCredentialDocument(
            administrators: [
                LocalAdministratorCredential(
                    keeperRoot: "https://keeper.example/cpa",
                    password: "引号\"、反斜线\\和换行\n"
                ),
            ],
            providers: [
                LocalProviderCredential(
                    keeperRoot: "https://keeper.example/cpa",
                    providerID: "provider-一",
                    key: "sk-\"secret\"\\line\nnext"
                ),
            ]
        )

        let encoded = try LocalCredentialTOMLCodec.encode(document)
        let decoded = try LocalCredentialTOMLCodec.decode(encoded)

        XCTAssertEqual(decoded, document)
        let text = try XCTUnwrap(String(data: encoded, encoding: .utf8))
        XCTAssertTrue(text.contains("version = 1"))
        XCTAssertTrue(text.contains("[[administrator_credentials]]"))
        XCTAssertTrue(text.contains("[[provider_credentials]]"))
        XCTAssertFalse(text.contains("\\/"))
    }

    func testDecodeAcceptsBlankLinesAndFullLineComments() throws {
        let data = Data(#"""
        # 本文件包含明文凭证
        version = 1

        [[administrator_credentials]]
        keeper_root = "https://keeper.example/cpa"
        password = "secret"
        """#.utf8)

        let document = try LocalCredentialTOMLCodec.decode(data)

        XCTAssertEqual(document.administrators.count, 1)
        XCTAssertEqual(document.administrators[0].password, "secret")
        XCTAssertTrue(document.providers.isEmpty)
    }

    func testRejectsUnknownIncompleteDuplicateAndUnsupportedDocuments() {
        let invalidDocuments = [
            "version = 2\n",
            "version = 1\nunknown = \"value\"\n",
            "version = 1\n[[administrator_credentials]]\nkeeper_root = \"root\"\n",
            "version = 1\n[[provider_credentials]]\nkeeper_root = \"root\"\nprovider_id = \"id\"\n",
            "version = 1\n[[administrator_credentials]]\nkeeper_root = \"root\"\npassword = \"one\"\n[[administrator_credentials]]\nkeeper_root = \"root\"\npassword = \"two\"\n",
            "version = 1\n[[provider_credentials]]\nkeeper_root = \"root\"\nprovider_id = \"id\"\nkey = \"one\"\n[[provider_credentials]]\nkeeper_root = \"root\"\nprovider_id = \"id\"\nkey = \"two\"\n",
            "version = 1\n[[administrator_credentials]]\nkeeper_root = \"root\" trailing\npassword = \"secret\"\n",
        ]

        for document in invalidDocuments {
            XCTAssertThrowsError(
                try LocalCredentialTOMLCodec.decode(Data(document.utf8)),
                document
            )
        }
    }

    func testRejectsDuplicateFieldsAndEmptyScopes() {
        let invalidDocuments = [
            "version = 1\nversion = 1\n",
            "version = 1\n[[administrator_credentials]]\nkeeper_root = \"\"\npassword = \"secret\"\n",
            "version = 1\n[[provider_credentials]]\nkeeper_root = \"root\"\nprovider_id = \"\"\nkey = \"secret\"\n",
        ]

        for document in invalidDocuments {
            XCTAssertThrowsError(
                try LocalCredentialTOMLCodec.decode(Data(document.utf8)),
                document
            )
        }
    }

    func testRejectsInputAndOutputLargerThanOneMiB() {
        let oversized = Data(
            repeating: UInt8(ascii: "x"),
            count: LocalCredentialTOMLCodec.maximumBytes + 1
        )
        XCTAssertThrowsError(try LocalCredentialTOMLCodec.decode(oversized))

        let document = LocalCredentialDocument(
            administrators: [
                LocalAdministratorCredential(
                    keeperRoot: "root",
                    password: String(
                        repeating: "x",
                        count: LocalCredentialTOMLCodec.maximumBytes
                    )
                ),
            ],
            providers: []
        )
        XCTAssertThrowsError(try LocalCredentialTOMLCodec.encode(document))
    }
}
