//
//  Request.swift
//  MMLanScanSwiftDemo
//
//  Created by Businsoft on 18/12/2018.
//  Copyright © 2018 Miksoft. All rights reserved.
//

import Foundation

class Request: NSObject {
    
    var queue: OperationQueue
    
    override init() {
        self.queue = OperationQueue()
        super.init()

        self.queue.maxConcurrentOperationCount = 10
        self.queue.addObserver(self, forKeyPath: "operations", options: [], context: nil)
    }
    
    deinit {
        
    }
    
    
    func scan(with devicesList:[MMDevice]) {
        NSLog("Start")
        for device in devicesList {
            if !device.isScanning {
                continue
            }
            self.queue.addOperation {
                self.get(urlPath: "http://\(device.ipAddress!)/bl_index.asp") { response, error in
                    NSLog("IP: \(device.ipAddress!)")
                    device.isScanning = false
                    device.isScanned = true
                    if error != nil {
                        NSLog("Error: \(error?.localizedDescription)")
                    } else {
                        NSLog("Res: \(response)")
                        if response == "200" {
                            self.foundSpeaker(ip: "\(device.ipAddress!)")
                        }
                    }
                }
            }
        }
    }
    
    func get(urlPath: String, completion: @escaping (String?, Error?) -> Void) {
        let url = URL(string: urlPath)!
        
        var request = URLRequest(url: url)
        
        request.httpMethod = "GET"
        request.timeoutInterval = 30 // 1 mins
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        fetchedDatabyDataTask(from: request, completion: completion)
    }
    
    private func fetchedDatabyDataTask(from request: URLRequest, completion: @escaping (String?, Error?) -> Void){
        let task = URLSession.shared.dataTask(with: request, completionHandler: {
            data, response, error in
            if error != nil {
                completion(nil, error)
            }
            else {
                guard let data = data else { return }
                NSLog(data.translateDataToString())
                if let httpResponse = response as? HTTPURLResponse {
                    completion("\(httpResponse.statusCode)", nil)
                } else {
                    completion("404", nil)
                }
            }
        })
        task.resume()
    }
}

extension Request {
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "operations" {
            if self.queue.operationCount == 0 {
                self.finishSearching()
            }
        }
    }
    
    func finishSearching() {
        NSLog("Finish Searching")
        NotificationCenter.default.post(name: Notification.Name("didFinishedSearching"), object: nil)
    }
    
    func foundSpeaker(ip: String) {
        NSLog("Found Speaker")
        NotificationCenter.default.post(name: Notification.Name("didFoundSpeaker"), object: nil, userInfo: ["ip":ip])
        self.queue.cancelAllOperations()
    }
}
extension Data {
    func translateDataToString() -> String{
        guard let r = String(data: self, encoding: String.Encoding.utf8) else {
            return ""
        }
        return String(r.filter {!"\r\n".contains($0)})
    }
}
