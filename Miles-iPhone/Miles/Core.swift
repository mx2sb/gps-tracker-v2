import Foundation

struct GPSPoint: Codable {
    var lat: Double
    var lon: Double
    var time: String
    var accuracy: Double
    var speed: Double?
    var altitude: Double?
    var segment: Int
}

struct Trip: Codable, Identifiable {
    var id = UUID().uuidString.lowercased()
    var owner_id: String
    var sport: String
    var started_at: String
    var ended_at: String?
    var state = "paused"
    var segment = 0
    var points: [GPSPoint] = []
    var next_offset = 0
    var synced = false

    mutating func append(_ point: GPSPoint) -> Bool {
        guard state == "recording", ended_at == nil,
              points.count < 200_000,
              point.lat.isFinite, point.lon.isFinite,
              (-90...90).contains(point.lat), (-180...180).contains(point.lon),
              point.accuracy.isFinite, point.accuracy >= 0,
              let stamp = Clock.date(point.time), let start = Clock.date(started_at), stamp >= start
        else { return false }
        if let last = points.last, let previous = Clock.date(last.time), stamp <= previous { return false }
        points.append(point)
        return true
    }

    mutating func pause() { if ended_at == nil { state = "paused"; segment += 1 } }
    mutating func resume() { if ended_at == nil { segment += 1; state = "recording" } }
    mutating func finish(at date: Date) throws {
        guard ended_at == nil else { throw TrialError.message("Este recorrido ya está finalizado.") }
        pause()
        let last = points.last.flatMap { Clock.date($0.time) } ?? date
        ended_at = Clock.string(max(date, last)); state = "finished"
        // Empty attempts remain on disk, but are never uploaded as activities.
        if points.isEmpty { synced = true }
    }
    func upload() throws -> Data {
        guard let end = ended_at else { throw TrialError.message("Recorrido sin finalizar.") }
        return try JSONEncoder().encode(Upload(id: id, sport: sport, started_at: started_at, ended_at: end, points: points))
    }
    private struct Upload: Encodable {
        let id: String; let sport: String; let started_at: String; let ended_at: String; let points: [GPSPoint]
    }
}

enum Clock {
    static func string(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
    static func date(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string)
    }
}
enum TrialError: LocalizedError {
    case message(String)
    var errorDescription: String? { switch self { case .message(let message): return message } }
}

struct TripStore {
    let directory: URL
    func save(_ trip: Trip) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent(trip.id + ".json")
        #if os(iOS)
        try JSONEncoder().encode(trip).write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: file.path)
        #else
        try JSONEncoder().encode(trip).write(to: file, options: .atomic)
        #endif
    }
    func all() throws -> [Trip] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .map { try JSONDecoder().decode(Trip.self, from: Data(contentsOf: $0)) }
            .sorted { $0.started_at > $1.started_at }
    }
}
