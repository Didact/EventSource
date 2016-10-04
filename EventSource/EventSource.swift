//
//  EventSource.swift
//  EventSource
//
//  Created by Dakota Smith on 10/3/16.
//
//

import Foundation

struct Event {
    let id: String?
    let event: String?
    let data: String?
    
    func appending(other: Event) -> Event {
        return Event(id: other.id, event: (self.event ?? "") + (other.event ?? ""), data: (self.data ?? "") + (other.data ?? ""))
    }
}

extension _EventSource {
    enum State: Int {
        case connecting
        case open
        case closed
    }
}

public class _EventSource {
    let url: URL
    var readyState: State
    let withCredentials: Bool
    var lastID: String?
    var reconnectTime: DispatchTimeInterval
    
    var onMessage: ((Event) -> Void)?
    var onError: ((Error) -> Void)?
    
    private let socket: Socket
    
    //TODO: See if a switch to Data is worth it
    private var buffer: String = ""
    
    public init(url: URL) throws {
        guard url.host != nil, url.port != nil else {
             throw NSError()
        }
        self.url = url
        readyState = .closed
        withCredentials = false
        reconnectTime = .seconds(5)
        
        try socket = Socket.create()
    }
    
    public func open() throws {
        guard let host = self.url.host, let port = self.url.port else {
            throw NSError()
        }
        self.readyState = .connecting
        try socket.connect(to: host, port: Int32(port))
        print(url.path)
        let path: String
        if let q = url.query {
            path = url.path + "?" + q
        } else {
            path = url.path
        }
        let request = "GET \(path) HTTP/1.0\r\nAccept: text/event-stream\r\nCache-Control: no-cache\r\nConnection: keep-alive\r\n\r\n"
        try socket.write(from: request)
        
        guard let string = try socket.readString() else {
            throw NSError()
        }
        
        guard let headerEnd = string.range(of: "\r\n\r\n") else {
            throw NSError()
        }
        let header = string.substring(to: headerEnd.lowerBound)
        
        let fields = header.components(separatedBy: .newlines)
        guard fields.first?.lowercased().contains("200 ok") ?? false else {
            throw NSError()
        }
        
        guard fields.map({$0.lowercased()}).contains("content-type: text/event-stream") else {
            throw NSError()
        }
        
        buffer = string.substring(from: headerEnd.upperBound)
        DispatchQueue.global(qos: .utility).async {
            self.runLoop()
        }
        self.readyState = .open
    }
    
    func close() {
        self.readyState = .closed
    }
    
    func runLoop() {
        while readyState == .open {
            do {
                guard let newData = try socket.readString() else {
                    continue
                }
                            
                buffer.append(newData)
                
                let records: ArraySlice<String>
                let components = buffer.components(separatedBy: "\n\n")

                if !buffer.hasSuffix("\n\n") {
                    records = components.dropLast()
                    buffer = components.last!
                }
                else {
                    // there will be a last index if we have a suffix of \n\n
                    records = components[0..<components.indices.last!]
                }
                
                for record in records {
                    // process
                }
                
            }
            catch let e {
                self.onError?(e)
            }
        }
    }
    
    func parseEvent(_ text: String) -> Event? {
        return nil
    }
}
