import Foundation
import Security

struct UsageData {
    struct Window {
        let utilization: Double  // 0-100
        let resetsAt: Date?
        let windowSeconds: Int

        var timeElapsedPercent: Double {
            guard let resetsAt else { return 0 }
            let remaining = resetsAt.timeIntervalSinceNow
            if remaining < 0 { return 100 }
            let elapsed = Double(windowSeconds) - remaining
            let clamped = min(max(elapsed, 0), Double(windowSeconds))
            return clamped / Double(windowSeconds) * 100
        }

        var timeRemainingFormatted: String {
            guard let resetsAt else { return "—" }
            let diff = Int(resetsAt.timeIntervalSinceNow)
            if diff <= 0 { return "now" }
            if diff < 3600 { return "\(diff / 60)m" }
            if diff < 86400 { return "\(diff / 3600)h\(diff % 3600 / 60)m" }
            return "\(diff / 86400)d \(diff % 86400 / 3600)h"
        }
    }

    let fiveHour: Window
    let sevenDay: Window
}

enum UsageAPIError: Error {
    case noCredentials
    case tokenExpired
    case refreshFailed(String)
    case fetchFailed(String)
}

final class UsageAPI {
    private static let keychainService = "Claude Code-credentials"
    private static let tokenURL = "https://api.anthropic.com/api/oauth/token"
    private static let usageURL = "https://api.anthropic.com/api/oauth/usage"
    private static let betaHeader = "oauth-2025-04-20"

    func fetchUsage() async throws -> UsageData {
        let token = try await getValidToken()
        return try await fetchUsageData(token: token)
    }

    // MARK: - Keychain

    private struct OAuthCredentials {
        let accessToken: String
        let refreshToken: String
        let expiresAt: Int64
    }

    private func readKeychainRaw() throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data,
              let str = String(data: data, encoding: .utf8) else {
            throw UsageAPIError.noCredentials
        }
        return str
    }

    /// Extract OAuth fields using regex, matching the bash script's fallback
    /// approach. The keychain JSON is often truncated/malformed so full JSON
    /// parsing is unreliable.
    private func readCredentials() throws -> OAuthCredentials {
        let raw = try readKeychainRaw()

        guard let accessToken = extractString(named: "accessToken", from: raw),
              let refreshToken = extractString(named: "refreshToken", from: raw),
              let expiresAt = extractInt(named: "expiresAt", from: raw) else {
            throw UsageAPIError.noCredentials
        }

        return OAuthCredentials(accessToken: accessToken, refreshToken: refreshToken, expiresAt: expiresAt)
    }

    private func extractString(named field: String, from raw: String) -> String? {
        // Match "fieldName":"value"
        guard let range = raw.range(of: #""\#(field)":"([^"]*)""#, options: .regularExpression) else {
            return nil
        }
        let match = raw[range]
        // Strip "fieldName":" prefix and trailing "
        let prefixLen = field.count + 4 // "field":"
        let start = match.index(match.startIndex, offsetBy: prefixLen)
        let end = match.index(before: match.endIndex)
        return String(match[start..<end])
    }

    private func extractInt(named field: String, from raw: String) -> Int64? {
        // Match "fieldName":12345
        guard let range = raw.range(of: #""\#(field)":(\d+)"#, options: .regularExpression) else {
            return nil
        }
        let match = raw[range]
        let prefixLen = field.count + 3 // "field":
        let start = match.index(match.startIndex, offsetBy: prefixLen)
        return Int64(match[start...])
    }

    // MARK: - Token Management

    private func isTokenExpired(expiresAt: Int64) -> Bool {
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let bufferMs: Int64 = 60_000
        return expiresAt - bufferMs < nowMs
    }

    private func getValidToken() async throws -> String {
        let credentials = try readCredentials()

        if !isTokenExpired(expiresAt: credentials.expiresAt) {
            return credentials.accessToken
        }

        // Token expired, refresh it (don't update keychain — Claude Code manages it)
        let refreshResponse = try await refreshToken(credentials.refreshToken)
        return refreshResponse.accessToken
    }

    private struct RefreshResponse {
        let accessToken: String
        let refreshToken: String?
        let expiresAt: Int64?
    }

    private func refreshToken(_ token: String) async throws -> RefreshResponse {
        var request = URLRequest(url: URL(string: Self.tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Self.betaHeader, forHTTPHeaderField: "anthropic-beta")

        let body: [String: String] = [
            "grant_type": "refresh_token",
            "refresh_token": token,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw UsageAPIError.refreshFailed("Invalid response")
        }

        if let error = json["error"] as? String {
            throw UsageAPIError.refreshFailed(error)
        }

        guard let accessToken = json["access_token"] as? String else {
            throw UsageAPIError.refreshFailed("No access_token in response")
        }

        return RefreshResponse(
            accessToken: accessToken,
            refreshToken: json["refresh_token"] as? String,
            expiresAt: json["expires_at"] as? Int64
        )
    }

    // MARK: - Usage Fetch

    private func fetchUsageData(token: String) async throws -> UsageData {
        var request = URLRequest(url: URL(string: Self.usageURL)!)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(Self.betaHeader, forHTTPHeaderField: "anthropic-beta")
        request.setValue("ClaudeUsageBar/1.0", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.data(for: request)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw UsageAPIError.fetchFailed("Invalid JSON")
        }

        if let error = json["error"] as? String {
            throw UsageAPIError.fetchFailed(error)
        }

        return UsageData(
            fiveHour: parseWindow(json["five_hour"] as? [String: Any], windowSeconds: 18_000),
            sevenDay: parseWindow(json["seven_day"] as? [String: Any], windowSeconds: 604_800)
        )
    }

    private func parseWindow(_ json: [String: Any]?, windowSeconds: Int) -> UsageData.Window {
        guard let json else {
            return UsageData.Window(utilization: 0, resetsAt: nil, windowSeconds: windowSeconds)
        }

        let utilization = (json["utilization"] as? Double) ?? 0

        var resetsAt: Date?
        if let resetStr = json["resets_at"] as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            resetsAt = formatter.date(from: resetStr)
            if resetsAt == nil {
                formatter.formatOptions = [.withInternetDateTime]
                resetsAt = formatter.date(from: resetStr)
            }
        }

        return UsageData.Window(
            utilization: utilization,
            resetsAt: resetsAt,
            windowSeconds: windowSeconds
        )
    }
}
