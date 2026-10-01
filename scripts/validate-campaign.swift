import Foundation
import ImageIO
func validate(_ directory: String, width: Int, height: Int) throws {
 let files=try FileManager.default.contentsOfDirectory(atPath:directory).filter { $0.hasSuffix(".png") }
 precondition(files.count == 10,"Expected ten campaign panels")
 for file in files {
  let data=try Data(contentsOf:URL(fileURLWithPath:directory+"/"+file))
  guard let source=CGImageSourceCreateWithData(data as CFData,nil), let image=CGImageSourceCreateImageAtIndex(source,0,nil) else { fatalError("Invalid image") }
  precondition(image.width == width && image.height == height,"Wrong dimensions: \(file)")
  precondition(data[25] == 2,"PNG must be RGB without alpha: \(file)")
  precondition(data.count > 50000,"Unexpectedly blank image: \(file)")
 }
}
try validate("AppStoreScreenshots",width:1320,height:2868)
try validate("AppStoreScreenshots-1242x2688",width:1242,height:2688)
print("PASS: twenty PNGs, correct App Store dimensions, RGB without alpha, nonempty content")
