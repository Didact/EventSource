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
}

extension _EventSource {
    enum State: Int {
        case connecting
        case open
        case closed
    }
}

public struct _EventSource {
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
    
    public mutating func open() throws {
        guard let host = self.url.host, let port = self.url.port else {
            throw NSError()
        }
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
        buffer = string.substring(from: headerEnd.upperBound)
    }
    
    mutating func runLoop() {
        
    }
}
