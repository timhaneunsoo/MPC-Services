//
//  GoogleDriveHelper.swift
//

import Foundation
import FirebaseFirestore
import PDFKit

struct GoogleDriveHelper {
    static func fetchAccessToken(completion: @escaping (Result<String, Error>) -> Void) {
        generateAccessToken { token in
            if let token = token {
                completion(.success(token))
            } else {
                let error = NSError(domain: "GoogleDriveHelper", code: 401, userInfo: [NSLocalizedDescriptionKey: "Failed to generate access token."])
                completion(.failure(error))
            }
        }
    }

    static func fetchFiles(fromFolderID folderID: String, accessToken: String, pageToken: String? = nil, completion: @escaping (Result<[GDriveFile], Error>) -> Void) {
        var urlString = "https://www.googleapis.com/drive/v3/files?q='\(folderID)'+in+parents&fields=nextPageToken,files(id,name,mimeType)"
        if let token = pageToken {
            urlString += "&pageToken=\(token)"
        }

        guard let url = URL(string: urlString) else {
            let error = NSError(domain: "GoogleDriveHelper", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL for Google Drive API."])
            completion(.failure(error))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                let error = NSError(domain: "GoogleDriveHelper", code: 404, userInfo: [NSLocalizedDescriptionKey: "No data received from Google Drive API."])
                completion(.failure(error))
                return
            }

            do {
                let result = try JSONDecoder().decode(GDriveFileListWithToken.self, from: data)
                completion(.success(result.files))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    static func downloadFile(from file: GDriveFile, accessToken: String, completion: @escaping (Result<Data, Error>) -> Void) {
        let isGoogleDoc = file.mimeType?.starts(with: "application/vnd.google-apps.") ?? false
        var urlString: String

        if isGoogleDoc {
            // Use the export endpoint for Google Docs files
            urlString = "https://www.googleapis.com/drive/v3/files/\(file.id)/export?mimeType=application/pdf"
        } else {
            // Use the alt=media parameter for regular files
            urlString = "https://www.googleapis.com/drive/v3/files/\(file.id)?alt=media"
        }

        guard let url = URL(string: urlString) else {
            let error = NSError(domain: "GoogleDriveHelper", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL for downloading file."])
            completion(.failure(error))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                let error = NSError(domain: "GoogleDriveHelper", code: 404, userInfo: [NSLocalizedDescriptionKey: "No data received from Google Drive API."])
                completion(.failure(error))
                return
            }

            completion(.success(data))
        }.resume()
    }

    static func generateCombinedPDF(for files: [GDriveFile], accessToken: String, completion: @escaping (Result<URL, Error>) -> Void) {
        let combinedPDF = PDFDocument()
        let dispatchGroup = DispatchGroup()

        for file in files {
            dispatchGroup.enter()
            downloadFile(from: file, accessToken: accessToken) { result in
                switch result {
                case .success(let data):
                    if let songPDF = PDFDocument(data: data) {
                        for pageIndex in 0..<songPDF.pageCount {
                            if let page = songPDF.page(at: pageIndex) {
                                combinedPDF.insert(page, at: combinedPDF.pageCount)
                            }
                        }
                    }
                case .failure:
                    break
                }
                dispatchGroup.leave()
            }
        }

        dispatchGroup.notify(queue: .main) {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("CombinedSongs.pdf")
            if combinedPDF.write(to: tempURL) {
                completion(.success(tempURL))
            } else {
                let error = NSError(domain: "GoogleDriveHelper", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to save combined PDF file."])
                completion(.failure(error))
            }
        }
    }
}
