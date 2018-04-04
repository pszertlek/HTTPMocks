//
//  HTTPMocksResponse.swift
//  HTTPMocks
//
//  Created by apple on 2018/4/4.
//  Copyright © 2018年 Pszertlek. All rights reserved.
//

import Foundation

class HTTPMocksResponse {
    var headers: [String: AnyObject]?
    var statusCode = 0
    var inputStream: InputStream?
    var dataSize: Int64 = 0
    var requestTime: TimeInterval = 0
    var reponseTime: TimeInterval = 0
    var error: Error?
    
    convenience init(inputStream: InputStream,dataSize:Int64 = 0,statusCode: Int = 0, headers: [String: AnyObject]?) {
        self.init()
        self.inputStream = inputStream
        self.statusCode = statusCode
        self.headers = headers
        self.dataSize = dataSize
        if self.headers != nil {
            self.headers!["Content-Length"] = "\(dataSize)" as AnyObject
        }
    }
}
