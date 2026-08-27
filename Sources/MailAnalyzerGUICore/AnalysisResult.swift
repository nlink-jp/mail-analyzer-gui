import Foundation

// The mail-analyzer JSON output schema. Mirrors the Go analyzer's output as
// accepted by the legacy Rust types (legacy/src-tauri/src/types.rs): fields
// the analyzer may omit decode to defaults, and the six array fields the Go
// backend emits as `null` for empty slices decode to []. Fields that were
// required in the legacy decoder stay required here, so garbage JSON is
// reported as a parse error instead of rendering as an empty "safe" result.

public struct AnalysisResult: Codable, Equatable {
    public var sourceFile: String
    public var hash: String
    public var messageID: String
    public var subject: String
    public var from: String
    public var to: [String]
    public var date: String
    public var indicators: Indicators
    public var judgment: Judgment

    enum CodingKeys: String, CodingKey {
        case sourceFile = "source_file"
        case hash
        case messageID = "message_id"
        case subject
        case from
        case to
        case date
        case indicators
        case judgment
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sourceFile = try c.decode(String.self, forKey: .sourceFile)
        hash = try c.decode(String.self, forKey: .hash)
        messageID = try c.decodeIfPresent(String.self, forKey: .messageID) ?? ""
        subject = try c.decodeIfPresent(String.self, forKey: .subject) ?? ""
        from = try c.decodeIfPresent(String.self, forKey: .from) ?? ""
        to = try c.decodeIfPresent([String].self, forKey: .to) ?? []
        date = try c.decodeIfPresent(String.self, forKey: .date) ?? ""
        indicators = try c.decode(Indicators.self, forKey: .indicators)
        judgment = try c.decode(Judgment.self, forKey: .judgment)
    }

    public init(
        sourceFile: String = "", hash: String = "", messageID: String = "",
        subject: String = "", from: String = "", to: [String] = [],
        date: String = "", indicators: Indicators = Indicators(),
        judgment: Judgment = Judgment()
    ) {
        self.sourceFile = sourceFile
        self.hash = hash
        self.messageID = messageID
        self.subject = subject
        self.from = from
        self.to = to
        self.date = date
        self.indicators = indicators
        self.judgment = judgment
    }
}

public struct Indicators: Codable, Equatable {
    public var authentication: AuthResult
    public var sender: SenderResult
    public var urls: [UrlResult]
    public var attachments: [AttachResult]
    public var routing: RoutingResult

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        authentication = try c.decode(AuthResult.self, forKey: .authentication)
        sender = try c.decode(SenderResult.self, forKey: .sender)
        urls = try c.decodeIfPresent([UrlResult].self, forKey: .urls) ?? []
        attachments = try c.decodeIfPresent([AttachResult].self, forKey: .attachments) ?? []
        routing = try c.decode(RoutingResult.self, forKey: .routing)
    }

    public init(
        authentication: AuthResult = AuthResult(), sender: SenderResult = SenderResult(),
        urls: [UrlResult] = [], attachments: [AttachResult] = [],
        routing: RoutingResult = RoutingResult()
    ) {
        self.authentication = authentication
        self.sender = sender
        self.urls = urls
        self.attachments = attachments
        self.routing = routing
    }
}

public struct AuthResult: Codable, Equatable {
    public var spf: String
    public var dkim: String
    public var dmarc: String

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        spf = try c.decodeIfPresent(String.self, forKey: .spf) ?? ""
        dkim = try c.decodeIfPresent(String.self, forKey: .dkim) ?? ""
        dmarc = try c.decodeIfPresent(String.self, forKey: .dmarc) ?? ""
    }

    public init(spf: String = "", dkim: String = "", dmarc: String = "") {
        self.spf = spf
        self.dkim = dkim
        self.dmarc = dmarc
    }
}

public struct SenderResult: Codable, Equatable {
    public var fromReturnPathMismatch: Bool
    public var displayNameSpoofing: Bool
    public var replyToDivergence: Bool
    public var details: String

    enum CodingKeys: String, CodingKey {
        case fromReturnPathMismatch = "from_return_path_mismatch"
        case displayNameSpoofing = "display_name_spoofing"
        case replyToDivergence = "reply_to_divergence"
        case details
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        fromReturnPathMismatch = try c.decodeIfPresent(Bool.self, forKey: .fromReturnPathMismatch) ?? false
        displayNameSpoofing = try c.decodeIfPresent(Bool.self, forKey: .displayNameSpoofing) ?? false
        replyToDivergence = try c.decodeIfPresent(Bool.self, forKey: .replyToDivergence) ?? false
        details = try c.decodeIfPresent(String.self, forKey: .details) ?? ""
    }

    public init(
        fromReturnPathMismatch: Bool = false, displayNameSpoofing: Bool = false,
        replyToDivergence: Bool = false, details: String = ""
    ) {
        self.fromReturnPathMismatch = fromReturnPathMismatch
        self.displayNameSpoofing = displayNameSpoofing
        self.replyToDivergence = replyToDivergence
        self.details = details
    }
}

