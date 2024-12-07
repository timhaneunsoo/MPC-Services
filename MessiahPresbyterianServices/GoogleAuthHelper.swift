//
//  GoogleAuthHelper.swift
//

import Foundation
import SwiftJWT

func generateAccessToken(completion: @escaping (String?) -> Void) {
    // First, fetch the service account file from Firebase Storage
    fetchServiceAccountFromStorage { result in
        switch result {
        case .success(let fileURL):
            do {
                // Read and parse the service account file
                let data = try Data(contentsOf: fileURL)
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let clientEmail = json["client_email"] as? String,
                      let privateKey = json["private_key"] as? String else {
                    print("Error: Invalid service account format.")
                    completion(nil)
                    return
                }

                // Create JWT claims
                let now = Int(Date().timeIntervalSince1970)
                let claims = GoogleJWTClaims(
                    iss: clientEmail,
                    scope: "https://www.googleapis.com/auth/drive",
                    aud: "https://oauth2.googleapis.com/token",
                    exp: now + 3600,
                    iat: now
                )

                // Sign the JWT
                var jwt = JWT(claims: claims)
                let privateKeyData = privateKey.replacingOccurrences(of: "\\n", with: "\n").data(using: .utf8)!
                let signer = JWTSigner.rs256(privateKey: privateKeyData)

                let signedJWT = try jwt.sign(using: signer)

                // Create the token request
                var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
                request.httpMethod = "POST"
                request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                request.httpBody = "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=\(signedJWT)".data(using: .utf8)

                // Perform the token request
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
                print("Error reading or parsing service account file: \(error.localizedDescription)")
                completion(nil)
            }
        case .failure(let error):
            print("Error fetching service account from Firebase: \(error.localizedDescription)")
            completion(nil)
        }
    }
}

struct GoogleJWTClaims: Claims {
    let iss: String
    let scope: String
    let aud: String
    let exp: Int
    let iat: Int
}
