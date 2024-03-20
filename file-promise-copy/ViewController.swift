//
//  ViewController.swift
//  file-promise-copy
//
//  Created by Florian on 2024-03-20.
//

import Cocoa
import UniformTypeIdentifiers

class ViewController: NSViewController {

    @IBOutlet private weak var tableView: NSTableView!

    private var filePromiseQueue = OperationQueue()

    override var representedObject: Any? {
        didSet {
            if let tableView = tableView {
                tableView.reloadData()
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.delegate = self
        tableView.dataSource = self
        tableView.registerForDraggedTypes([.fileListTableRow])
        tableView.setDraggingSourceOperationMask(.copy, forLocal: false)
    }

    @IBAction func openDocument(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true

        if let window = self.view.window {
            panel.beginSheetModal(for: window) { (response) in
                if response == NSApplication.ModalResponse.OK {
                    self.representedObject = panel.urls
                }
            }
        }
    }

    @IBAction func copy(_ sender: Any?) {
        guard let urls = representedObject as? [URL] else { return }

        let itemIndexes = tableView.selectedRowIndexes
        if itemIndexes.isEmpty {
            return
        }

        var filePromises = [FilePromiseProvider]()
        for idx in itemIndexes {
            var userInfo = [String: Any]()
            userInfo[FilePromiseProvider.UserInfoKeys.fileURL] = urls[idx]

            let filePromise = FilePromiseProvider(fileType: UTType.fileURL.identifier, delegate: self)
            filePromise.userInfo = userInfo
            filePromises.append(filePromise)
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects(filePromises)
    }
}

extension NSPasteboard.PasteboardType {
    static let fileListTableRow = NSPasteboard.PasteboardType("de.fheidenreich.FileList.internalTableDragType")
}

extension ViewController: NSTableViewDelegate, NSTableViewDataSource {

    // MARK: - NSTableViewDataSource -
    func numberOfRows(in tableView: NSTableView) -> Int {
        guard let urls = representedObject as? [URL] else { return 0 }

        return urls.count
    }

    // MARK: - NSTableViewDelegate -
    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        guard let urls = representedObject as? [URL] else { return nil }

        var userInfo = [String: Any]()
        userInfo[FilePromiseProvider.UserInfoKeys.row] = row
        userInfo[FilePromiseProvider.UserInfoKeys.fileURL] = urls[row]

        let fpp = FilePromiseProvider(fileType: UTType.fileURL.identifier, delegate: self)
        fpp.userInfo = userInfo
        return fpp
    }

    private static let cellIdentifier = NSUserInterfaceItemIdentifier(rawValue: "Cell")

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let urls = representedObject as? [URL] else { return nil }

        if let cell = tableView.makeView(withIdentifier: ViewController.cellIdentifier, owner: nil) as? NSTableCellView {
            let url = urls[row]
            cell.textField?.stringValue = url.lastPathComponent
            return cell
        }
        return nil
    }
}

// MARK: - NSFilePromiseProviderDelegate -
extension ViewController: NSFilePromiseProviderDelegate {

    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, fileNameForType fileType: String) -> String {
        let fileURL = queryFileURL(from: filePromiseProvider)
        return fileURL?.lastPathComponent ?? ""
    }

    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, writePromiseTo url: URL, completionHandler: @escaping (Error?) -> Void) {

        do {
            if let atURL = queryFileURL(from: filePromiseProvider) {
                try FileManager.default.copyItem(at: atURL, to: url)
            }
            completionHandler(nil)
        } catch let error {
            OperationQueue.main.addOperation {
                self.presentError(error, modalFor: self.view.window!, delegate: nil, didPresent: nil, contextInfo: nil)
            }
            completionHandler(error)
        }
    }

    func operationQueue(for filePromiseProvider: NSFilePromiseProvider) -> OperationQueue {
        return filePromiseQueue
    }

    private func queryFileURL(from filePromiseProvider: NSFilePromiseProvider) -> URL? {
        if let userInfo = filePromiseProvider.userInfo as? [String: Any] {
           return userInfo[FilePromiseProvider.UserInfoKeys.fileURL] as? URL
        }
        return nil
    }
}
