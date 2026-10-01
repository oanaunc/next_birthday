import AppKit
import ImageIO
let size = 1024
let context=CGContext(data:nil,width:size,height:size,bitsPerComponent:8,bytesPerRow:size*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.noneSkipLast.rawValue)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current=NSGraphicsContext(cgContext:context,flipped:false)
NSColor(srgbRed: 0.14, green: 0.36, blue: 0.29, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: size, height: size)).fill()
NSColor(srgbRed: 0.965, green: 0.953, blue: 0.922, alpha: 1).setStroke()
let circle = NSBezierPath(ovalIn: NSRect(x: 175, y: 175, width: 674, height: 674)); circle.lineWidth = 18; circle.stroke()
let stem = NSBezierPath(); stem.move(to: NSPoint(x: 512, y: 305)); stem.curve(to: NSPoint(x: 532, y: 650), controlPoint1: NSPoint(x: 480, y: 450), controlPoint2: NSPoint(x: 520, y: 570)); stem.lineWidth = 24; stem.lineCapStyle = .round; stem.stroke()
NSColor(srgbRed: 0.82, green: 0.88, blue: 0.73, alpha: 1).setFill()
let left = NSBezierPath(); left.move(to: NSPoint(x: 508, y: 464)); left.curve(to: NSPoint(x: 330, y: 635), controlPoint1: NSPoint(x: 330, y: 453), controlPoint2: NSPoint(x: 340, y: 555)); left.curve(to: NSPoint(x: 508, y: 464), controlPoint1: NSPoint(x: 470, y: 630), controlPoint2: NSPoint(x: 495, y: 568)); left.fill()
let right = NSBezierPath(); right.move(to: NSPoint(x: 521, y: 557)); right.curve(to: NSPoint(x: 705, y: 720), controlPoint1: NSPoint(x: 550, y: 700), controlPoint2: NSPoint(x: 640, y: 707)); right.curve(to: NSPoint(x: 521, y: 557), controlPoint1: NSPoint(x: 716, y: 574), controlPoint2: NSPoint(x: 623, y: 540)); right.fill()
NSColor(srgbRed: 0.92, green: 0.73, blue: 0.54, alpha: 1).setFill()
NSBezierPath(ovalIn: NSRect(x: 625, y: 332, width: 60, height: 60)).fill()
NSGraphicsContext.restoreGraphicsState()
let destination=CGImageDestinationCreateWithURL(URL(fileURLWithPath:CommandLine.arguments[1]) as CFURL,"public.png" as CFString,1,nil)!
CGImageDestinationAddImage(destination,context.makeImage()!,nil)
precondition(CGImageDestinationFinalize(destination))
