//
//  NetworkDispatcher.swift
//  register_study_photoGraphy
//
//  Created by Tatsuya Yamamoto on 2019/7/11.
//  Copyright © 2019 山本竜也. All rights reserved.
//

import Foundation

public enum NetworErrors: Error {
    case badInput
    case noData
}

public class NetworkDispatcher: Dispatcher {
    
    private var environment: Environment
    
    private var session: URLSession
    
    public required init(environment: Environment) {
        self.environment = environment
        self.session = URLSession(configuration: URLSessionConfiguration.default)
    }
    
    public func execute(request: Request) throws -> Promise<Response> {
        let rq = try self.prepareURLRequest(for: request)
        return Promise<Response>(in: .background, { resolve, _,_ in
            let d = self.session.dataTask(with: rq, completionHandler: { (data, urlResponse, error) in
                let response = Response( (urlResponse as? HTTPURLResponse, data, error), for: request)
                resolve(response)
            })
            d.resume()
        })
    }
    
    private func prepareURLRequest(for request: Request) throws -> URLRequest {
        // compose the url
        let fullUrl = "\(environment.host)\(request.path)"
        var urlRequest = URLRequest(url: URL(string: fullUrl)!)
        
        // working with parameters
        switch request.parameters {
        case .body(let params):
            // Parameters are part of the body
            if let params = params  {
                urlRequest.httpBody = try JSONSerialization.data(withJSONObject: (params), options: .init(rawValue:0))
            } else {
                throw NetworErrors.badInput
            }
        case .url(let params):
            // Parameters are part of the body
            if let params = params  {
                let query_params = params.map {(element) -> URLQueryItem in
                    return URLQueryItem(name: element.key, value: String(describing: element.value))
                }
                guard var components = URLComponents(string: fullUrl) else {
                    throw NetworErrors.badInput
                }
                components.queryItems = query_params
                urlRequest.url = components.url
            }
        case .multiPart(let name, let fileName, let mimeType, let data):
            let boundary = String(format: "%08x%08x", arc4random(), arc4random())
            urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            
            var body = Data()
            body.append("--\(boundary)\r\n".data(using: String.Encoding.utf8)!)
            body.append("Content-Disposition:form-data; name=\"\(name)\"\r\n\r\n".data(using: String.Encoding.utf8)!)
            body.append("hi\r\n".data(using: String.Encoding.utf8)!)
            body.append("--\(boundary)\r\n".data(using: String.Encoding.utf8)!)
            body.append("Content-Disposition:form-data; name=\"\(name)\"; filename=\"\(fileName)\"\r\n".data(using: String.Encoding.utf8)!)
            body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: String.Encoding.utf8)!)
            body.append(data)
            body.append("\r\n".data(using: String.Encoding.utf8)!)
            body.append("--\(boundary)--\r\n".data(using: String.Encoding.utf8)!)
            
            urlRequest.httpBody = body
            // e.g name: image, file name: image.png, mimetype: image/png
        case .none:
            break
        }
        
        // Add headers from environment and request
        environment.headers.forEach { urlRequest.addValue($0.value as! String, forHTTPHeaderField: $0.key) }
        request.headers?.forEach { urlRequest.addValue($0.value as! String, forHTTPHeaderField: $0.key)}
        
        // Setup HTTP method
        urlRequest.httpMethod = request.method.rawValue
        
        return urlRequest
    }
}
