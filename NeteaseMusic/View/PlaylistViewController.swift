//
//  PlaylistViewController.swift
//  NeteaseMusic
//
//  Created by xjbeta on 2019/4/9.
//  Copyright © 2019 xjbeta. All rights reserved.
//

import Cocoa
import PromiseKit

class PlaylistViewController: NSViewController, ContentTabViewController {
    
    @IBOutlet weak var playAllButton: NSButton!
    @IBOutlet weak var subscribeButton: SubscribeButton!
    @IBOutlet weak var coverTabView: NSTabView!
    @IBOutlet weak var coverImageView: NSImageView!
    @IBOutlet weak var titleTextFiled: NSTextField!
    @IBOutlet weak var dateTextField: NSTextField!
    
    @IBOutlet weak var playCountTextField: NSTextField!
    @IBOutlet weak var trackCountTextField: NSTextField!
    @IBOutlet weak var descriptionTextField: NSTextField!
    @IBOutlet weak var artistTextField: NSTextField!
    
    @IBOutlet weak var descriptionStackView: NSStackView!
    @IBOutlet weak var countAndViewsStackView: NSStackView!
    @IBOutlet weak var artistStackView: NSStackView!
    
    @IBAction func playPlaylist(_ sender: Any) {
        if (sender as? NSButton) == playAllButton {
            PlayCore.shared.start(tracks)
        }
    }
    
    @IBAction func subscribe(_ sender: SubscribeButton) {
        guard playlistId > 0 else { return }
        let id = playlistId
        sender.isEnabled = false
        let subscribed = sender.subscribed
        let api = PlayCore.shared.api
        
        api.subscribe(id, unsubscribe: subscribed, type: .playlist)
            .ensure(on: .main) {
                sender.isEnabled = true
        }.done {
            sender.subscribed = !sender.subscribed
            guard let vc = self.view.window?.windowController?.contentViewController as? MainViewController else { return }
            vc.children.compactMap {
                $0 as? SidebarViewController
            }.first?.updatePlaylists()
            print("playlist subscribe / unsubscribe success")
        }.catch {
            print($0)
        }
    }
    
    lazy var menuContainer: (menu: NSMenu?, menuController: TAAPMenuController?) = {
        var objects: NSArray?
        Bundle.main.loadNibNamed(.init("TAAPMenu"), owner: nil, topLevelObjects: &objects)
        let mc = objects?.compactMap {
            $0 as? TAAPMenuController
        }.first
        let m = objects?.compactMap {
            $0 as? NSMenu
        }.first
        return (m, mc)
    }()
    
    var sidebarItemObserver: NSKeyValueObservation?
    var tracks: [Track] {
        get {
            return trackTableViewController()?.tracks ?? []
        }
        set {
            trackTableViewController()?.tracks = newValue
        }
    }
    
    var playlistId = -1
    var playlistType: SidebarViewController.ItemType = .none
    
    private let api = PlayCore.shared.api
    
    override func viewDidLoad() {
        super.viewDidLoad()
        menuContainer.menuController?.delegate = self
        
        coverImageView.wantsLayer = true
        coverImageView.layer?.cornerRadius = 3
        coverImageView.layer?.borderWidth = 0.5
        coverImageView.layer?.borderColor = NSColor.tertiaryLabelColor.cgColor
        
    }
    
    func initContent() -> Promise<()> {
        guard let item = ViewControllerManager.shared.selectedSidebarItem,
              [.createdPlaylist,
               .subscribedPlaylist,
               .favourite,
               .discoverPlaylist,
               .album,
               .topSongs,
               .fmTrash].contains(item.type)
              else {
            return .init(error: ContentTabInitError.wrongTab)
        }
        
        playlistId = item.id
        playlistType = item.type
        trackTableViewController()?.playlistId = item.id
        trackTableViewController()?.playlistType = item.type
        trackTableViewController()?.tableView.menu = menuContainer.menu
        
        initPlaylistInfo()
        
        return initPlaylistContent()
    }
    
    func initPlaylistInfo() {
        var typeList = [SidebarViewController.ItemType]()
        tracks = []
        
        coverImageView.image = nil
        titleTextFiled.stringValue = ""
        playCountTextField.integerValue = 0
        trackCountTextField.integerValue = 0
        descriptionTextField.stringValue = ""
        descriptionTextField.toolTip = ""
        
        playAllButton.isHidden = playlistType == .fmTrash
        typeList = [.album, .topSongs, .discoverPlaylist]
        countAndViewsStackView.isHidden = typeList.contains(playlistType)
        artistStackView.isHidden = playlistType != .album
        typeList = [.topSongs, .discoverPlaylist, .favourite, .fmTrash]
        subscribeButton.isHidden = typeList.contains(playlistType)
        subscribeButton.isEnabled = true
        descriptionStackView.isHidden = playlistType == .topSongs
        
        let isRecommandSongs = playlistType == .discoverPlaylist && playlistId == -114514
        
        coverTabView.selectTabViewItem(at: isRecommandSongs ? 1 : 0)
        if isRecommandSongs {
            let date = Date()
            let formatter = DateFormatter()
            formatter.dateFormat = "dd"
            dateTextField.textColor = .nColor
            dateTextField.stringValue = formatter.string(from: date)
        }
    }
    
