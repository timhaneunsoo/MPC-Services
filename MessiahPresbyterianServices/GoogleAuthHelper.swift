//
//  GoogleAuthHelper.swift
//

import Foundation
import SwiftJWT

func generateAccessToken(completion: @escaping (String?) -> Void) {
    guard let filePath = Bundle.main.path(forResource: "service_account", ofType: "json"),
          let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let clientEmail = json["client_email"] as? String,
          let privateKey = json["private_key"] as? String else {
        completion(nil)
        return
    }

    let now = Int(Date().timeIntervalSince1970)
    let claims = GoogleJWTClaims(
        iss: clientEmail,
        scope: "https://www.googleapis.com/auth/drive.readonly",
        aud: "https://oauth2.googleapis.com/token",
        exp: now + 3600,
        iat: now
    )

    var jwt = JWT(claims: claims)
    let privateKeyData = privateKey.replacingOccurrences(of: "\\n", with: "\n").data(using: .utf8)!
    let signer = JWTSigner.rs256(privateKey: privateKeyData)

    do {
        let signedJWT = try jwt.sign(using: signer)
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=\(signedJWT)".data(using: .utf8)

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                print("Error fetching token: \(error.localizedDescription)")
                completion(nil)
                return
            }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let token = json["access_token"] as? String else {
                completion(nil)
                return
            }

            completion(token)
        }.resume()
    } catch {
        print("Error signing JWT: \(error.localizedDescription)")
        completion(nil)
    }
}

struct GoogleJWTClaims: Claims {
    let iss: String
    let scope: String
    let aud: String
    let exp: Int
    let iat: Int
}
