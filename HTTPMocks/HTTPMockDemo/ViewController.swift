//
//  ViewController.swift
//  HTTPMockDemo
//
//  Created by apple on 2018/9/6.
//  Copyright © 2018年 Pszertlek. All rights reserved.
//

import UIKit
import Alamofire
import HTTPMocks

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        let button = UIButton(type: .custom)
        button.frame = CGRect(x: 100, y: 100, width: 100, height: 30)
        button.setTitle("request", for: .normal)
        view.addSubview(button)
        button.setTitleColor(UIColor.red, for: .normal)
        button.addTarget(self, action: #selector(buttonClick(button:)), for: .touchUpInside)
        
        HTTPMocks.mockRequests(testBlock: { (request) -> Bool in
            return true
        }) { (request) -> HTTPMocksResponse in
            let dict: [String : Any] = ["status":1,"msg":"hello"]
            let responseData = try! JSONSerialization.data(withJSONObject: dict, options: JSONSerialization.WritingOptions(rawValue: 0))
            let input = InputStream(data: responseData)
            return HTTPMocksResponse(inputStream: input, dataSize: Int64(responseData.count), statusCode: 200, headers: ["hello":"sss" as AnyObject])
        }
    }

    @objc func buttonClick(button:UIButton) {
        Alamofire.request("https://httpbin.org/get").responseJSON { response in
            print(response.request)  // 原始的URL请求
            print(response.response) // HTTP URL响应
            print(response.data)     // 服务器返回的数据
            print(response.result)   // 响应序列化结果，在这个闭包里，存储的是JSON数据
            
            if let JSON = response.result.value {
                print("JSON: \(JSON)")
            }
        }
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

