//
//  EventSource.swift
//  EventSource
//
//  Created by Dakota Smith on 10/3/16.
//
//

import Foundation

public struct Event {
    let id: String?
    let event: String?
    let data: String?
}

public extension EventSource {
    public enum State: Int {
        case connecting
        case open
        case closed
    }
}

public class EventSource {
    let url: URL
    var readyState: State
    var lastID: String?
    var reconnectTime: DispatchTimeInterval
    
    public var onMessage: ((Event) -> Void)?
    public var onError: ((Error) -> Void)?
    
    private let socket: Socket
    
    //TODO: See if a switch to Data is worth it
    private var buffer: String = ""
    
    public init(url: URL) throws {
        guard url.host != nil, url.port != nil else {
             throw NSError()
        }
        self.url = url
        readyState = .closed
        reconnectTime = .seconds(5)
        
        try socket = Socket.create()
    }
    
    public func open() throws {
        guard let host = self.url.host, let port = self.url.port else {
            throw NSError()
        }
        self.readyState = .connecting
        try socket.connect(to: host, port: Int32(port))
        let path: String
        if let q = url.query {
            path = url.path + "?" + q
        } else {
            path = url.path
        }
        let request = "GET \(path) HTTP/1.0\r\nAccept: text/event-stream\r\nCache-Control: no-cache\r\n\r\n"
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
        self.readyState = .open
        DispatchQueue.global(qos: .utility).async {
            self.runLoop()
        }
    }

    public func close() {
	    self.socket.close()
        self.readyState = .closed
    }
    
    func runLoop() {
        while readyState == .open {
		do {
			guard let newData = try socket.readString() else {
			    continue
			}
			    
		    buffer.append(newData)
		}
		catch let e {
			self.onError?(e)
		}
                
                let records: ArraySlice<String>
                let components = buffer.components(separatedBy: "\n\n")

                if !buffer.hasSuffix("\n\n") {
                    records = components.dropLast()
                    buffer = components.last!
                }
                else {
                    records = components[0..<components.endIndex]
                }

		if let m = self.onMessage {

			let events = records.flatMap(parse(from:))
			
			for event in events {
				DispatchQueue.global(qos: .utility).async {
					m(e)
				}
			}	
		}

            }
        }
    }

    private func parse(from record: String) -> Event? {
	    
	    var id: String?
	    var event: String?
	    var data: String?
	    
	    let lines = record.components(separatedBy: .newlines).map({$0.trimmingCharacters(in: .whitespacesAndNewlines)}).filter({$0 != ""})

	    guard lines.count != 0 else {
		    return nil
	    }

	    for line in lines {
		
		if line.hasPrefix(":") {
		    continue
		}
		
		if line.hasPrefix("id:") {
		    id = line[line.index(line.startIndex, offsetBy: 3)..<line.endIndex]
		    self.lastID = record
		}
		
		if line.hasPrefix("event:") {
		    event = (event ?? "") + line[line.index(line.startIndex, offsetBy: 6)..<line.endIndex].trimmingCharacters(in: .whitespaces)
		}
		
		if line.hasPrefix("data:") {
		    data = (data ?? "") + line[record.index(line.startIndex, offsetBy: 5)..<line.endIndex].trimmingCharacters(in: .whitespaces)
		}
		
		if line.hasPrefix("retry:") {
		    guard let i = Int(line[line.index(line.startIndex, offsetBy: 6)..<line.endIndex].trimmingCharacters(in: .whitespaces)) else {
			continue
		    }
		    self.reconnectTime = .milliseconds(i)
		}
	    }

	    return Event(id: id, event: event, data: data)
	    
    }
}
