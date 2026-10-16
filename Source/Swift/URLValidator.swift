import Foundation

enum URLValidator {
    static func isValid(_ string: String) -> Bool {
        guard let url = URL(string: string) else { return false }
        return HostsDownloader.isAllowedURL(url)
    }
}
