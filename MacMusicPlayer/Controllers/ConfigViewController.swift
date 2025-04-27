//
//  ConfigViewController.swift
//  MacMusicPlayer
//
//  Created by samzong<samzong.lu@gmail.com>
//

import Cocoa

class ConfigViewController: NSViewController {
    // MARK: - UI组件
    private let githubLinkButton = NSButton()
    private let apiUrlLabel = NSTextField()
    private let apiUrlTextField = NSTextField()
    private let apiKeyLabel = NSTextField()
    private let apiKeyTextField = NSTextField()
    private let saveButton = NSButton()
    private let cancelButton = NSButton()
    private let statusLabel = NSTextField()
    
    // MARK: - 属性
    private let configManager = ConfigManager.shared
    private var saveCallback: (() -> Void)?
    
    // MARK: - 初始化
    init(saveCallback: (() -> Void)? = nil) {
        self.saveCallback = saveCallback
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - 生命周期
    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 280))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        loadCurrentConfig()
    }
    
    // MARK: - UI设置
    private func setupUI() {
        view.wantsLayer = true
        
        if let window = view.window {
            window.title = NSLocalizedString("配置搜索服务", comment: "")
            window.titleVisibility = .visible
        }
        
        setupApiKeyUI()
        setupApiUrlUI()
        setupButtons()
        setupGithubLink()
        setupStatusLabel()
    }
    
    private func setupApiKeyUI() {
        apiKeyLabel.translatesAutoresizingMaskIntoConstraints = false
        apiKeyLabel.stringValue = NSLocalizedString("API Key:", comment: "")
        apiKeyLabel.isEditable = false
        apiKeyLabel.isBordered = false
        apiKeyLabel.backgroundColor = .clear
        apiKeyLabel.alignment = .right
        apiKeyLabel.font = NSFont.systemFont(ofSize: 13)
        apiKeyLabel.textColor = NSColor.labelColor
        view.addSubview(apiKeyLabel)
        
        apiKeyTextField.translatesAutoresizingMaskIntoConstraints = false
        apiKeyTextField.placeholderString = NSLocalizedString("输入API密钥", comment: "")
        apiKeyTextField.font = NSFont.systemFont(ofSize: 13)
        apiKeyTextField.bezelStyle = .roundedBezel
        apiKeyTextField.focusRingType = .exterior
        view.addSubview(apiKeyTextField)
        
        NSLayoutConstraint.activate([
            apiKeyLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 30),
            apiKeyLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            apiKeyLabel.widthAnchor.constraint(equalToConstant: 80),
            apiKeyLabel.heightAnchor.constraint(equalToConstant: 24),
            
            apiKeyTextField.topAnchor.constraint(equalTo: apiKeyLabel.topAnchor),
            apiKeyTextField.leadingAnchor.constraint(equalTo: apiKeyLabel.trailingAnchor, constant: 10),
            apiKeyTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            apiKeyTextField.heightAnchor.constraint(equalToConstant: 24)
        ])
    }
    
    private func setupApiUrlUI() {
        apiUrlLabel.translatesAutoresizingMaskIntoConstraints = false
        apiUrlLabel.stringValue = NSLocalizedString("API URL:", comment: "")
        apiUrlLabel.isEditable = false
        apiUrlLabel.isBordered = false
        apiUrlLabel.backgroundColor = .clear
        apiUrlLabel.alignment = .right
        apiUrlLabel.font = NSFont.systemFont(ofSize: 13)
        apiUrlLabel.textColor = NSColor.labelColor
        view.addSubview(apiUrlLabel)
        
        apiUrlTextField.translatesAutoresizingMaskIntoConstraints = false
        apiUrlTextField.placeholderString = NSLocalizedString("输入API地址", comment: "")
        apiUrlTextField.font = NSFont.systemFont(ofSize: 13)
        apiUrlTextField.bezelStyle = .roundedBezel
        apiUrlTextField.focusRingType = .exterior
        view.addSubview(apiUrlTextField)
        
        NSLayoutConstraint.activate([
            apiUrlLabel.topAnchor.constraint(equalTo: apiKeyLabel.bottomAnchor, constant: 20),
            apiUrlLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            apiUrlLabel.widthAnchor.constraint(equalToConstant: 80),
            apiUrlLabel.heightAnchor.constraint(equalToConstant: 24),
            
            apiUrlTextField.topAnchor.constraint(equalTo: apiUrlLabel.topAnchor),
            apiUrlTextField.leadingAnchor.constraint(equalTo: apiUrlLabel.trailingAnchor, constant: 10),
            apiUrlTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            apiUrlTextField.heightAnchor.constraint(equalToConstant: 24)
        ])
    }
    
    private func setupButtons() {
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.title = NSLocalizedString("保存", comment: "")
        saveButton.bezelStyle = .rounded
        saveButton.target = self
        saveButton.action = #selector(saveConfig)
        saveButton.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        saveButton.contentTintColor = .white
        saveButton.wantsLayer = true
        
        if #available(macOS 11.0, *) {
            saveButton.bezelColor = NSColor.controlAccentColor
        } else {
            saveButton.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        }
        
        view.addSubview(saveButton)
        
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.title = NSLocalizedString("取消", comment: "")
        cancelButton.bezelStyle = .rounded
        cancelButton.target = self
        cancelButton.action = #selector(cancelConfig)
        cancelButton.font = NSFont.systemFont(ofSize: 13)
        view.addSubview(cancelButton)
        
        NSLayoutConstraint.activate([
            saveButton.topAnchor.constraint(equalTo: apiUrlTextField.bottomAnchor, constant: 30),
            saveButton.trailingAnchor.constraint(equalTo: view.centerXAnchor, constant: -10),
            saveButton.widthAnchor.constraint(equalToConstant: 80),
            saveButton.heightAnchor.constraint(equalToConstant: 28),
            
            cancelButton.topAnchor.constraint(equalTo: saveButton.topAnchor),
            cancelButton.leadingAnchor.constraint(equalTo: view.centerXAnchor, constant: 10),
            cancelButton.widthAnchor.constraint(equalToConstant: 80),
            cancelButton.heightAnchor.constraint(equalToConstant: 28)
        ])
    }
    
    private func setupGithubLink() {
        githubLinkButton.translatesAutoresizingMaskIntoConstraints = false
        githubLinkButton.title = NSLocalizedString("什么是 yt-search-api ？", comment: "")
        githubLinkButton.bezelStyle = .inline
        githubLinkButton.target = self
        githubLinkButton.action = #selector(openGithubLink)
        githubLinkButton.font = NSFont.systemFont(ofSize: 12)
        githubLinkButton.contentTintColor = NSColor.linkColor
        view.addSubview(githubLinkButton)
        
        NSLayoutConstraint.activate([
            githubLinkButton.topAnchor.constraint(equalTo: saveButton.bottomAnchor, constant: 30),
            githubLinkButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            githubLinkButton.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    private func setupStatusLabel() {
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.stringValue = ""
        statusLabel.isEditable = false
        statusLabel.isBordered = false
        statusLabel.backgroundColor = .clear
        statusLabel.alignment = .center
        statusLabel.font = NSFont.systemFont(ofSize: 12)
        statusLabel.textColor = NSColor.secondaryLabelColor
        view.addSubview(statusLabel)
        
        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: githubLinkButton.bottomAnchor, constant: 20),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            statusLabel.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    // MARK: - 功能实现
    private func loadCurrentConfig() {
        apiKeyTextField.stringValue = configManager.apiKey
        apiUrlTextField.stringValue = configManager.apiUrl
    }
    
    @objc private func saveConfig() {
        let apiKey = apiKeyTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        var apiUrl = apiUrlTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 确保URL格式正确
        if !apiUrl.isEmpty && !apiUrl.hasPrefix("http") {
            apiUrl = "https://" + apiUrl
        }
        
        // 验证输入
        if apiKey.isEmpty {
            showStatus(NSLocalizedString("请输入API密钥", comment: ""), isError: true)
            return
        }
        
        if apiUrl.isEmpty {
            showStatus(NSLocalizedString("请输入API地址", comment: ""), isError: true)
            return
        }
        
        // 保存配置
        configManager.saveConfig(apiKey: apiKey, apiUrl: apiUrl)
        showStatus(NSLocalizedString("配置已保存", comment: ""), isError: false)
        
        // 调用回调函数
        saveCallback?()
        
        // 延迟关闭窗口
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.dismiss(nil)
        }
    }
    
    @objc private func cancelConfig() {
        dismiss(nil)
    }
    
    @objc private func openGithubLink() {
        if let url = URL(string: "https://github.com/samzong/yt-search-api") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func showStatus(_ message: String, isError: Bool) {
        statusLabel.stringValue = message
        statusLabel.textColor = isError ? NSColor.systemRed : NSColor.secondaryLabelColor
    }
} 