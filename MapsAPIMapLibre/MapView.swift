import MapLibre
import SwiftUI

// Rate-limited demo API key. Will be replaced from time to time. Do not use.
// Get an API key here: https://content.meteoblue.com/en/access-options/meteoblue-weather-api
private let apiKey = "be72f76237db"

// Weather model. For all domains and height levels, see
// https://docs.meteoblue.com/en/weather-apis/maps-api/domains
private let domain = "NEMSAUTO"

// Colour scale: from each temperature step (°C) upwards the given colour is used.
// Values below the first step are not drawn.
private let temperatureColors: [(step: Int, color: String)] = [
    (-100, "rgb(52,140,237)"), (-8, "rgb(68,177,246)"), (-6, "rgb(81,203,250)"),
    (-4, "rgb(128,224,247)"), (-2, "rgb(160,234,247)"), (0, "rgb(0,239,124)"),
    (2, "rgb(0,228,82)"), (4, "rgb(0,200,72)"), (6, "rgb(16,184,122)"),
    (8, "rgb(41,123,93)"), (10, "rgb(0,114,41)"), (12, "rgb(60,161,44)"),
    (14, "rgb(121,208,48)"), (16, "rgb(181,255,51)"), (18, "rgb(216,247,161)"),
    (20, "rgb(255,246,0)"), (22, "rgb(248,223,11)"), (24, "rgb(253,202,12)"),
    (26, "rgb(252,172,5)"), (28, "rgb(248,141,0)"), (30, "rgb(255,102,0)"),
]

struct MapView: UIViewRepresentable {
    func makeUIView(context: Context) -> MLNMapView {
        // 1. Background map from meteoblue. Also available: "radarmap".
        let styleURL = URL(string: "https://maps-api.meteoblue.com/mapstyle/weathermap?lang=en&apikey=\(apiKey)")
        let mapView = MLNMapView(frame: .zero, styleURL: styleURL)
        mapView.setCenter(CLLocationCoordinate2D(latitude: 47, longitude: 7), zoomLevel: 4, animated: false)
        mapView.delegate = context.coordinator
        return mapView
    }

    func updateUIView(_ mapView: MLNMapView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, MLNMapViewDelegate {
        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            // 2. Ask the Time API for the current time step of the weather model.
            // Full docs: https://docs.meteoblue.com/en/weather-apis/maps-api/time-api
            let timeApiURL = URL(string: "https://maps-api.meteoblue.com/v1/time/hourly/\(domain)?apikey=\(apiKey)")!
            Task {
                do {
                    let (data, _) = try await URLSession.shared.data(from: timeApiURL)
                    let timeInfo = try JSONDecoder().decode(TimeInfo.self, from: data)
                    addTemperatureLayer(to: style, time: timeInfo.current, lastUpdate: timeInfo.lastUpdate ?? "")
                } catch {
                    print("Time API request failed: \(error)")
                }
            }
        }

        // 3. Add the temperature tiles on top of the background map.
        private func addTemperatureLayer(to style: MLNStyle, time: String, lastUpdate: String) {
            // Layer definition: weather variable code (11 = temperature) ~ height level ~ time resolution ~
            // aggregation ~ colour scale. Tile API docs: https://docs.meteoblue.com/en/weather-apis/maps-api/tile-api
            let layer = "11~2%20m%20above%20gnd~hourly~none~contourSteps~"
                + temperatureColors.map { "\($0.step)~\($0.color)" }.joined(separator: "~")

            let tileURL = "https://maps-api.meteoblue.com/v1/map/raster/\(domain)/\(time)/\(layer)/{z}/{x}/{y}"
                + "?temperatureUnit=C&apikey=\(apiKey)&lastUpdate=\(lastUpdate)" // lastUpdate is for cache busting

            let source = MLNRasterTileSource(identifier: "temperature-source", tileURLTemplates: [tileURL], options: [.tileSize: 256])
            style.addSource(source)

            let rasterLayer = MLNRasterStyleLayer(identifier: "temperature-layer", source: source)
            rasterLayer.rasterOpacity = NSExpression(forConstantValue: 0.7)

            // Insert below the "building" layer, so borders and labels of the background map stay on top.
            if let buildingLayer = style.layer(withIdentifier: "building") {
                style.insertLayer(rasterLayer, below: buildingLayer)
            } else {
                style.addLayer(rasterLayer)
            }
        }
    }
}

// Response of the Time API, e.g. {"current": "2026-11-03T12:00", "lastUpdate": "2026-11-03T09:45:11", ...}
private struct TimeInfo: Decodable {
    let current: String
    let lastUpdate: String?
}
