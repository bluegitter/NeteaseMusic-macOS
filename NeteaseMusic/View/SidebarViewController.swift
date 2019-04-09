//
//  SidebarViewController.swift
//  NeteaseMusic
//
//  Created by xjbeta on 2019/4/5.
//  Copyright © 2019 xjbeta. All rights reserved.
//

import Cocoa

class SidebarViewController: NSViewController {
    @IBOutlet weak var tableView: NSTableView!
    struct TableViewItem {
        let title: String
        let icon: NSImage?
        let id: Int
        let isHeader: Bool
    }
    
    let defaultItems = [TableViewItem(title: "发现音乐", icon: nil, id: -1, isHeader: false),
                        TableViewItem(title: "私人FM", icon: nil, id: -1, isHeader: false),
                        TableViewItem(title: "创建的歌单", icon: nil, id: -1, isHeader: true),
                        TableViewItem(title: "收藏的歌单", icon: nil, id: -1, isHeader: true)]
    var tableViewItems = [TableViewItem]()
    var tableViewSelectedRow = -1
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableViewItems = defaultItems
        
        PlayCore.shared.api.isLogin().then { _ in
            PlayCore.shared.api.userPlaylist()
            }.done(on: .main) {
                let created = $0.filter {
                    !$0.subscribed
                    }.map {
                        TableViewItem(title: $0.name, icon: nil, id: $0.id, isHeader: false)
                }
                guard let indexOfCreated = self.tableViewItems.enumerated().filter({
                    $0.element.title == "创建的歌单"
                }).first?.offset else {
                    return
                }
                
                self.tableViewItems.insert(contentsOf: created, at: indexOfCreated + 1)
                
                let subscribed = $0.filter {
                    $0.subscribed
                    }.map {
                        TableViewItem(title: $0.name, icon: nil, id: $0.id, isHeader: false)
                }
                self.tableViewItems.append(contentsOf: subscribed)
                self.tableView.reloadData()
            }.catch {
                print($0)
        }
    }
    
}

extension SidebarViewController: NSTableViewDelegate, NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return tableViewItems.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let item = tableViewItems[safe: row] else { return nil }
        
        if item.isHeader {
            guard let view = tableView.makeView(withIdentifier: .sidebarHeaderTableCellView, owner: self) as? SidebarHeaderTableCellView else { return nil }
            view.titleButton.title = item.title
            return view
        } else {
            guard let view =  tableView.makeView(withIdentifier: .sidebarTableCellView, owner: self) as? SidebarTableCellView else { return nil }
            view.textField?.stringValue = item.title
            return view
        }
        
    }

    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        guard let item = tableViewItems[safe: row] else { return false }
        return !item.isHeader
    }
    
    func tableViewSelectionIsChanging(_ notification: Notification) {
        if tableViewSelectedRow >= 0, tableViewSelectedRow < tableView.numberOfRows,
            let view = tableView.view(atColumn: tableView.selectedColumn, row: tableViewSelectedRow, makeIfNecessary: false) as? SidebarTableCellView {
            view.isSelected = false
        }
        if tableView.selectedRow >= 0, tableView.selectedRow < tableView.numberOfRows,
            let view = tableView.view(atColumn: tableView.selectedColumn, row: tableView.selectedRow, makeIfNecessary: false) as? SidebarTableCellView {
            view.isSelected = true
        }
        
        tableViewSelectedRow = tableView.selectedRow
        
    }
}