    func initPlaylistContent() -> Promise<()> {
        let id = playlistId
        switch playlistType {
        case .album:
            return initPlaylistWithAlbum(id)
        case .topSongs:
            return initPlaylistWithTopSongs(id)
        case .subscribedPlaylist, .createdPlaylist, .favourite:
            return initPlaylist(id)
        case .discoverPlaylist:
            if id == -114514 {
                return initPlaylistWithRecommandSongs()
            } else {
                return initPlaylist(id)
            }
        case .fmTrash:
            return initFMTrashList()
        default:
            return .init(error: ContentTabInitError.wrongTab)
        }
    }
    
    func initPlaylist(_ id: Int) -> Promise<()> {
        api.playlistDetail(id).done(on: .main) {
            guard self.playlistId == id else { return }
            self.coverImageView.setImage($0.coverImgUrl.absoluteString, true)
            self.titleTextFiled.stringValue = self.playlistType == .favourite ? "我喜欢的音乐" : $0.name
            let descriptionStr = $0.description ?? "none"
            self.descriptionTextField.stringValue = descriptionStr
            self.descriptionTextField.toolTip = descriptionStr
            self.playCountTextField.integerValue = $0.playCount
            self.trackCountTextField.integerValue = $0.trackCount
            self.tracks = $0.tracks?.initIndexes() ?? []
            
            self.subscribeButton.isEnabled = $0.creator?.userId != ViewControllerManager.shared.userId
            self.subscribeButton.subscribed = $0.subscribed
        }
    }
    
    func initPlaylistWithRecommandSongs() -> Promise<()> {
        api.recommendSongs().done(on: .main) {
            guard self.playlistId == -114514 else { return }
            self.titleTextFiled.stringValue = "每日歌曲推荐"
            self.descriptionTextField.stringValue = "根据你的音乐口味生成, 每天6:00更新"
            self.tracks = $0.initIndexes()
        }
    }
    
    func initPlaylistWithAlbum(_ id: Int) -> Promise<()> {
        when(fulfilled: api.album(id), api.albumSublist()).done(on: .main) {
            self.coverImageView.setImage($0.0.album.picUrl?.absoluteString, true)
            self.titleTextFiled.stringValue = $0.0.album.name
            self.descriptionTextField.stringValue = $0.0.album.des ?? "none"
            self.descriptionTextField.toolTip = $0.0.album.des
            self.artistTextField.stringValue = $0.0.album.artists?.artistsString() ?? ""
            self.tracks = $0.0.songs.initIndexes()
            
            let subscribed = $0.1.map {
                $0.id
            }.contains($0.0.album.id)
            
            self.subscribeButton.subscribed = subscribed
        }
    }
    
    func initPlaylistWithTopSongs(_ id: Int) -> Promise<()> {
        api.artist(id).done(on: .main) {
            self.coverImageView.setImage($0.artist.picUrl, true)
            self.titleTextFiled.stringValue = $0.artist.name + "'s Top 50 Songs"
            self.tracks = $0.hotSongs.initIndexes()
            
        }
    }
    
    func initFMTrashList() -> Promise<()> {
        api.fmTrashList().done(on: .main) {
            let t = "simple mode?"
            self.titleTextFiled.stringValue = "Trash."
            self.tracks = $0.initIndexes()
        }
    }
    
    func trackTableViewController() -> TrackTableViewController? {
        let vc = children.compactMap {
            $0 as? TrackTableViewController
        }.first
        return vc
    }
    
    deinit {
        sidebarItemObserver?.invalidate()
    }
}

extension PlaylistViewController: TAAPMenuDelegate {
    func selectedItems() -> (id: [Int], items: [Any]) {
        guard let vc = trackTableViewController() else { return ([], []) }
        let items = tracks.enumerated().filter {
            vc.tableView.selectedIndexs().contains($0.offset)
        }.map {
            $0.element
        }
        return (items.map({ $0.id }), items)
    }
    
    func presentNewPlaylist(_ newPlaylisyVC: NewPlaylistViewController) {
        guard newPlaylisyVC.presentingViewController == nil else { return }
        self.presentAsSheet(newPlaylisyVC)
    }
    
    func removeSuccess(ids: [Int], newItem: Any?) {
        guard let vc = trackTableViewController() else { return }
        switch playlistType {
        case .discoverPlaylist:
            guard let item = newItem as? Track,
                let id = ids.first,
                let i = vc.tracks.enumerated().first(where: { $0.element.id == id })?.offset else { return }
            
            let todo = "check playable"
            item.index = vc.tracks[i].index
            vc.tracks[i] = item
        default:
            vc.tracks.removeAll {
                ids.contains($0.id)
            }
        }
    }
    
    func shouldReloadData() {
        initPlaylistContent()
    }
    
    func tableViewList() -> (type: SidebarViewController.ItemType, id: Int, contentType: TAAPItemsType) {
        return (playlistType, playlistId, .song)
    }
    
}
