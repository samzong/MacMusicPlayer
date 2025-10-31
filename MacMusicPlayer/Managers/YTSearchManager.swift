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
    
    // Search result model
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
    
    // Search method
    func search(keyword: String, pageToken: String? = nil, completion: @escaping (Result<SearchResult, Error>) -> Void) {
        // Check if configuration is valid
        guard configManager.isConfigValid else {
            let error = NSError(domain: "YTSearchManager", code: 1001, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("API configuration not completed", comment: "")])
            completion(.failure(error))
            return
        }
        
        // Ensure API URL is not empty and handle trailing slash
        let apiUrl = configManager.apiUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !apiUrl.isEmpty else {
            let error = NSError(domain: "YTSearchManager", code: 1002, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("API URL not configured", comment: "")])
            completion(.failure(error))
            return
        }
        
        // Build URL
        var urlComponents = URLComponents(string: "\(apiUrl)/search")
        let queryItems = [
            URLQueryItem(name: "platform", value: "youtube"),
            URLQueryItem(name: "q", value: keyword),
            pageToken != nil ? URLQueryItem(name: "pageToken", value: pageToken) : nil
        ].compactMap { $0 }
        
        urlComponents?.queryItems = queryItems
        
        guard let url = urlComponents?.url else {
            let error = NSError(domain: "YTSearchManager", code: 1002, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("Invalid URL", comment: "")])
            completion(.failure(error))
            return
        }
        
        // Log full request information
        print("YTSearchManager - Send request: URL: \(url.absoluteString), PageToken: \(pageToken ?? "nil")")
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(configManager.apiKey)", forHTTPHeaderField: "Authorization")
        
        // Send request
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = data else {
                let error = NSError(domain: "YTSearchManager", code: 1003, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("No data received", comment: "")])
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            // Check HTTP status code
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                let errorMessage = String(format: NSLocalizedString("Server Error: %@", comment: "Server error message"), String(httpResponse.statusCode))
                let error = NSError(domain: "YTSearchManager", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            // Parse JSON
            do {
                let decoder = JSONDecoder()
                let result = try decoder.decode(SearchResult.self, from: data)
                
                // Log response information
                print("YTSearchManager -Response received: Number of items: \(result.items.count), NextPageToken: \(result.nextPageToken ?? "nil"), Total results: \(result.totalResults)")
                
                DispatchQueue.main.async {
                    completion(.success(result))
                }
            } catch {
                print("YTSearchManager - JSON parsing error: \(error)")
                // Print raw data content for debugging
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