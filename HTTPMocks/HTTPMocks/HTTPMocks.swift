//
//  HTTPMocks.swift
//  HTTPMocks
//
//  Created by apple on 2018/4/4.
//  Copyright © 2018年 Pszertlek. All rights reserved.
//

import Foundation

public typealias HTTPMocksTestBlock = (URLRequest) -> Bool
public typealias HTTPMocksResponseBlock = (URLRequest) -> HTTPMocksResponse

public class HTTPMocksDescriptor: CustomStringConvertible {
    public var description: String {
        return "name:\(name ?? "nil")"
    }
    
    var name: String?
    var testBlock: HTTPMocksTestBlock
    var responseBlock: HTTPMocksResponseBlock
    init(name: String? = nil, testBlock: @escaping HTTPMocksTestBlock, responseBlock: @escaping HTTPMocksResponseBlock) {
        self.testBlock = testBlock
        self.name = name
        self.responseBlock = responseBlock
    }
}

open class HTTPMocks {
    static let shared = HTTPMocks()
    lazy var lock: NSLock = NSLock()

    lazy var mockDescriptors = [HTTPMocksDescriptor]()
    
    var onMockActivationBlock: ((URLRequest, HTTPMocksDescriptor,HTTPMocksResponse) -> Void)?
    var onMockRedirectBlock: ((URLRequest, URLRequest, HTTPMocksDescriptor) -> Void)?
    var afterMockFinishBlock: ((URLRequest, HTTPMocksDescriptor?, HTTPMocksResponse?,Error?) -> Void)?
    var onMockMissingBlock: ((URLRequest) -> Void)?
    var enable: Bool = true {
        didSet {
            if enable {
                URLProtocol.registerClass(HTTPMocksProtocol.self)
            } else {
                URLProtocol.unregisterClass(HTTPMocksProtocol.self)
            }
        }
    }
    private init() {
        self.enable = true
    }
    
    @discardableResult
    public static func mockRequests(testBlock: @escaping HTTPMocksTestBlock,responseBlock: @escaping HTTPMocksResponseBlock) -> HTTPMocksDescriptor {
        let mock =  HTTPMocksDescriptor(testBlock: testBlock, responseBlock: responseBlock)
        self.shared.addMock(mock)
        return mock
    }
    
    public static func remove(mock: HTTPMocksDescriptor) {
        self.shared.removeMock(mock)
    }
}

//MARK: Private

public extension HTTPMocks {
    func addMock(_ mock: HTTPMocksDescriptor) {
        lock.lock()
        mockDescriptors.append(mock)
        lock.unlock()
    }
    
    func removeMock(_ mock: HTTPMocksDescriptor) -> Void {
        lock.lock()
        let index = mockDescriptors.index { return $0 === mock
        }
        if let index = index {
            mockDescriptors.remove(at: index)
        }
        lock.unlock()
    }
    
    func removeAll() {
        lock.lock()
        mockDescriptors.removeAll()
        lock.unlock()
    }
    
    func firstMockPassingTest(for request: URLRequest) -> HTTPMocksDescriptor? {
        lock.lock()
        var result: HTTPMocksDescriptor?
        for mock in mockDescriptors.reversed() {
            if mock.testBlock(request) {
                result = mock
            }
        }
        lock.unlock()
        return result
    }
}

//MARK:Disable & Enable

public extension HTTPMocks {
    public static func setEnable(_ enable: Bool) {
        HTTPMocks.shared.enable = enable
    }

    public static func isEnable() -> Bool {
        return HTTPMocks.shared.enable
    }
    public static func sessionConfigure(_ sessionConfigure: URLSessionConfiguration, enabled: Bool) {
        var urlProtocols = sessionConfigure.protocolClasses!
        let proto = HTTPMocksProtocol.self
        
        let index = urlProtocols.index { (type) -> Bool in
            return type == proto
        }
        if enabled && index == nil{
            urlProtocols.insert(proto, at: 0)
        } else if !enabled && index != nil {
            urlProtocols.remove(at: index!)
        }
        sessionConfigure.protocolClasses = urlProtocols
    }
    
    public static func isEnabledFor(_ sessionConfiguration: URLSessionConfiguration) -> Bool {
        let urlProtocols = sessionConfiguration.protocolClasses!
        let proto = HTTPMocksProtocol.self
        
        let index = urlProtocols.index { (type) -> Bool in
            return type == proto
        }
        return index != nil
    }

    
}

