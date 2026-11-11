import AppKit
import Foundation
guard CommandLine.arguments.count == 2 else {
  fatalError("Usage: swift make_document_import_images.swift OUTPUT_DIRECTORY")
}
let directory = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
func render(name: String, title: String, lines: [(String, CGFloat)], type: NSBitmapImageRep.FileType) throws {
  let width: CGFloat = 1200, height: CGFloat = 1400
  let image = NSImage(size: NSSize(width: width, height: height))
  image.lockFocus()
  NSColor.white.setFill(); NSRect(x: 0, y: 0, width: width, height: height).fill()
  NSColor(calibratedRed: 0.10, green: 0.25, blue: 0.32, alpha: 1).setFill(); NSRect(x: 0, y: height - 115, width: width, height: 115).fill()
  (title as NSString).draw(at: NSPoint(x: 55, y: height - 80), withAttributes: [.font: NSFont.boldSystemFont(ofSize: 38), .foregroundColor: NSColor.white])
  var y = height - 160
  for (text, size) in lines {
    let style = NSMutableParagraphStyle(); style.lineSpacing = 8
    let attrs: [NSAttributedString.Key: Any] = [.font: size >= 30 ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size), .foregroundColor: NSColor.black, .paragraphStyle: style]
    let bounds = (text as NSString).boundingRect(with: NSSize(width: width - 110, height: 1200), options: [.usesLineFragmentOrigin], attributes: attrs)
    y -= ceil(bounds.height)
    (text as NSString).draw(in: NSRect(x: 55, y: y, width: width - 110, height: ceil(bounds.height) + 5), withAttributes: attrs)
    y -= 27
  }
  image.unlockFocus()
  guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff), let data = bitmap.representation(using: type, properties: [.compressionFactor: 0.95]) else { fatalError("Image output failed") }
  try data.write(to: directory.appendingPathComponent(name))
}
try render(name: "Canvas assessment.jpg", title: "Canvas  |  Assignments", lines: [
 ("32405 Human-Centred Design Research Methods", 34),
 ("Spring Session 2026", 26),
 ("Research synthesis memo", 38),
 ("Due 20 November 2026 at 5:00 pm", 28),
 ("20% of final result", 28),
 ("Individual written memo", 28),
 ("Submit a 1200-word memo connecting interview observations to design choices. Explain one study limitation and cite the course readings.", 28),
 ("Include a small traceability table linking observations, interpretations and proposed requirements. Use anonymised participant identifiers.", 28),
 ("Submit your memo as a PDF through Canvas.", 28)
], type: .jpeg)
try render(name: "Subject screenshot.png", title: "Subject information", lines: [
 ("55501 Interaction Prototyping", 36),
 ("Delivery: Spring Session 2026", 28),
 ("Credit Points: 6", 28),
 ("Subject Description", 32),
 ("Design and evaluate interactive prototypes through iterative testing and clear documentation of design decisions.", 28),
 ("Assessment task 1: Prototype walkthrough", 34),
 ("Description: Present an interactive prototype and explain two design decisions using observations from usability testing. Include a short evaluation summary.", 28),
 ("Type: Presentation", 28),
 ("Groupwork: Individual", 28),
 ("Weight: 40%", 28),
 ("Due: 2026-11-27", 28),
 ("Length: 5 minutes", 28)
], type: .png)
print("Created two fictional screenshot files")
