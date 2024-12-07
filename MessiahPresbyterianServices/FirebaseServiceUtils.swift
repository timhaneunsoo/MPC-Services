//
//  FirebaseServiceUtils.swift
//

import FirebaseStorage
import Foundation

func fetchServiceAccountFromStorage(completion: @escaping (Result<URL, Error>) -> Void) {
    let storage = Storage.storage()
    let storageRef = storage.reference(withPath: "config/service_account.json")

    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("service_account.json")
    storageRef.write(toFile: tempURL) { url, error in
        if let error = error {
            completion(.failure(error))
            return
        }
        completion(.success(tempURL))
    }
}
