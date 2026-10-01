import AppKit
import ImageIO

// Deterministic marketing layout: generated editorial art + unmodified real app captures.
// Run from repo root. Writes both App Store image sizes and an overview contact sheet.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let ink = NSColor(srgbRed: 0.09, green: 0.25, blue: 0.20, alpha: 1)
let paper = NSColor(srgbRed: 0.965, green: 0.953, blue: 0.922, alpha: 1)
let clay = NSColor(srgbRed: 0.70, green: 0.34, blue: 0.24, alpha: 1)
struct Panel { let name: String; let title: String; let subtitle: String; let art: String; let screen: String; let badge: String; let dark: Bool }
let panels = [
 Panel(name:"01-make-people-feel-remembered",title:"Make people\nfeel remembered.",subtitle:"Thoughtful plans. Little gestures. Time together.",art:"gestures",screen:"studio",badge:"A LITTLE MORE INTENTION",dark:false),
 Panel(name:"02-a-plan-with-heart",title:"A plan with\na little heart.",subtitle:"One personal intention. A budget that feels right.",art:"picnic",screen:"plan",badge:"FROM DATE TO MEANINGFUL GESTURE",dark:false),
 Panel(name:"03-moments-to-keep",title:"Keep the moments.\nNot just the dates.",subtitle:"A private journal of the time you share.",art:"journal",screen:"journal",badge:"CONNECTION JOURNAL · INCLUDED FREE",dark:true),
 Panel(name:"04-room-for-everyone",title:"Your people.\nYour little world.",subtitle:"Keep birthdays, notes and gift ideas together.",art:"rhythm",screen:"people",badge:"UNLIMITED PEOPLE · INCLUDED FREE",dark:false),
 Panel(name:"05-gifts-that-mean-something",title:"Gifts with\nmeaning.",subtitle:"Save ideas all year. Remember what you gave.",art:"gestures",screen:"gifts",badge:"GIFT IDEAS & HISTORY · INCLUDED FREE",dark:false),
 Panel(name:"06-time-to-show-up",title:"A little nudge.\nA lot of meaning.",subtitle:"Birthday reminders before the day arrives.",art:"rhythm",screen:"settings",badge:"LOCAL BIRTHDAY REMINDERS · INCLUDED FREE",dark:true),
 Panel(name:"07-see-whats-ahead",title:"Good things\non the horizon.",subtitle:"See the birthdays ahead. Make room for joy.",art:"picnic",screen:"calendar",badge:"YOUR BIRTHDAY CALENDAR",dark:false),
 Panel(name:"08-start-with-someone",title:"Start with someone\nyou love.",subtitle:"Add a birthday. Imagine a thoughtful gesture.",art:"gestures",screen:"add",badge:"NO DEVELOPER ACCOUNT NEEDED",dark:false),
 Panel(name:"09-private-by-design",title:"Your memories.\nYour own space.",subtitle:"Personal notes and plans stay on your iPhone.",art:"journal",screen:"privacy",badge:"NO ADS · NO DEVELOPER ANALYTICS",dark:true),
 Panel(name:"10-more-intention-with-pro",title:"More intention.\nAll year long.",subtitle:"Personal checklists and a rhythm for catching up.",art:"rhythm",screen:"plan",badge:"OPTIONAL PRO SUBSCRIPTION",dark:false)
]
func text(_ value: String, x: CGFloat, top: CGFloat, width: CGFloat, size: CGFloat, color: NSColor, serif: Bool = false, tracking: CGFloat = 0) {
 let font = serif ? (NSFont(name:"Georgia-Bold",size:size) ?? .boldSystemFont(ofSize:size)) : NSFont.systemFont(ofSize:size,weight:.medium)
 let style = NSMutableParagraphStyle(); style.lineSpacing = serif ? 8 : 5
 (value as NSString).draw(in:NSRect(x:x,y:2868-top-420,width:width,height:420),withAttributes:[.font:font,.foregroundColor:color,.paragraphStyle:style,.kern:tracking])
}
func image(_ path: String, in rect: NSRect, radius: CGFloat = 0) {
 guard let img = NSImage(contentsOfFile:path) else { fatalError("Missing image: \(path)") }
 NSGraphicsContext.saveGraphicsState()
 if radius > 0 { NSBezierPath(roundedRect:rect,xRadius:radius,yRadius:radius).addClip() }
 img.draw(in:rect,from:.zero,operation:.sourceOver,fraction:1)
 NSGraphicsContext.restoreGraphicsState()
}
func phone(screen: String, rect: NSRect) {
 let outer = rect.insetBy(dx:-14,dy:-14)
 NSGraphicsContext.saveGraphicsState()
 let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.20); shadow.shadowBlurRadius=40; shadow.shadowOffset=NSSize(width:12,height:-24); shadow.set()
 NSColor(srgbRed:0.08,green:0.12,blue:0.10,alpha:1).setFill(); NSBezierPath(roundedRect:outer,xRadius:65,yRadius:65).fill()
 NSGraphicsContext.restoreGraphicsState()
 image(root.appendingPathComponent("Release-2.0/Screenshots/\(screen).png").path,in:rect,radius:52)
 NSColor.black.setFill(); NSBezierPath(roundedRect:NSRect(x:rect.midX-64,y:rect.maxY-34,width:128,height:22),xRadius:12,yRadius:12).fill()
}
func render(_ p: Panel, width: Int, height: Int, directory: String) throws {
 let context = CGContext(data:nil,width:width,height:height,bitsPerComponent:8,bytesPerRow:width*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.noneSkipLast.rawValue)!
 NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current=NSGraphicsContext(cgContext:context,flipped:false)
 let transform = NSAffineTransform(); transform.scaleX(by:CGFloat(width)/1320,yBy:CGFloat(height)/2868); transform.concat()
 (p.dark ? ink : paper).setFill(); NSBezierPath(rect:NSRect(x:0,y:0,width:1320,height:2868)).fill()
 let primary = p.dark ? paper : ink
 text("NEXT BIRTHDAY",x:90,top:105,width:1120,size:27,color:primary,tracking:6)
 text(p.title,x:86,top:220,width:1160,size:p.name.hasPrefix("05") ? 100 : 110,color:primary,serif:true)
 text(p.subtitle,x:90,top:535,width:1130,size:37,color:primary.withAlphaComponent(0.78))
 // Artwork anchors the story; the actual app remains the largest functional element.
 let index = panels.firstIndex { $0.name == p.name }!
 if index % 3 == 0 {
  image(root.appendingPathComponent("BrandArtwork/\(p.art).png").path,in:NSRect(x:70,y:870,width:1180,height:1180),radius:32)
  phone(screen:p.screen,rect:NSRect(x:100,y:255,width:620,height:1347))
 } else if index % 3 == 1 {
  image(root.appendingPathComponent("BrandArtwork/\(p.art).png").path,in:NSRect(x:490,y:1040,width:830,height:830),radius:32)
  phone(screen:p.screen,rect:NSRect(x:120,y:255,width:780,height:1695))
 } else {
  image(root.appendingPathComponent("BrandArtwork/\(p.art).png").path,in:NSRect(x:100,y:965,width:1120,height:1120),radius:32)
  phone(screen:p.screen,rect:NSRect(x:560,y:255,width:620,height:1347))
 }
 // Small editorial side note; generous margins keep the design legible at thumbnail size.
 if index % 3 == 2 {
  text("LITTLE\nMOMENTS.\nBIG\nFEELINGS.",x:110,top:2110,width:400,size:35,color:primary,tracking:3)
 } else {
  text(p.dark ? "TIME\nWELL\nSHARED." : "SMALL\nTHINGS\nMATTER.",x:965,top:2240,width:280,size:30,color:primary,tracking:3)
 }
 primary.withAlphaComponent(0.25).setFill(); NSBezierPath(rect:NSRect(x:90,y:155,width:1140,height:2)).fill()
 text(p.badge,x:90,top:2770,width:1150,size:23,color:primary,tracking:2)
 NSGraphicsContext.restoreGraphicsState()
 try FileManager.default.createDirectory(at:root.appendingPathComponent(directory),withIntermediateDirectories:true)
 let destination = CGImageDestinationCreateWithURL(root.appendingPathComponent("\(directory)/\(p.name).png") as CFURL,"public.png" as CFString,1,nil)!
 CGImageDestinationAddImage(destination,context.makeImage()!,nil)
 precondition(CGImageDestinationFinalize(destination))
}
for p in panels {
 try render(p,width:1320,height:2868,directory:"AppStoreScreenshots")
 try render(p,width:1242,height:2688,directory:"AppStoreScreenshots-1242x2688")
}
let overview=CGContext(data:nil,width:1650,height:1434,bitsPerComponent:8,bytesPerRow:1650*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.noneSkipLast.rawValue)!
NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current=NSGraphicsContext(cgContext:overview,flipped:false)
paper.setFill(); NSBezierPath(rect:NSRect(x:0,y:0,width:1650,height:1434)).fill()
for (i,p) in panels.enumerated() { image(root.appendingPathComponent("AppStoreScreenshots/\(p.name).png").path,in:NSRect(x:(i%5)*330,y:(1-i/5)*717,width:330,height:717)) }
NSGraphicsContext.restoreGraphicsState()
let overviewDestination=CGImageDestinationCreateWithURL(root.appendingPathComponent("Release-2.0/campaign-overview.png") as CFURL,"public.png" as CFString,1,nil)!
CGImageDestinationAddImage(overviewDestination,overview.makeImage()!,nil)
precondition(CGImageDestinationFinalize(overviewDestination))
print("Rendered 10 designed store panels at both supported sizes and a campaign overview.")
