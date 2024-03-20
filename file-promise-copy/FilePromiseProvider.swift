//
//  FilePromiseProvider.swift
//  file-promise-copy
//
//  Created by Florian on 2024-03-20.
//

import AppKit

class FilePromiseProvider: NSFilePromiseProvider {

    struct UserInfoKeys {
        static let fileURL = "fileURLKey"
        static let row = "rowKey"
    }

    override func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        var types = super.writableTypes(for: pasteboard)
        if let userInfoDict = userInfo as? [String: Any] {
            if userInfoDict[UserInfoKeys.row] != nil {
                types.append(.fileListTableRow)
            }
            if userInfoDict[UserInfoKeys.fileURL] != nil {
                types.append(.fileURL)
                types.append(.string)
            }
        }
        return types
    }

    override func writingOptions(forType type: NSPasteboard.PasteboardType, pasteboard: NSPasteboard) -> NSPasteboard.WritingOptions {
        // If we return [] here, the app closes without delay and extra work by the system.
        // It seems that returning `.promise` for some of the types (which is done by the 
        // default implementation) flags some of the files to be made available to a
        // system-internal location, causing the app to block for a while when closing.
        super.writingOptions(forType: type, pasteboard: pasteboard)
    }

    override func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        guard let userInfoDict = userInfo as? [String: Any] else { return nil }

        switch type {
        case .fileListTableRow:
            if let row = userInfoDict[UserInfoKeys.row] as? Int {
                return row
            }

        case .fileURL:
            if let url = userInfoDict[UserInfoKeys.fileURL] as? NSURL {
                return url.pasteboardPropertyList(forType: type)
            }

        case .string:
            if let url = userInfoDict[UserInfoKeys.fileURL] as? NSURL {
                return url.lastPathComponent
            }

        default: break
        }

        return super.pasteboardPropertyList(forType: type)
    }
}

