import Foundation
import PDFKit

struct GoogleDriveHelper {
    static func fetchAccessToken(completion: @escaping (Result<String, Error>) -> Void) {
        generateAccessToken { token in
            if let token = token {
                print("Successfully fetched Access Token:", token)
                completion(.success(token))
            } else {
                let error = NSError(domain: "GoogleDriveHelper", code: 401, userInfo: [NSLocalizedDescriptionKey: "Failed to generate access token."])
                print("Failed to fetch Access Token.")
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

    static func fetchFileAsText(from file: GDriveFile, accessToken: String, completion: @escaping (Result<String, Error>) -> Void) {
        let fileId = file.id // Use `file.id` directly since it's non-optional
        let urlString = "https://www.googleapis.com/drive/v3/files/\(fileId)/export?mimeType=text/plain"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "GoogleDriveHelper", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL for text export."])))
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

            guard let data = data, let text = String(data: data, encoding: .utf8) else {
                let error = NSError(domain: "GoogleDriveHelper", code: 404, userInfo: [NSLocalizedDescriptionKey: "Failed to retrieve text content."])
                completion(.failure(error))
                return
            }

            completion(.success(text))
        }.resume()
    }

    static func downloadFile(from file: GDriveFile, accessToken: String, completion: @escaping (Result<Data, Error>) -> Void) {
        let isGoogleDoc = file.mimeType?.starts(with: "application/vnd.google-apps.") ?? false
        let urlString: String

        if isGoogleDoc {
            urlString = "https://www.googleapis.com/drive/v3/files/\(file.id)/export?mimeType=application/pdf"
        } else {
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
}
