#!/usr/bin/env swift
//
// Generates the macOS app icon set for FileDateChanger.
//
// Renders a calendar card with an overlaid clock (echoing the app's
// `calendar.badge.clock` theme) at every required size and writes the PNGs plus
// Contents.json into FileDateChanger/Assets.xcassets/AppIcon.appiconset.
//
// Usage:  swift Tools/generate-appicon.swift
//
import AppKit
import Foundation

func rgb(_ r: Double, _ g: Double, _ b: Double) -> NSColor {
    NSColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: 1)
}

func makeIcon(size s: CGFloat) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(s), pixelsHigh: Int(s),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: s, height: s)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)!

    // Background squircle with vertical gradient.
    let margin = s * 0.06
    let tile = NSRect(x: margin, y: margin, width: s - 2 * margin, height: s - 2 * margin)
    let bg = NSBezierPath(roundedRect: tile, xRadius: tile.width * 0.2237, yRadius: tile.width * 0.2237)
    NSGraphicsContext.saveGraphicsState()
    bg.addClip()
    NSGradient(starting: rgb(110, 168, 254), ending: rgb(47, 107, 255))!.draw(in: tile, angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    // Calendar card.
    let cw = s * 0.50, ch = s * 0.44
    let card = NSRect(x: (s - cw) / 2, y: s * 0.54 - ch / 2, width: cw, height: ch)
    let cardPath = NSBezierPath(roundedRect: card, xRadius: s * 0.055, yRadius: s * 0.055)
    NSColor.white.setFill()
    cardPath.fill()

    // Red header band (clipped to the card's rounded top).
    NSGraphicsContext.saveGraphicsState()
    cardPath.addClip()
    let headerH = ch * 0.28
    rgb(255, 92, 84).setFill()
    NSBezierPath(rect: NSRect(x: card.minX, y: card.maxY - headerH, width: cw, height: headerH)).fill()
    NSGraphicsContext.restoreGraphicsState()

    // Binder rings.
    let ringW = s * 0.024, ringH = s * 0.07
    for fx in [0.38, 0.62] {
        let r = NSRect(x: card.minX + cw * CGFloat(fx) - ringW / 2,
                       y: card.maxY - ringH * 0.5, width: ringW, height: ringH)
        rgb(225, 228, 235).setFill()
        NSBezierPath(roundedRect: r, xRadius: ringW / 2, yRadius: ringW / 2).fill()
    }

    // Clock, overlapping the lower-right of the card.
    let cr = s * 0.155
    let c = NSPoint(x: s * 0.655, y: s * 0.40)
    let face = NSRect(x: c.x - cr, y: c.y - cr, width: cr * 2, height: cr * 2)
    // subtle outer halo so the clock reads against the card edge
    rgb(47, 107, 255).withAlphaComponent(0.18).setFill()
    NSBezierPath(ovalIn: face.insetBy(dx: -s * 0.02, dy: -s * 0.02)).fill()
    NSColor.white.setFill()
    NSBezierPath(ovalIn: face).fill()
    let ring = NSBezierPath(ovalIn: face.insetBy(dx: s * 0.011, dy: s * 0.011))
    ring.lineWidth = s * 0.022
    rgb(47, 107, 255).setStroke()
    ring.stroke()

    // Hands.
    let dark = rgb(40, 52, 90)
    func hand(angleDeg: Double, length: CGFloat, width: CGFloat) {
        let a = angleDeg * .pi / 180
        let p = NSBezierPath()
        p.move(to: c)
        p.line(to: NSPoint(x: c.x + cos(a) * length, y: c.y + sin(a) * length))
        p.lineWidth = width
        p.lineCapStyle = .round
        dark.setStroke()
        p.stroke()
    }
    hand(angleDeg: 90, length: cr * 0.62, width: s * 0.024)   // minute → up
    hand(angleDeg: 0, length: cr * 0.44, width: s * 0.028)    // hour → right
    let dotR = s * 0.018
    dark.setFill()
    NSBezierPath(ovalIn: NSRect(x: c.x - dotR, y: c.y - dotR, width: dotR * 2, height: dotR * 2)).fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

// Resolve the appiconset directory relative to this script's location.
let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let outDir = scriptURL.deletingLastPathComponent()
    .appendingPathComponent("FileDateChanger/Assets.xcassets/AppIcon.appiconset")

let slots: [(file: String, px: CGFloat, idiom: String, size: String, scale: String)] = [
    ("icon_16.png", 16, "mac", "16x16", "1x"),
    ("icon_16@2x.png", 32, "mac", "16x16", "2x"),
    ("icon_32.png", 32, "mac", "32x32", "1x"),
    ("icon_32@2x.png", 64, "mac", "32x32", "2x"),
    ("icon_128.png", 128, "mac", "128x128", "1x"),
    ("icon_128@2x.png", 256, "mac", "128x128", "2x"),
    ("icon_256.png", 256, "mac", "256x256", "1x"),
    ("icon_256@2x.png", 512, "mac", "256x256", "2x"),
    ("icon_512.png", 512, "mac", "512x512", "1x"),
    ("icon_512@2x.png", 1024, "mac", "512x512", "2x"),
]

for slot in slots {
    try makeIcon(size: slot.px).write(to: outDir.appendingPathComponent(slot.file))
    print("wrote \(slot.file) (\(Int(slot.px))px)")
}

let images = slots.map {
    "    { \"filename\" : \"\($0.file)\", \"idiom\" : \"\($0.idiom)\", \"scale\" : \"\($0.scale)\", \"size\" : \"\($0.size)\" }"
}.joined(separator: ",\n")
let contents = """
{
  "images" : [
\(images)
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}

"""
try contents.write(to: outDir.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
print("wrote Contents.json")
