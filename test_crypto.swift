import Foundation
import CryptoKit
let keyB64 = "0ta0cRhx+zpudERcmK0TfWXm2os2lKW+hYkgNDHuzo9vx/4tSZYcltPmtdy4tZAyUEnv9wqss1JLcnOm+1M6Ow=="
let keyData = Data(base64Encoded: keyB64)!
let seed = keyData.prefix(32)
let privateKey = try! Curve25519.Signing.PrivateKey(rawRepresentation: seed)
let signature = try! privateKey.signature(for: "hello world".data(using: .utf8)!)
print("sig=\(signature.base64EncodedString())")