public struct UrlResult: Codable, Equatable {
    public var url: String
    public var suspicious: Bool
    public var reason: String

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        url = try c.decodeIfPresent(String.self, forKey: .url) ?? ""
        suspicious = try c.decodeIfPresent(Bool.self, forKey: .suspicious) ?? false
        reason = try c.decodeIfPresent(String.self, forKey: .reason) ?? ""
    }

    public init(url: String = "", suspicious: Bool = false, reason: String = "") {
        self.url = url
        self.suspicious = suspicious
        self.reason = reason
    }
}

public struct AttachResult: Codable, Equatable {
    public var filename: String
    public var mimeType: String
    public var size: UInt64
    public var hash: String
    public var suspicious: Bool
    public var reason: String

    enum CodingKeys: String, CodingKey {
        case filename
        case mimeType = "mime_type"
        case size
        case hash
        case suspicious
        case reason
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        filename = try c.decodeIfPresent(String.self, forKey: .filename) ?? ""
        mimeType = try c.decodeIfPresent(String.self, forKey: .mimeType) ?? ""
        size = try c.decodeIfPresent(UInt64.self, forKey: .size) ?? 0
        hash = try c.decodeIfPresent(String.self, forKey: .hash) ?? ""
        suspicious = try c.decodeIfPresent(Bool.self, forKey: .suspicious) ?? false
        reason = try c.decodeIfPresent(String.self, forKey: .reason) ?? ""
    }

    public init(
        filename: String = "", mimeType: String = "", size: UInt64 = 0,
        hash: String = "", suspicious: Bool = false, reason: String = ""
    ) {
        self.filename = filename
        self.mimeType = mimeType
        self.size = size
        self.hash = hash
        self.suspicious = suspicious
        self.reason = reason
    }
}

public struct RoutingResult: Codable, Equatable {
    public var hopCount: UInt32
    public var xMailer: String
    public var xMailerSuspicious: Bool
    public var suspiciousHops: [String]

    enum CodingKeys: String, CodingKey {
        case hopCount = "hop_count"
        case xMailer = "x_mailer"
        case xMailerSuspicious = "x_mailer_suspicious"
        case suspiciousHops = "suspicious_hops"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hopCount = try c.decodeIfPresent(UInt32.self, forKey: .hopCount) ?? 0
        xMailer = try c.decodeIfPresent(String.self, forKey: .xMailer) ?? ""
        xMailerSuspicious = try c.decodeIfPresent(Bool.self, forKey: .xMailerSuspicious) ?? false
        suspiciousHops = try c.decodeIfPresent([String].self, forKey: .suspiciousHops) ?? []
    }

    public init(
        hopCount: UInt32 = 0, xMailer: String = "", xMailerSuspicious: Bool = false,
        suspiciousHops: [String] = []
    ) {
        self.hopCount = hopCount
        self.xMailer = xMailer
        self.xMailerSuspicious = xMailerSuspicious
        self.suspiciousHops = suspiciousHops
    }
}

public struct Judgment: Codable, Equatable {
    public var isSuspicious: Bool
    public var category: String
    public var confidence: Double
    public var summary: String
    public var reasons: [String]
    public var tags: [String]

    enum CodingKeys: String, CodingKey {
        case isSuspicious = "is_suspicious"
        case category
        case confidence
        case summary
        case reasons
        case tags
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        isSuspicious = try c.decode(Bool.self, forKey: .isSuspicious)
        category = try c.decodeIfPresent(String.self, forKey: .category) ?? ""
        confidence = try c.decodeIfPresent(Double.self, forKey: .confidence) ?? 0.0
        summary = try c.decodeIfPresent(String.self, forKey: .summary) ?? ""
        reasons = try c.decodeIfPresent([String].self, forKey: .reasons) ?? []
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
    }

    public init(
        isSuspicious: Bool = false, category: String = "", confidence: Double = 0.0,
        summary: String = "", reasons: [String] = [], tags: [String] = []
    ) {
        self.isSuspicious = isSuspicious
        self.category = category
        self.confidence = confidence
        self.summary = summary
        self.reasons = reasons
        self.tags = tags
    }
}

public enum AnalysisResultDecoding {
    /// Decode one analyzer result from raw stdout bytes.
    public static func decode(_ data: Data) throws -> AnalysisResult {
        try JSONDecoder().decode(AnalysisResult.self, from: data)
    }
}

public enum ExportJSON {
    /// Pretty-printed export of results in list order, matching the legacy
    /// "Export JSON" clipboard payload. Key order is alphabetical (stable),
    /// where serde used struct order — semantically identical.
    public static func encode(_ results: [AnalysisResult]) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(results)
        return String(decoding: data, as: UTF8.self)
    }
}
