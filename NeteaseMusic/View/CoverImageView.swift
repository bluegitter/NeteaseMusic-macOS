//
//  CoverImageView.swift
//  NeteaseMusic
//
//  Created by xjbeta on 2019/5/11.
//  Copyright © 2019 xjbeta. All rights reserved.
//

import Cocoa

class CoverImageView: NSImageView {
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 0.5
        layer?.borderColor = NSColor.tertiaryLabelColor.cgColor
    }
    
    override func mouseDown(with event: NSEvent) {
        
    }
}
