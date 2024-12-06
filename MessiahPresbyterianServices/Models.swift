// Models.swift

import Foundation

struct GDriveFile: Codable, Identifiable {
    let id: String
    let name: String
    let mimeType: String?
}

struct GDriveFileList: Codable {
    let files: [GDriveFile]
}

struct GDriveFileListWithToken: Codable {
    let files: [GDriveFile]
    let nextPageToken: String?
}

// Set Model
struct SetModel: Identifiable {
    let id: String
    let name: String
}

// Organization model
struct Organization: Identifiable {
    let id: String
    let name: String
}
