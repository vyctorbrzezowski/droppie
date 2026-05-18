import Foundation

public enum DroppedFileURLDecoder {
  public static func fileURL(from item: NSSecureCoding?) -> URL? {
    if let url = item as? NSURL, (url as URL).isFileURL {
      return url as URL
    }

    if let data = item as? Data,
       let url = URL(dataRepresentation: data, relativeTo: nil),
       url.isFileURL {
      return url
    }

    if let value = item as? String,
       let url = URL(string: value),
       url.isFileURL {
      return url
    }

    return nil
  }
}
