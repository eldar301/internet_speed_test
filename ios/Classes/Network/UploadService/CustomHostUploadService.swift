//
//  CustomHostUploadService.swift
//  SpeedTestLib
//
//  Created by dhaurylenka on 2/6/18.
//  Copyright © 2018 Exadel. All rights reserved.
//

import Foundation

class CustomHostUploadService: NSObject, SpeedService {
    private var responseDate: Date?
    private var latestDate: Date?
    private var current: ((Speed, Speed) -> ())!
    private var final: ((Result<Speed, NetworkError>) -> ())!
    private var task: URLSessionUploadTask?
    
    func test(_ url: URL, fileSize: Int, timeout: TimeInterval, current: @escaping (Speed, Speed) -> (), final: @escaping (Result<Speed, NetworkError>) -> ()) {
        self.current = current
        self.final = final
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = ["Content-Type": "application/octet-stream",
                                       "Accept-Encoding": "gzip, deflate",
                                       "Content-Length": "\(fileSize)",
                                       "Connection": "keep-alive"]
        
        task = URLSession(configuration: sessionConfiguration(timeout: 15), delegate: self, delegateQueue: OperationQueue.main)
            .uploadTask(with: request, from: Data(count: fileSize))
        task?.resume()
    }
    
    func stop() {
        task?.cancel()
    }
}

extension CustomHostUploadService: URLSessionDataDelegate {
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Swift.Void) {
        let result = calculate(bytes: dataTask.countOfBytesSent, seconds: Date().timeIntervalSince(self.responseDate!))
        self.final(.value(result))
        responseDate = nil
    }
}

extension CustomHostUploadService: URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        guard let startDate = responseDate, let latesDate = latestDate else {
            responseDate = Date();
            latestDate = responseDate
            return
        }
        
        let currentTime = Date()
        let timeSpend = currentTime.timeIntervalSince(latesDate)
        
        let current = calculate(bytes: bytesSent, seconds: timeSpend)
        let average = calculate(bytes: totalBytesSent, seconds: -startDate.timeIntervalSinceNow)
        
        latestDate = currentTime
        
        self.current(current, average)
    }
    
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        if error != nil {
            let result = calculate(bytes: task!.countOfBytesReceived, seconds: Date().timeIntervalSince(self.responseDate ?? Date()))
            self.final(.value(result))
            responseDate = nil
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if error != nil {
            let result = calculate(bytes: self.task!.countOfBytesReceived, seconds: Date().timeIntervalSince(self.responseDate ?? Date()))
            self.final(.value(result))
            responseDate = nil
        }
    }
}
