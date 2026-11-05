import SwiftUI
import WebKit
import UIKit

@main struct MilesApp: App {
    @StateObject private var recorder = Recorder()
    @State private var selectedTab = 0
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedTab) {
                Website(recorder: recorder, onRecord: { selectedTab = 1 }).tabItem { Label("Web", systemImage: "map") }.tag(0)
                RecordingScreen(recorder: recorder).tabItem { Label("Grabar GPS", systemImage: "location.fill") }.tag(1)
            }
            .tint(Color(red: 0.1, green: 0.3, blue: 0.23))
            .onChange(of: phase) { value in
                // Do not pause on background: Core Location owns the recorder.
                if value == .active { Task { await recorder.sync() } }
            }
        }
    }
}

struct Website: UIViewRepresentable {
    let recorder: Recorder
    let onRecord: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onRecord: onRecord) }
    func makeUIView(context: Context) -> WKWebView {
        recorder.web.navigationDelegate = context.coordinator
        if recorder.web.url == nil { recorder.web.load(URLRequest(url: Recorder.origin)) }
        return recorder.web
    }
    func updateUIView(_ view: WKWebView, context: Context) {}
    final class Coordinator: NSObject, WKNavigationDelegate {
        let onRecord: () -> Void
        init(onRecord: @escaping () -> Void) { self.onRecord = onRecord }
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            let url = navigationAction.request.url
            if url?.scheme == "miles", url?.host == "record", navigationAction.targetFrame?.isMainFrame == true {
                onRecord(); decisionHandler(.cancel); return
            }
            if url?.scheme == "https", url?.host == Recorder.origin.host, url?.port == Recorder.origin.port, url?.fragment == "grabar" {
                onRecord(); decisionHandler(.cancel); return
            }
            decisionHandler(url?.scheme == "https" && url?.host == Recorder.origin.host && url?.port == Recorder.origin.port ? .allow : .cancel)
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // This prototype has one recorder. Browser recording remains unchanged outside this app.
            webView.evaluateJavaScript("""
            (()=>{document.querySelectorAll('a[href="#grabar"]').forEach(link=>{
            link.setAttribute('href','miles://record');
            link.setAttribute('aria-label','Abrir grabador GPS del iPhone');
            });const section=document.getElementById('grabar');
            if(section){section.hidden=true;let text=document.getElementById('native-recording-help');
            if(!text){text=document.createElement('p');text.id='native-recording-help';section.before(text);}
            text.textContent='Para grabar con pantalla bloqueada, usa la pestaña Grabar GPS de esta app.';}
            })();
            """, completionHandler: nil)
        }
    }
}

struct RecordingScreen: View {
    @ObservedObject var recorder: Recorder
    @State private var sport = "walk"
    @State private var share: URL?
    @State private var exportError = ""
    var body: some View {
        NavigationView {
            Form {
                Section("Cuenta") {
                    Text(recorder.account)
                    Button("Verificar sesión de la web") { Task { await recorder.verify() } }
                }
                Section("Grabar en este iPhone") {
                    Picker("Actividad", selection: $sport) {
                        Text("Caminar").tag("walk"); Text("Correr").tag("run"); Text("Bicicleta").tag("bike")
                    }.disabled(recorder.current?.ended_at == nil && recorder.current != nil)
                    Button(recorder.preparing ? "Verificando cuenta…" : "Iniciar recorrido") { Task { await recorder.prepareStart(sport: sport) } }
                        .disabled(recorder.preparing || recorder.storageFailed || (recorder.current != nil && recorder.current?.ended_at == nil))
                    if let current = recorder.current {
                        Text("\(current.points.count) puntos guardados en el iPhone")
                        Text(current.state == "recording" ? "GPS activo" : current.ended_at == nil ? "En pausa" : "Finalizado")
                        if current.ended_at == nil {
                            Button("Pausar") { recorder.pause() }.disabled(current.state != "recording")
                            Button("Reanudar") { recorder.resume() }.disabled(current.state == "recording" || recorder.storageFailed)
                            Button("Finalizar y guardar") { recorder.finish() }
                        }
                    }
                    Text(recorder.message).font(.callout).accessibilityIdentifier("recordingStatus")
                    if recorder.locationNeedsSettings {
                        Button("Abrir ajustes de ubicación") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                        }
                    }
                }
                Section("Sincronización") {
                    Text("Los puntos se guardan aunque no haya internet. Conecta Tailscale para enviarlos a tu Dell. La sincronización se reintenta al abrir la app; en segundo plano puede demorarse.")
                    Button(recorder.syncing ? "Sincronizando…" : "Sincronizar ahora") { Task { await recorder.sync() } }.disabled(recorder.syncing)
                    ForEach(recorder.trips.filter { $0.owner_id == recorder.owner }) { trip in
                        VStack(alignment: .leading) {
                            Text(trip.started_at).font(.caption)
                            Text("\(trip.points.count) puntos · \(trip.synced ? "Enviado" : "Copia local conservada")")
                        }
                    }
                    Button("Compartir copia local de mi cuenta") {
                        do { share = try recorder.export() } catch { exportError = error.localizedDescription }
                    }
                    if !exportError.isEmpty { Text(exportError) }
                }
                Section("Prueba privada de siete días") {
                    Text("Versión 0.1.2 · GPS nativo").font(.caption)
                    Text("No fuerces el cierre de la app durante el recorrido. Si iOS la termina, al reabrir recuperaremos los puntos guardados y deberás reanudar. Antes de reinstalar o eliminar, sincroniza o exporta tus recorridos.")
                }
            }
            .navigationTitle("Miles · GPS nativo")
            .sheet(isPresented: Binding(get: { share != nil }, set: { if !$0 { share = nil } })) {
                if let share { ShareFile(url: share) }
            }
        }.navigationViewStyle(.stack)
            .task { await recorder.verify() }
    }
}

struct ShareFile: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: [url], applicationActivities: nil) }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
