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
            let error = NSError(domain: "YTSearchManager", code: 1001, userInfo: [NSLocalizedString("message", comment: ""): NSLocalizedString("API配置未完成", comment: "")])
            completion(.failure(error))
            return
        }
        
        // 构建URL
        var urlComponents = URLComponents(string: "\(configManager.apiUrl)/search")
        let queryItems = [
            URLQueryItem(name: "platform", value: "youtube"),
            URLQueryItem(name: "q", value: keyword),
            pageToken != nil ? URLQueryItem(name: "pageToken", value: pageToken) : nil
        ].compactMap { $0 }
        
        urlComponents?.queryItems = queryItems
        
        guard let url = urlComponents?.url else {
            let error = NSError(domain: "YTSearchManager", code: 1002, userInfo: [NSLocalizedString("message", comment: ""): NSLocalizedString("无效的URL", comment: "")])
            completion(.failure(error))
            return
        }
        
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
                let error = NSError(domain: "YTSearchManager", code: httpResponse.statusCode, userInfo: [NSLocalizedString("message", comment: ""): NSLocalizedString("服务器错误: \(httpResponse.statusCode)", comment: "")])
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            // 解析JSON
            do {
                let decoder = JSONDecoder()
                let result = try decoder.decode(SearchResult.self, from: data)
                DispatchQueue.main.async {
                    completion(.success(result))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
        
        task.resume()
    }
} 