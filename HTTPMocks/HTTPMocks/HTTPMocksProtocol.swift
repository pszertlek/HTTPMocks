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
    let kSlotTime = 0.25
    override public var cachedResponse: CachedURLResponse? {
        return nil
    }
    
    override init(request: URLRequest, cachedResponse: CachedURLResponse?, client: URLProtocolClient?) {
        super.init(request: request, cachedResponse: nil, client: client)
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
            HTTPMocks.shared.afterMockFinishBlock?(request,self.mockDescriptor!,nil, error)
            return
        }
        let responseMock = mockDescriptor.responseBlock(request)
        HTTPMocks.shared.onMockActivationBlock?(request,mockDescriptor,responseMock)
        if responseMock.error == nil {
            let urlResponse = HTTPURLResponse(url: request.url!, statusCode: responseMock.statusCode, httpVersion: "HTTP/1.1", headerFields: responseMock.headers as! [String : String])
            if request.httpShouldHandleCookies {
                let cookies = HTTPCookie.cookies(withResponseHeaderFields: responseMock.headers! as! [String : String], for: request.url!)
                HTTPCookieStorage.shared.setCookies(cookies, for: request.url, mainDocumentURL: request.mainDocumentURL)
            }
            let redirectLocation = responseMock.headers!["Location"]
            let redirectLocationURL = URL(string: redirectLocation as! String)
        }
    }
    
    override func stopLoading() {
        self.stopped = true
    }
    
    struct HTTPMocksStreamTimingInfo {
        var slotTime: TimeInterval
        var chunkSizePerSlot: Double
        var cumulativeChunkSize: Double
    }
    
    func streamData(for client: URLProtocolClient, mockResponse: HTTPMocksResponse, completion: @escaping (Error?) -> Void) {
        guard !self.stopped else {
            return
        }
        if mockResponse.dataSize > 0 && mockResponse.inputStream!.hasBytesAvailable {
            var timingInfo = HTTPMocksStreamTimingInfo(slotTime: kSlotTime, chunkSizePerSlot: 0, cumulativeChunkSize: 0)
            if mockResponse.responseTime < 0 {
                timingInfo.chunkSizePerSlot = fabs(mockResponse.responseTime * 1000) * timingInfo.slotTime
            } else if mockResponse.responseTime < kSlotTime {
                timingInfo.chunkSizePerSlot = Double(mockResponse.dataSize)
                timingInfo.slotTime = mockResponse.responseTime
            } else {
                timingInfo.chunkSizePerSlot = Double(mockResponse.dataSize) / mockResponse.responseTime * timingInfo.slotTime
            }
            self.streamData(for: client, stream: mockResponse.inputStream!, timingInfo: timingInfo, completion: completion)
        } else {
            
        }
    }
    
    func streamData(for client: URLProtocolClient, stream: InputStream, timingInfo: HTTPMocksStreamTimingInfo, completion: @escaping (Error?) -> Void) {
        assert(timingInfo.chunkSizePerSlot > 0)
        if stream.hasBytesAvailable && !self.stopped {
            let cumulativeChunkSizeAfterRead = timingInfo.cumulativeChunkSize + timingInfo.chunkSizePerSlot
            let chunkSizeToRead = floor(cumulativeChunkSizeAfterRead) - floor(timingInfo.cumulativeChunkSize)
            var timing = timingInfo
            timing.cumulativeChunkSize = cumulativeChunkSizeAfterRead
            if chunkSizeToRead == 0 {
                self.executeOnClinetRunLoopAfter(delay: timing.slotTime) {
                    self.streamData(for: client, stream: stream, timingInfo: timing, completion: completion)
                }
            } else {
                let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(chunkSizeToRead))
                let bytesRead = stream.read(buffer, maxLength: Int(chunkSizeToRead))
                if bytesRead > 0 {
                    let data = NSData(bytesNoCopy: buffer, length: bytesRead) as Data
                    self.executeOnClinetRunLoopAfter(delay: Double(bytesRead) / timing.slotTime) {
                        client.urlProtocol(self, didLoad: data)
                        self .streamData(for: client, stream: stream, timingInfo: timing, completion: completion)
                    }
                } else {
                    completion(stream.streamError)
                }
                free(buffer)
            }
        }
    }
    
    func executeOnClinetRunLoopAfter(delay delayInSeconds: TimeInterval, block: @escaping () -> Void) {
        let popTime = DispatchTime(uptimeNanoseconds: UInt64(delayInSeconds) * NSEC_PER_SEC)
        DispatchQueue.global(qos: .default).asyncAfter(deadline: popTime) {
            CFRunLoopPerformBlock(self.clientRunLoop, CFRunLoopMode.defaultMode as CFTypeRef, block)
            CFRunLoopWakeUp(self.clientRunLoop)
        }
    }
}
