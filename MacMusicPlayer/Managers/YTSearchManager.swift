//
//  YTSearchManager.swift
//  MacMusicPlayer
//
//  Created by samzong<samzong.lu@gmail.com>
//

import Foundation

class YTSearchManager {
    static let shared = YTSearchManager()
    
    private let configManager = ConfigManager.shared
    
    // 搜索结果模型
    struct SearchResult: Codable {
        struct VideoItem: Codable {
            let videoId: String
            let videoUrl: String
            let title: String
            let thumbnailUrl: String
            let platform: String
        }
        
        let items: [VideoItem]
        let nextPageToken: String?
        let totalResults: Int
    }
    
    private init() {}
    
    // 搜索方法
    func search(keyword: String, pageToken: String? = nil, completion: @escaping (Result<SearchResult, Error>) -> Void) {
        // 检查配置是否有效
        guard configManager.isConfigValid else {
            let error = NSError(domain: "YTSearchManager", code: 1001, userInfo: [NSLocalizedString("message", comment: ""): NSLocalizedString("API configuration not completed", comment: "")])
            completion(.failure(error))
            return
        }
        
        // 确保API URL不为空并处理末尾斜杠
        let apiUrl = configManager.apiUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !apiUrl.isEmpty else {
            let error = NSError(domain: "YTSearchManager", code: 1002, userInfo: [NSLocalizedString("message", comment: ""): NSLocalizedString("API URL not configured", comment: "")])
            completion(.failure(error))
            return
        }
        
        // 构建URL
        var urlComponents = URLComponents(string: "\(apiUrl)/search")
        let queryItems = [
            URLQueryItem(name: "platform", value: "youtube"),
            URLQueryItem(name: "q", value: keyword),
            pageToken != nil ? URLQueryItem(name: "pageToken", value: pageToken) : nil
        ].compactMap { $0 }
        
        urlComponents?.queryItems = queryItems
        
        guard let url = urlComponents?.url else {
            let error = NSError(domain: "YTSearchManager", code: 1002, userInfo: [NSLocalizedString("message", comment: ""): NSLocalizedString("Invalid URL", comment: "")])
            completion(.failure(error))
            return
        }
        
        // 日志输出完整请求信息
        print("YTSearchManager - Send request: URL: \(url.absoluteString), PageToken: \(pageToken ?? "nil")")
        
        // 创建请求
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(configManager.apiKey)", forHTTPHeaderField: "Authorization")
        
        // 发送请求
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = data else {
                let error = NSError(domain: "YTSearchManager", code: 1003, userInfo: [NSLocalizedString("message", comment: ""): NSLocalizedString("没有接收到数据", comment: "")])
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            // 检查HTTP状态码
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                let error = NSError(domain: "YTSearchManager", code: httpResponse.statusCode, userInfo: [NSLocalizedString("message", comment: ""): NSLocalizedString("Server Error: \(httpResponse.statusCode)", comment: "")])
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            // 解析JSON
            do {
                let decoder = JSONDecoder()
                let result = try decoder.decode(SearchResult.self, from: data)
                
                // 日志输出响应信息
                print("YTSearchManager -Response received: Number of items: \(result.items.count), NextPageToken: \(result.nextPageToken ?? "nil"), Total results: \(result.totalResults)")
                
                DispatchQueue.main.async {
                    completion(.success(result))
                }
            } catch {
                print("YTSearchManager - JSON parsing error: \(error)")
                // 打印原始数据内容，帮助调试
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("YTSearchManager - Original JSON: \(jsonString)")
                }
                
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
        
        task.resume()
    }
} 