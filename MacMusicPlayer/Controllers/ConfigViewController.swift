import Cocoa

class ConfigViewController: NSViewController {

    private let apiUrlLabel = NSTextField()
    private let apiUrlTextField = NSTextField()
    private let apiKeyLabel = NSTextField()
    private let apiKeyTextField = NSTextField()
    private let saveButton = NSButton()
    private let cancelButton = NSButton()
    private let statusLabel = NSTextField()
    private let statusIconView = NSImageView()
    private let songPickerCheckbox = NSButton()
    private let statusStackView = NSStackView()
    private var hideStatusWorkItem: DispatchWorkItem?

    private let configManager = ConfigManager.shared
    private var saveCallback: (() -> Void)?

    init(saveCallback: (() -> Void)? = nil) {
        self.saveCallback = saveCallback
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

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

    private func setupUI() {
        view.wantsLayer = true

        setupApiKeyUI()
        setupApiUrlUI()
        setupSongPickerPreference()
        setupStatusLabel()
        setupFormGrid()
        setupButtons()
    }

    private func setupApiKeyUI() {
        apiKeyLabel.translatesAutoresizingMaskIntoConstraints = false
        apiKeyLabel.stringValue = NSLocalizedString("API Key:", comment: "API Key label")
        apiKeyLabel.isEditable = false
        apiKeyLabel.isBordered = false
        apiKeyLabel.backgroundColor = .clear
        apiKeyLabel.alignment = .right
        apiKeyLabel.font = NSFont.systemFont(ofSize: 13)
        apiKeyLabel.textColor = NSColor.labelColor

        apiKeyTextField.translatesAutoresizingMaskIntoConstraints = false
        apiKeyTextField.placeholderString = NSLocalizedString("Enter API Key", comment: "API Key placeholder")
        apiKeyTextField.font = NSFont.systemFont(ofSize: 13)
        apiKeyTextField.bezelStyle = .roundedBezel
        apiKeyTextField.focusRingType = .exterior
    }

    private func setupApiUrlUI() {
        apiUrlLabel.translatesAutoresizingMaskIntoConstraints = false
        apiUrlLabel.stringValue = NSLocalizedString("API URL:", comment: "API URL label")
        apiUrlLabel.isEditable = false
        apiUrlLabel.isBordered = false
        apiUrlLabel.backgroundColor = .clear
        apiUrlLabel.alignment = .right
        apiUrlLabel.font = NSFont.systemFont(ofSize: 13)
        apiUrlLabel.textColor = NSColor.labelColor

        apiUrlTextField.translatesAutoresizingMaskIntoConstraints = false
        apiUrlTextField.placeholderString = NSLocalizedString("Enter API URL", comment: "API URL placeholder")
        apiUrlTextField.font = NSFont.systemFont(ofSize: 13)
        apiUrlTextField.bezelStyle = .roundedBezel
        apiUrlTextField.focusRingType = .exterior
    }

    private func setupButtons() {
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.title = NSLocalizedString("Save", comment: "Save button")
        saveButton.bezelStyle = .rounded
        saveButton.target = self
        saveButton.action = #selector(saveConfig)
        saveButton.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        saveButton.keyEquivalent = "\r"

        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.title = NSLocalizedString("Reset", comment: "Reset button")
        cancelButton.bezelStyle = .rounded
        cancelButton.target = self
        cancelButton.action = #selector(cancelConfig)
        cancelButton.font = NSFont.systemFont(ofSize: 13)

        let buttonStack = NSStackView(views: [saveButton, cancelButton])
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 12
        buttonStack.alignment = .centerY
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(buttonStack)

        NSLayoutConstraint.activate([
            buttonStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            buttonStack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20)
        ])
    }


    private func setupStatusLabel() {
        statusIconView.translatesAutoresizingMaskIntoConstraints = false
        statusIconView.isHidden = true
        statusIconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        statusIconView.contentTintColor = NSColor.systemGreen
        statusIconView.setContentCompressionResistancePriority(.required, for: .horizontal)
        statusIconView.setContentHuggingPriority(.required, for: .horizontal)

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.stringValue = ""
        statusLabel.isEditable = false
        statusLabel.isBordered = false
        statusLabel.backgroundColor = .clear
        statusLabel.alignment = .left
        statusLabel.font = NSFont.systemFont(ofSize: 12)
        statusLabel.textColor = NSColor.secondaryLabelColor
        statusLabel.isHidden = true
        statusLabel.lineBreakMode = .byWordWrapping

        statusStackView.orientation = .horizontal
        statusStackView.alignment = .centerY
        statusStackView.spacing = 8
        statusStackView.translatesAutoresizingMaskIntoConstraints = false
        statusStackView.addArrangedSubview(statusIconView)
        statusStackView.addArrangedSubview(statusLabel)
        statusStackView.isHidden = true
        statusStackView.alphaValue = 0
    }

