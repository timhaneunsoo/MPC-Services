// Models.swift

import Foundation

struct GDriveFile: Codable, Identifiable {
    let id: String
    let name: String
    let mimeType: String
}

struct GDriveFileList: Codable {
    let files: [GDriveFile]
}
