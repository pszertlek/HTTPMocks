//
//  HTTPMocksProtocol.swift
//  HTTPMocks
//
//  Created by apple on 2018/4/4.
//  Copyright © 2018年 Pszertlek. All rights reserved.
//

import Foundation

class HTTPMocksProtocol: URLProtocol {
    var stopped: Bool = false
    var mockDescriptor: HTTPMocksDescriptor?
    var clientRunLoop: CFRunLoop!
    override var cachedResponse: CachedURLResponse? {
        return nil
    }
    
    override init(request: URLRequest, cachedResponse: CachedURLResponse?, client: URLProtocolClient?) {
        super.init(request: request, cachedResponse: cachedResponse, client: client)
        self.mockDescriptor = HTTPMocks.shared.firstMockPassingTest(for: request)
    }
    
    func sss() {

    }
    
    override class func canInit(with request:URLRequest) -> Bool {
        let found = HTTPMocks.shared.firstMockPassingTest(for: request) != nil
        if !found {
            HTTPMocks.shared.onMockMissingBlock?(request)
        }
        return found
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        self.clientRunLoop = CFRunLoopGetCurrent()
        let request = self.request
        guard let mockDescriptor = self.mockDescriptor else {
            let error = NSError.init(domain: "HTTPMocks", code: 500, userInfo: [NSLocalizedDescriptionKey:"It seems like the stub has been removed BEFORE the response had time to be sent."])
            client?.urlProtocol(self, didFailWithError: error as Error)
            HTTPMocks.shared.afterMockFinishBlock?(request,self.mockDescriptor,nil, error)
            return
        }
        let response = mockDescriptor.res
    }
}
