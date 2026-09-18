#!/usr/bin/env swift

import AppKit
import CoreGraphics
import Foundation

let canvasSize: CGFloat = 1024
let outputDirectoryURL: URL = URL(
    fileURLWithPath: CommandLine.arguments.dropFirst().first
        ?? "iOS-Template/ProgressDiary/Assets.xcassets/AppIcon.appiconset",
    isDirectory: true
)

struct AppIconPaletteData {
    let backgroundColor: NSColor
    let notebookColor: NSColor
    let pageColor: NSColor
    let inactiveCellColor: NSColor
    let activeCellColors: [NSColor]
    let bookmarkColor: NSColor
}

let standardPaletteData: AppIconPaletteData = AppIconPaletteData(
    backgroundColor: NSColor(red: 0.055, green: 0.105, blue: 0.180, alpha: 1),
    notebookColor: NSColor(red: 0.095, green: 0.170, blue: 0.275, alpha: 1),
    pageColor: NSColor(red: 0.970, green: 0.955, blue: 0.885, alpha: 1),
    inactiveCellColor: NSColor(red: 0.790, green: 0.815, blue: 0.750, alpha: 1),
    activeCellColors: [
        NSColor(red: 0.690, green: 0.870, blue: 0.300, alpha: 1),
        NSColor(red: 0.420, green: 0.750, blue: 0.260, alpha: 1),
        NSColor(red: 0.160, green: 0.560, blue: 0.300, alpha: 1),
    ],
    bookmarkColor: NSColor(red: 1.000, green: 0.700, blue: 0.160, alpha: 1)
)

let darkPaletteData: AppIconPaletteData = AppIconPaletteData(
    backgroundColor: NSColor(red: 0.015, green: 0.035, blue: 0.065, alpha: 1),
    notebookColor: NSColor(red: 0.070, green: 0.120, blue: 0.195, alpha: 1),
    pageColor: NSColor(red: 0.900, green: 0.920, blue: 0.850, alpha: 1),
    inactiveCellColor: NSColor(red: 0.620, green: 0.660, blue: 0.610, alpha: 1),
    activeCellColors: [
        NSColor(red: 0.710, green: 0.910, blue: 0.330, alpha: 1),
        NSColor(red: 0.410, green: 0.790, blue: 0.290, alpha: 1),
        NSColor(red: 0.130, green: 0.610, blue: 0.330, alpha: 1),
    ],
    bookmarkColor: NSColor(red: 1.000, green: 0.620, blue: 0.120, alpha: 1)
)

let tintedPaletteData: AppIconPaletteData = AppIconPaletteData(
    backgroundColor: NSColor(red: 0.080, green: 0.080, blue: 0.080, alpha: 1),
    notebookColor: NSColor(red: 0.190, green: 0.190, blue: 0.190, alpha: 1),
    pageColor: NSColor(red: 0.930, green: 0.930, blue: 0.930, alpha: 1),
    inactiveCellColor: NSColor(red: 0.660, green: 0.660, blue: 0.660, alpha: 1),
    activeCellColors: [
        NSColor(red: 0.800, green: 0.800, blue: 0.800, alpha: 1),
        NSColor(red: 0.590, green: 0.590, blue: 0.590, alpha: 1),
        NSColor(red: 0.360, green: 0.360, blue: 0.360, alpha: 1),
    ],
    bookmarkColor: NSColor.white
)

// WHY: keeping the complete composition in one function makes every exported appearance share identical geometry.
func makeAppIconImage(using paletteData: AppIconPaletteData) -> NSImage {
    let image: NSImage = NSImage(size: NSSize(width: canvasSize, height: canvasSize))
    image.lockFocus()
    guard let context: CGContext = NSGraphicsContext.current?.cgContext else {
        fatalError("Unable to create the app icon drawing context.")
    }

    context.setFillColor(paletteData.backgroundColor.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: canvasSize, height: canvasSize))
    drawNotebook(in: context, paletteData: paletteData)
    image.unlockFocus()
    return image
}

// WHY: the notebook silhouette communicates daily writing before the smaller heatmap details become visible.
func drawNotebook(in context: CGContext, paletteData: AppIconPaletteData) {
    let coverRectangle: CGRect = CGRect(x: 194, y: 154, width: 636, height: 716)
    let coverPath: CGPath = CGPath(roundedRect: coverRectangle, cornerWidth: 92, cornerHeight: 92, transform: nil)
    context.setFillColor(paletteData.notebookColor.cgColor)
    context.addPath(coverPath)
    context.fillPath()

    let pageRectangle: CGRect = CGRect(x: 252, y: 196, width: 520, height: 632)
    let pagePath: CGPath = CGPath(roundedRect: pageRectangle, cornerWidth: 62, cornerHeight: 62, transform: nil)
    context.setFillColor(paletteData.pageColor.cgColor)
    context.addPath(pagePath)
    context.fillPath()

    drawBinding(in: context)
    drawEntryLines(in: context, color: paletteData.notebookColor)
    drawHeatmap(in: context, paletteData: paletteData)
    drawBookmark(in: context, color: paletteData.bookmarkColor)
}

