//
//  HTTPMocks.swift
//  HTTPMocks
//
//  Created by apple on 2018/4/4.
//  Copyright © 2018年 Pszertlek. All rights reserved.
//

import Foundation

typealias HTTPMocksTestBlock = (URLRequest) -> Bool
typealias HTTPMocksResponseBlock = (URLRequest) -> HTTPMocksResponse

class HTTPMocksDescriptor: CustomStringConvertible {
    var description: String {
        return "name:\(name ?? "nil")"
    }
    
    var name: String?
    fileprivate var testBlock: HTTPMocksTestBlock
    fileprivate var responseBlock: HTTPMocksResponseBlock
    init(name: String? = nil, testBlock: @escaping HTTPMocksTestBlock, responseBlock: @escaping HTTPMocksResponseBlock) {
        self.testBlock = testBlock
        self.name = name
        self.responseBlock = responseBlock
    }
}

class HTTPMocks {
    static let shared = HTTPMocks()
    lazy var lock: NSLock = NSLock()

    lazy var mockDescriptors = [HTTPMocksDescriptor]()
    
    var onMockActivationBlock: ((URLRequest, HTTPMocksDescriptor,HTTPMocksResponse) -> Void)?
    var onMockRedirectBlock: ((URLRequest, URLRequest, HTTPMocksDescriptor) -> Void)?
    var afterMockFinishBlock: ((URLRequest, HTTPMocksDescriptor, HTTPMocksResponse?,Error) -> Void)?
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
        
    }
    static func mockRequests(testBlock: @escaping HTTPMocksTestBlock,responseBlock: @escaping HTTPMocksResponseBlock) -> HTTPMocksDescriptor {
        return HTTPMocksDescriptor(testBlock: testBlock, responseBlock: responseBlock)
    }
    static func remove(stub: HTTPMocksDescriptor) {
        
    }
}

//MARK: Private

extension HTTPMocks {
    func addMock(_ mock:HTTPMocksDescriptor) {
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

extension HTTPMocks {
//    static func setEnable(_ enable: Bool) {
//        HTTPMocks.shared.enable = enable
//    }
//
//    static func isEnable() -> Bool {
//        return HTTPMocks.shared.enable
//    }
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

