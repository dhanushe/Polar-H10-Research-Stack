//
//  APIServer.swift
//  URAP Polar H10 V1
//
//  Lightweight HTTP API server for exposing recordings to Python clients.
//

import Foundation
import Network

/// Simple in-app HTTP server exposing recordings over the local network.
final class APIServer {
    static let shared = APIServer()

    private let queue = DispatchQueue(label: "com.urap.APIServer")
    private var listener: NWListener?

    /// Port the server is listening on (if running)
    private(set) var port: UInt16?

    var isRunning: Bool {
        listener != nil
    }

    private init() {}

    // MARK: - Public API

    func start(on port: UInt16 = 8080) {
        guard listener == nil else { return }

        do {
            let parameters = NWParameters.tcp
            let listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)
            self.listener = listener
            self.port = port

            listener.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }

            listener.stateUpdateHandler = { newState in
                print("APIServer listener state: \(newState)")
            }

            listener.start(queue: queue)
            print("📡 APIServer started on port \(port)")
        } catch {
            print("❌ Failed to start APIServer: \(error.localizedDescription)")
            listener = nil
            self.port = nil
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        port = nil
        print("🛑 APIServer stopped")
    }

    /// Best-effort base URL string for the current device on the local network.
    /// This uses the Wi-Fi (en0) IPv4 address if available; otherwise returns nil.
    func baseURLString() -> String? {
        guard let port = port else { return nil }
        guard let ip = Self.wifiIPv4Address() else { return nil }
        return "http://\(ip):\(port)"
    }

    // MARK: - Connection Handling

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(on: connection)
    }

    private func receive(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16 * 1024) { [weak self] data, _, _, error in
            guard let self else { return }

            if let error = error {
                print("APIServer receive error: \(error.localizedDescription)")
                connection.cancel()
                return
            }

            guard let data = data, !data.isEmpty,
                  let requestString = String(data: data, encoding: .utf8) else {
                connection.cancel()
                return
            }

            let responseData = self.handleRequest(raw: requestString)

            connection.send(content: responseData, completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }

    // MARK: - Request Handling

    private func handleRequest(raw: String) -> Data {
        let lines = raw.split(separator: "\r\n", omittingEmptySubsequences: false)
        guard let requestLine = lines.first else {
            return httpResponse(statusCode: 400, statusText: "Bad Request", body: "Bad Request\n")
        }

        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else {
            return httpResponse(statusCode: 400, statusText: "Bad Request", body: "Bad Request\n")
        }

        let method = parts[0]
        let target = parts[1]

        guard method == "GET" else {
            return httpResponse(statusCode: 405, statusText: "Method Not Allowed", body: "Only GET is supported.\n")
        }

        let fullPath = String(target.split(separator: "?").first ?? "/")

        if fullPath == "/recordings" {
            return handleListRecordings()
        } else if fullPath.hasPrefix("/recordings/") {
            let id = String(fullPath.dropFirst("/recordings/".count))
            return handleGetRecording(id: id)
        } else {
            return httpResponse(statusCode: 404, statusText: "Not Found", body: "Not Found\n")
        }
    }

    private func handleListRecordings() -> Data {
        let result = RecordingsStorageManager.shared.loadAllRecordingMetadata()

        switch result {
        case .failure(let error):
            let message = "Failed to load recordings: \(error.localizedDescription)\n"
            return httpResponse(statusCode: 500, statusText: "Internal Server Error", body: message)

        case .success(let recordings):
            let summaries = recordings.map { recording in
                RecordingSummary(
                    id: recording.id,
                    name: recording.name,
                    startDate: recording.startDate,
                    endDate: recording.endDate,
                    duration: recording.duration,
                    sensorCount: recording.sensorCount,
                    averageHeartRate: recording.averageHeartRate,
                    averageSDNN: recording.averageSDNN,
                    averageRMSSD: recording.averageRMSSD
                )
            }

            do {
                let data = try JSONEncoder.iso8601Pretty.encode(summaries)
                return httpResponse(statusCode: 200, statusText: "OK", bodyData: data, contentType: "application/json")
            } catch {
                let message = "Failed to encode recordings: \(error.localizedDescription)\n"
                return httpResponse(statusCode: 500, statusText: "Internal Server Error", body: message)
            }
        }
    }

    private func handleGetRecording(id: String) -> Data {
        let result = RecordingsStorageManager.shared.loadRecording(withId: id)

        switch result {
        case .failure(let error):
            if case RecordingStorageError.recordingNotFound = error {
                return httpResponse(statusCode: 404, statusText: "Not Found", body: "Recording not found.\n")
            } else {
                let message = "Failed to load recording: \(error.localizedDescription)\n"
                return httpResponse(statusCode: 500, statusText: "Internal Server Error", body: message)
            }

        case .success(let recording):
            guard let recording = recording else {
                return httpResponse(statusCode: 404, statusText: "Not Found", body: "Recording not found.\n")
            }

            do {
                let data = try JSONEncoder.iso8601Pretty.encode(recording)
                return httpResponse(statusCode: 200, statusText: "OK", bodyData: data, contentType: "application/json")
            } catch {
                let message = "Failed to encode recording: \(error.localizedDescription)\n"
                return httpResponse(statusCode: 500, statusText: "Internal Server Error", body: message)
            }
        }
    }

    // MARK: - Response Helpers

    private func httpResponse(
        statusCode: Int,
        statusText: String,
        body: String,
        contentType: String = "text/plain; charset=utf-8"
    ) -> Data {
        let bodyData = Data(body.utf8)
        return httpResponse(statusCode: statusCode, statusText: statusText, bodyData: bodyData, contentType: contentType)
    }

    private func httpResponse(
        statusCode: Int,
        statusText: String,
        bodyData: Data,
        contentType: String
    ) -> Data {
        var headers: [String] = []
        headers.append("HTTP/1.1 \(statusCode) \(statusText)")
        headers.append("Content-Type: \(contentType)")
        headers.append("Content-Length: \(bodyData.count)")
        headers.append("Connection: close")
        headers.append("Access-Control-Allow-Origin: *")
        headers.append("")
        headers.append("")

        let headerData = Data(headers.joined(separator: "\r\n").utf8)

        var response = Data()
        response.append(headerData)
        response.append(bodyData)
        return response
    }

    // MARK: - IP Helper

    private static func wifiIPv4Address() -> String? {
        var address: String?

        var ifaddrPointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPointer) == 0, let firstAddr = ifaddrPointer else {
            return nil
        }

        defer {
            freeifaddrs(ifaddrPointer)
        }

        var ptr = firstAddr
        while ptr.pointee.ifa_next != nil {
            let interface = ptr.pointee

            let name = String(cString: interface.ifa_name)
            let addrFamily = interface.ifa_addr.pointee.sa_family

            if addrFamily == UInt8(AF_INET), name == "en0" {
                var addr = interface.ifa_addr.pointee
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                let result = getnameinfo(
                    &addr,
                    socklen_t(interface.ifa_addr.pointee.sa_len),
                    &hostname,
                    socklen_t(hostname.count),
                    nil,
                    0,
                    NI_NUMERICHOST
                )
                if result == 0 {
                    address = String(cString: hostname)
                    break
                }
            }

            if let next = interface.ifa_next {
                ptr = next
            } else {
                break
            }
        }

        return address
    }
}

// MARK: - Supporting Types

private struct RecordingSummary: Codable {
    let id: String
    let name: String
    let startDate: Date
    let endDate: Date
    let duration: TimeInterval
    let sensorCount: Int
    let averageHeartRate: Double
    let averageSDNN: Double
    let averageRMSSD: Double
}

private extension JSONEncoder {
    static var iso8601Pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