    private func setupFormGrid() {
        let grid = NSGridView(views: [
            [apiKeyLabel, apiKeyTextField],
            [apiUrlLabel, apiUrlTextField]
        ])
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.rowSpacing = 12
        grid.columnSpacing = 8
        grid.xPlacement = .leading
        grid.yPlacement = .top

        grid.addRow(with: [NSView(), songPickerCheckbox])
        grid.addRow(with: [NSView(), statusStackView])

        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 0).width = 100
        grid.column(at: 1).xPlacement = .leading
        grid.row(at: 0).yPlacement = .center
        grid.row(at: 1).yPlacement = .center

        view.addSubview(grid)

        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),
            grid.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            grid.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    private func setupSongPickerPreference() {
        songPickerCheckbox.translatesAutoresizingMaskIntoConstraints = false
        songPickerCheckbox.setButtonType(.switch)
        songPickerCheckbox.title = NSLocalizedString("Show song picker on launch", comment: "Checkbox label for showing song picker on launch")
        songPickerCheckbox.font = NSFont.systemFont(ofSize: 13)
    }

    private func loadCurrentConfig() {
        apiKeyTextField.stringValue = configManager.apiKey
        apiUrlTextField.stringValue = configManager.apiUrl
        songPickerCheckbox.state = configManager.showSongPickerOnLaunch ? .on : .off
    }

    @objc private func saveConfig() {
        let apiKey = apiKeyTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        var apiUrl = apiUrlTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let apiKeyChanged = apiKey != configManager.apiKey
        let apiUrlChanged = apiUrl != configManager.apiUrl

        if !apiUrl.isEmpty && !apiUrl.hasPrefix("http") {
            apiUrl = "https://" + apiUrl
        }
        if apiUrlChanged && !apiUrl.isEmpty && URLComponents(string: apiUrl) == nil {
            showStatus(NSLocalizedString("API URL is invalid", comment: "Error message when API URL is invalid"), isError: true)
            return
        }

        if apiKeyChanged && apiKey.isEmpty {
            showStatus(NSLocalizedString("Please enter API Key", comment: "Error message when API Key is empty"), isError: true)
            return
        }

        if apiUrlChanged && apiUrl.isEmpty {
            showStatus(NSLocalizedString("Please enter API URL", comment: "Error message when API URL is empty"), isError: true)
            return
        }

        configManager.saveConfig(apiKey: apiKey, apiUrl: apiUrl, showSongPickerOnLaunch: songPickerCheckbox.state == .on)
        showStatus(NSLocalizedString("Configuration saved", comment: "Success message when configuration is saved"), isError: false)

        saveCallback?()
    }

    @objc private func cancelConfig() {
        configManager.resetConfig()
        loadCurrentConfig()
        showStatus(NSLocalizedString("Reset to defaults", comment: "Success message when configuration is reset"), isError: false)
    }


    private func showStatus(_ message: String, isError: Bool) {
        hideStatusWorkItem?.cancel()

        let textColor: NSColor = isError ? .systemRed : .systemGreen
        statusLabel.stringValue = message
        statusLabel.textColor = textColor
        statusLabel.isHidden = false

        statusIconView.image = NSImage(systemSymbolName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill", accessibilityDescription: nil)
        statusIconView.contentTintColor = textColor
        statusIconView.isHidden = false

        statusStackView.isHidden = false
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            statusStackView.animator().alphaValue = 1
        }

        if !isError {
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.25
                    self.statusStackView.animator().alphaValue = 0
                }, completionHandler: {
                    self.statusStackView.isHidden = true
                    self.hideStatusWorkItem = nil
                })
            }
            hideStatusWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: workItem)
        } else {
            hideStatusWorkItem = nil
        }
    }
}
