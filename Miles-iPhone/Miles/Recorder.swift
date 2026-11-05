import Foundation
import CoreLocation
import WebKit
import Combine

@MainActor final class Recorder: NSObject, ObservableObject, CLLocationManagerDelegate {
    nonisolated static let origin = URL(string: "https://gps-tracker.tailc37b71.ts.net")!
    @Published var trips: [Trip] = []
    @Published var current: Trip?
    @Published var account = "Inicia sesión en la pestaña Web y verifica tu cuenta aquí."
    @Published var message = "GPS detenido."
    @Published var syncing = false
    @Published var storageFailed = false
    @Published var owner: String?
    @Published var preparing = false
    @Published var locationNeedsSettings = false
    private var pendingSport: String?
    let web = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
    private let location = CLLocationManager()
    private let store = TripStore(directory: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("NativeTrips"))
    private var timer: Timer?

    override init() {
        super.init()
        location.delegate = self
        location.desiredAccuracy = kCLLocationAccuracyBest
        location.distanceFilter = kCLDistanceFilterNone
        location.activityType = .fitness
        location.pausesLocationUpdatesAutomatically = false
        location.allowsBackgroundLocationUpdates = true
        location.showsBackgroundLocationIndicator = true
        do {
            trips = try store.all()
            // Termination creates an explicit interruption, never silently joined.
            for var trip in trips where trip.ended_at == nil { trip.pause(); try store.save(trip) }
            trips = try store.all()
            current = trips.first(where: { $0.ended_at == nil })
            if current != nil { message = "Recorrido recuperado en pausa. Verifica tu cuenta y pulsa Reanudar." }
        } catch { storageFailed = true; message = "No se pudo recuperar el archivo local: \(error.localizedDescription). No inicies otra grabación." }
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.sync() }
        }
    }

    func request(_ path: String, method: String = "GET", body: Data? = nil) async throws -> Data {
        let cookies = await web.configuration.websiteDataStore.httpCookieStore.allCookies()
        let valid = cookies.filter { $0.domain.trimmingCharacters(in: CharacterSet(charactersIn: ".")) == Self.origin.host! && ($0.expiresDate == nil || $0.expiresDate! > Date()) }
        var request = URLRequest(url: Self.origin.appendingPathComponent("api/" + path))
        request.httpMethod = method; request.httpBody = body; request.timeoutInterval = 20
        request.httpShouldHandleCookies = false
        request.allHTTPHeaderFields = HTTPCookie.requestHeaderFields(with: valid)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let config = URLSessionConfiguration.ephemeral
        config.httpShouldSetCookies = false
        let session = URLSession(configuration: config, delegate: SameOriginRedirects(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw TrialError.message("Respuesta no válida.") }
        guard (200..<300).contains(response.statusCode) else {
            throw TrialError.message(response.statusCode == 401 ? "Inicia sesión otra vez en Web. Tus puntos siguen guardados." : "Servidor HTTP \(response.statusCode). Datos conservados para reintentar.")
        }
        return data
    }

    func verify() async {
        do { let user = try await identity(); owner = user.id; account = user.email }
        catch { owner = nil; account = error.localizedDescription }
    }
    struct Identity: Decodable { let id: String; let email: String }
    private func identity() async throws -> Identity { try JSONDecoder().decode(Identity.self, from: await request("auth/me")) }

    private func persist(_ trip: Trip) throws {
        try store.save(trip)
        current = trip
        trips = try store.all()
    }
    private func writable() -> Bool {
        guard !storageFailed else { message = "Reabre la app para revisar el almacenamiento antes de grabar."; return false }
        return true
    }
    func start(sport: String) {
        guard writable() else { return }
        guard let owner else { message = "Verifica tu cuenta antes de iniciar."; return }
        guard current?.ended_at != nil || current == nil else { message = "Finaliza el recorrido pendiente antes de iniciar otro."; return }
        if location.authorizationStatus == .notDetermined { pendingSport = sport }
        guard permitted() else { return }
        do {
            var trip = Trip(owner_id: owner, sport: sport, started_at: Clock.string(Date()))
            trip.resume(); try persist(trip); location.startUpdatingLocation()
            message = "GPS iniciado. Esperando la primera posición; sal al aire libre. Los puntos aparecerán aquí."
        } catch { failStorage(error) }
    }
    func prepareStart(sport: String) async {
        guard !preparing else { return }
        preparing = true; defer { preparing = false }
        message = "Verificando tu sesión…"
        await verify()
        guard owner != nil else { message = account; return }
        start(sport: sport)
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard let sport = pendingSport, manager.authorizationStatus != .notDetermined else { return }
        pendingSport = nil
        start(sport: sport)
    }
    private func permitted() -> Bool {
        locationNeedsSettings = false
        switch location.authorizationStatus {
        case .notDetermined: location.requestWhenInUseAuthorization(); message = "Autoriza ubicación precisa para iniciar la grabación."; return false
        case .authorizedAlways, .authorizedWhenInUse:
            guard location.accuracyAuthorization == .fullAccuracy else { locationNeedsSettings = true; message = "Activa Ubicación precisa en Ajustes → Miles GPS y vuelve a pulsar Iniciar."; return false }
            return true
        default: locationNeedsSettings = true; message = "Autoriza ubicación al usar la app y Ubicación precisa en Ajustes → Miles GPS. Después vuelve a pulsar Iniciar o Reanudar."; return false
        }
    }
    func pause() {
        location.stopUpdatingLocation()
        guard var trip = current, trip.ended_at == nil else { return }
        trip.pause()
        do { try persist(trip); message = "En pausa. El desplazamiento de esta pausa no se suma." } catch { failStorage(error) }
    }
    func resume() {
        guard writable(), permitted(), var trip = current, trip.ended_at == nil else { return }
        guard owner == trip.owner_id else { message = "Verifica la misma cuenta que inició este recorrido."; return }
        do { trip.resume(); try persist(trip); location.startUpdatingLocation(); message = "Grabación nativa reanudada." } catch { failStorage(error) }
    }
    func finish() {
        location.stopUpdatingLocation()
        guard var trip = current, trip.ended_at == nil else { return }
        do { try trip.finish(at: Date()); try persist(trip); message = trip.points.isEmpty ? "Intento cerrado sin puntos GPS. Puedes iniciar otro recorrido. Copia local conservada." : "Guardado en el iPhone. Pendiente de sincronización."; Task { await sync() } }
        catch { pause(); message = error.localizedDescription }
    }
    private func failStorage(_ error: Error) {
        location.stopUpdatingLocation(); storageFailed = true
        message = "Grabación detenida: no se pudo guardar. \(error.localizedDescription)"
        // Leave the original on disk; never replace it with an empty trip.
        if current?.ended_at == nil { current?.state = "paused" }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard var trip = current, trip.state == "recording", !storageFailed else { return }
        for sample in locations.sorted(by: { $0.timestamp < $1.timestamp }) {
            let point = GPSPoint(lat: sample.coordinate.latitude, lon: sample.coordinate.longitude, time: Clock.string(sample.timestamp), accuracy: sample.horizontalAccuracy,
                                 speed: sample.speed >= 0 && sample.speed.isFinite ? sample.speed : nil,
                                 altitude: sample.verticalAccuracy >= 0 && sample.altitude.isFinite ? sample.altitude : nil, segment: trip.segment)
            guard trip.append(point) else { continue }
            do { try persist(trip); message = "\(trip.points.count) puntos guardados · precisión \(Int(sample.horizontalAccuracy)) m." }
            catch { failStorage(error); return }
        }
        if trip.points.count >= 200_000 { pause(); message = "Límite de puntos alcanzado. Finaliza el recorrido." }
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if (error as? CLError)?.code == .denied { pause(); message = "Se retiró el permiso de ubicación. Puntos conservados." }
        else { message = "Esperando señal GPS. Puntos anteriores conservados." }
    }
    func sync() async {
        guard !syncing, !storageFailed else { return }
        syncing = true; defer { syncing = false }
        do {
            let pending = try store.all().filter { !$0.synced && !$0.points.isEmpty }
            guard !pending.isEmpty else { return }
            let user = try await identity()
            for trip in pending where trip.owner_id == user.id {
                if trip.ended_at != nil {
                    _ = try await request("activities", method: "POST", body: trip.upload())
                    // Read latest state after awaiting network, never overwrite newly appended points.
                    guard var latest = try store.all().first(where: { $0.id == trip.id }) else { continue }
                    latest.synced = true; try store.save(latest)
                } else {
                    let offset = min(trip.next_offset, trip.points.count - 1)
                    let batch = LiveBatch(sport: trip.sport, started_at: trip.started_at, state: trip.state, offset: offset, points: Array(trip.points.dropFirst(offset).prefix(5000)))
                    let response = try await request("live/" + trip.id, method: "PUT", body: JSONEncoder().encode(batch))
                    let result = try JSONDecoder().decode(LiveResult.self, from: response)
                    guard !result.finalized else { throw TrialError.message("Este recorrido ya está cerrado en el servidor. Copia local conservada.") }
                    guard var latest = try store.all().first(where: { $0.id == trip.id }) else { continue }
                    latest.next_offset = result.next_offset; try store.save(latest)
                }
            }
            trips = try store.all()
            if let id = current?.id { current = trips.first { $0.id == id } }
        } catch { message = "Sincronización pendiente: \(error.localizedDescription)" }
    }
    private struct LiveBatch: Encodable { let sport: String; let started_at: String; let state: String; let offset: Int; let points: [GPSPoint] }
    private struct LiveResult: Decodable { let finalized: Bool; let next_offset: Int }
    func export() throws -> URL {
        // Export only the verified account, not other accounts on a shared phone.
        guard let owner else { throw TrialError.message("Verifica tu cuenta para exportar.") }
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("Miles-copia-local.json")
        try JSONEncoder().encode(store.all().filter { $0.owner_id == owner }).write(to: file, options: .atomic)
        return file
    }
}

private final class SameOriginRedirects: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(request.url?.scheme == "https" && request.url?.host == Recorder.origin.host && request.url?.port == Recorder.origin.port ? request : nil)
    }
}