// WHY: oversized binding marks remain legible after iOS reduces the artwork to notification size.
func drawBinding(in context: CGContext) {
    context.setStrokeColor(NSColor.white.withAlphaComponent(0.94).cgColor)
    context.setLineWidth(24)
    context.setLineCap(.round)
    let bindingYCoordinates: [CGFloat] = [292, 414, 536, 658]
    for bindingY: CGFloat in bindingYCoordinates {
        context.move(to: CGPoint(x: 164, y: bindingY))
        context.addLine(to: CGPoint(x: 280, y: bindingY))
        context.strokePath()
    }
}

// WHY: two restrained lines identify the page as a diary without relying on language-specific text.
func drawEntryLines(in context: CGContext, color: NSColor) {
    context.setStrokeColor(color.withAlphaComponent(0.72).cgColor)
    context.setLineWidth(26)
    context.setLineCap(.round)
    let lineDataItems: [(startX: CGFloat, endX: CGFloat, y: CGFloat)] = [
        (342, 682, 692),
        (342, 606, 626),
    ]
    for lineData: (startX: CGFloat, endX: CGFloat, y: CGFloat) in lineDataItems {
        context.move(to: CGPoint(x: lineData.startX, y: lineData.y))
        context.addLine(to: CGPoint(x: lineData.endX, y: lineData.y))
        context.strokePath()
    }
}

// WHY: a compact activity grid distinguishes this diary from a generic notes application.
func drawHeatmap(in context: CGContext, paletteData: AppIconPaletteData) {
    let cellSize: CGFloat = 54
    let cellSpacing: CGFloat = 15
    let origin: CGPoint = CGPoint(x: 342, y: 330)
    let activeColorIndexes: [[Int?]] = [
        [nil, 0, nil, 1, 2],
        [0, 1, 2, 2, 1],
        [nil, 0, 1, 2, 2],
    ]

    for rowIndex: Int in activeColorIndexes.indices {
        let row: [Int?] = activeColorIndexes[rowIndex]
        for columnIndex: Int in row.indices {
            let color: NSColor = row[columnIndex].map { paletteData.activeCellColors[$0] }
                ?? paletteData.inactiveCellColor
            let x: CGFloat = origin.x + CGFloat(columnIndex) * (cellSize + cellSpacing)
            let y: CGFloat = origin.y + CGFloat(rowIndex) * (cellSize + cellSpacing)
            let cellRectangle: CGRect = CGRect(x: x, y: y, width: cellSize, height: cellSize)
            let cellPath: CGPath = CGPath(roundedRect: cellRectangle, cornerWidth: 13, cornerHeight: 13, transform: nil)
            context.setFillColor(color.cgColor)
            context.addPath(cellPath)
            context.fillPath()
        }
    }
}

// WHY: the warm accent creates a memorable focal point while preserving the text-free composition.
func drawBookmark(in context: CGContext, color: NSColor) {
    let bookmarkPath: CGMutablePath = CGMutablePath()
    bookmarkPath.move(to: CGPoint(x: 630, y: 752))
    bookmarkPath.addLine(to: CGPoint(x: 714, y: 752))
    bookmarkPath.addLine(to: CGPoint(x: 714, y: 570))
    bookmarkPath.addLine(to: CGPoint(x: 672, y: 606))
    bookmarkPath.addLine(to: CGPoint(x: 630, y: 570))
    bookmarkPath.closeSubpath()
    context.setFillColor(color.cgColor)
    context.addPath(bookmarkPath)
    context.fillPath()
}

// WHY: explicit PNG export keeps the committed asset deterministic and independent from Xcode previews.
func writePNG(_ image: NSImage, named filename: String) throws {
    guard let tiffData: Data = image.tiffRepresentation,
          let bitmapImageRepresentation: NSBitmapImageRep = NSBitmapImageRep(data: tiffData),
          let pngData: Data = bitmapImageRepresentation.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    let destinationURL: URL = outputDirectoryURL.appendingPathComponent(filename)
    try pngData.write(to: destinationURL, options: .atomic)
}

try FileManager.default.createDirectory(at: outputDirectoryURL, withIntermediateDirectories: true)
try writePNG(makeAppIconImage(using: standardPaletteData), named: "AppIcon.png")
try writePNG(makeAppIconImage(using: darkPaletteData), named: "AppIcon-Dark.png")
try writePNG(makeAppIconImage(using: tintedPaletteData), named: "AppIcon-Tinted.png")
