import XCTest
@testable import MilesCore

final class CoreTests: XCTestCase {
    let start = Date(timeIntervalSince1970: 1_790_000_000)
    func point(_ seconds: Double, segment: Int = 1, accuracy: Double = 4) -> GPSPoint {
        GPSPoint(lat: 40, lon: -73 + seconds / 100_000, time: Clock.string(start.addingTimeInterval(seconds)), accuracy: accuracy, speed: nil, altitude: nil, segment: segment)
    }
    func testPauseAndResumeNeverJoinSegments() throws {
        var trip = Trip(owner_id: "owner", sport: "walk", started_at: Clock.string(start))
        trip.resume(); XCTAssertTrue(trip.append(point(1, segment: trip.segment)))
        trip.pause(); XCTAssertFalse(trip.append(point(5)))
        trip.resume(); XCTAssertTrue(trip.append(point(20, segment: trip.segment)))
        XCTAssertNotEqual(trip.points[0].segment, trip.points[1].segment)
    }
    func testInvalidOrRepeatedSamplesDoNotEnterStore() {
        var trip = Trip(owner_id: "owner", sport: "walk", started_at: Clock.string(start))
        trip.resume(); XCTAssertFalse(trip.append(point(-1)))
        XCTAssertFalse(trip.append(point(1, accuracy: -1)))
        XCTAssertTrue(trip.append(point(2))); XCTAssertFalse(trip.append(point(2)))
        XCTAssertFalse(trip.append(point(1))); XCTAssertEqual(trip.points.count, 1)
    }
    func testDiskRecoveryRetainsOwnerRawAccuracyAndUploadIdentity() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = TripStore(directory: dir)
        var trip = Trip(owner_id: "private-owner", sport: "bike", started_at: Clock.string(start))
        trip.resume(); XCTAssertTrue(trip.append(point(1, accuracy: 100)))
        XCTAssertTrue(trip.append(point(3)))
        try store.save(trip)
        var restored = try XCTUnwrap(store.all().first)
        restored.pause(); try store.save(restored)
        XCTAssertEqual(restored.points.count, 2); XCTAssertEqual(restored.points[0].accuracy, 100)
        try restored.finish(at: start.addingTimeInterval(4)); try store.save(restored)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: restored.upload()) as? [String: Any])
        XCTAssertEqual(payload["id"] as? String, trip.id)
        XCTAssertNil(payload["owner_id"]); XCTAssertNil(payload["synced"])
        XCTAssertEqual(try store.all().first?.owner_id, "private-owner")
        XCTAssertFalse(restored.append(point(5)))
    }
    func testSinglePointCanFinishWithoutLosingItsSample() throws {
        var trip = Trip(owner_id: "owner", sport: "walk", started_at: Clock.string(start))
        trip.resume(); XCTAssertTrue(trip.append(point(1)))
        try trip.finish(at: start.addingTimeInterval(2))
        XCTAssertNotNil(trip.ended_at); XCTAssertEqual(trip.points.count, 1)
        XCTAssertFalse(trip.synced)
        XCTAssertThrowsError(try trip.finish(at: start.addingTimeInterval(3)))
    }
    func testEmptyAttemptClosesLocally() throws {
        var trip = Trip(owner_id: "owner", sport: "walk", started_at: Clock.string(start))
        trip.resume(); try trip.finish(at: start.addingTimeInterval(2))
        XCTAssertNotNil(trip.ended_at); XCTAssertTrue(trip.synced)
        XCTAssertTrue(trip.points.isEmpty)
    }
}
