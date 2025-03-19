# MacMusicPlayer 开发者指南

## 项目概述

MacMusicPlayer 是一款为 macOS 设计的轻量级音乐播放器应用，提供简洁的界面和丰富的功能。应用以菜单栏工具形式存在，便于用户日常使用，同时提供音乐播放、下载和均衡器等功能。

## 架构设计

### 项目结构

```
MacMusicPlayer/
├── AppDelegate.swift            # 应用入口和主要控制
├── MacMusicPlayerApp.swift      # SwiftUI应用入口
├── Info.plist                   # 应用配置信息
├── Assets.xcassets/             # 应用图标和资源
├── Controllers/                 # 控制器层
│   └── DownloadViewController.swift  # 音乐下载控制器
├── Managers/                    # 管理器层
│   ├── DownloadManager.swift    # 下载管理
│   ├── LaunchManager.swift      # 启动管理
│   ├── PlayerManager.swift      # 播放控制管理
│   └── SleepManager.swift       # 睡眠控制管理
├── Models/                      # 数据模型层
│   └── Track.swift              # 音轨模型
├── Resources/                   # 资源文件
│   └── Localization/            # 多语言支持
│       ├── en.lproj/            # 英文
│       ├── zh-Hans.lproj/       # 简体中文
│       ├── zh-Hant.lproj/       # 繁体中文
│       ├── ja.lproj/            # 日文
│       └── ko.lproj/            # 韩文
├── Utilities/                   # 工具类
└── Views/                       # 视图层
    ├── ContentView.swift        # 主内容视图
    ├── ControlOverlay.swift     # 控制覆盖层
    └── CustomTableRowView.swift # 自定义表格行视图
```

## 核心模块详解

### 1. 应用入口 (AppDelegate.swift)

AppDelegate 负责应用的生命周期管理，包括：

- 初始化各个 Manager
- 创建和管理状态栏图标和菜单
- 设置和配置媒体播放控制中心
- 处理用户交互事件

### 2. 播放管理 (PlayerManager.swift)

PlayerManager 是应用的核心，负责音乐播放相关功能：

- 播放列表管理
- 音频播放控制（播放、暂停、上一首、下一首）
- 播放模式控制（顺序播放、单曲循环、随机播放）
- 音频均衡器控制
- 音频效果处理

```swift
// 播放模式枚举
enum PlayMode: String {
    case sequential = "Sequential"  // 顺序播放
    case singleLoop = "Single Loop" // 单曲循环
    case random = "Random"         // 随机播放
}

// 均衡器预设
enum EqualizerPreset: String, CaseIterable {
    case flat = "Flat"
    case classical = "Classical"
    case rock = "Rock"
    case pop = "Pop"
    case jazz = "Jazz"
    case electronic = "Electronic"
    case hiphop = "Hip-Hop"
}
```

### 3. 下载功能 (DownloadManager.swift & DownloadViewController.swift)

提供从网络下载音乐的功能：

- 支持从 YouTube 等网站获取音频
- 基于 yt-dlp 和 ffmpeg 工具
- 支持多种音频格式和质量选择
- 自动下载至音乐库

### 4. 系统集成

#### 睡眠管理 (SleepManager.swift)

- 控制系统睡眠行为
- 播放时可阻止系统睡眠

#### 启动管理 (LaunchManager.swift)

- 控制应用登录启动
- 支持 macOS 13 以上和旧版系统

### 5. 用户界面

- 基于 SwiftUI 和 AppKit 混合架构
- 状态栏图标界面
- 下载窗口界面
- 主内容视图

## 数据模型

### Track 模型

```swift
struct Track: Identifiable {
    let id: UUID
    let title: String
    let artist: String
    let url: URL
}
```

## 功能亮点

1. **状态栏集成**：应用作为菜单栏工具运行，不占用 Dock 空间
2. **音乐播放**：支持常见音频格式，提供基础播放控制
3. **播放模式**：支持顺序播放、单曲循环、随机播放
4. **均衡器**：内置多种均衡器预设，支持低音、中音、高音调节
5. **睡眠控制**：可阻止系统在播放音乐时进入睡眠状态
6. **多语言支持**：支持英文、简体中文、繁体中文、日文和韩文
7. **下载功能**：集成音乐下载器，支持从各种网站下载音频

## 开发指南

### 环境要求

- macOS 10.15+
- Xcode 12.0+
- Swift 5.3+

### 构建项目

1. 克隆仓库

   ```bash
   git clone https://github.com/yourusername/MacMusicPlayer.git
   ```

2. 打开项目

   ```bash
   cd MacMusicPlayer
   open MacMusicPlayer.xcodeproj
   ```

3. 构建和运行项目

### 代码贡献指南

1. **代码风格**

   - 遵循 Swift 标准代码风格
   - 使用 SwiftLint 保证代码质量

2. **结构组织**

   - 遵循 MVVM 架构模式
   - Manager 类负责具体功能逻辑
   - 视图与数据分离

3. **本地化**

   - 所有用户可见字符串应使用 NSLocalizedString
   - 新增功能需添加对应的多语言支持

4. **测试**
   - 添加单元测试确保功能正常
   - 进行 UI 测试验证界面流程

## 依赖项

- **系统框架**：

  - AppKit
  - AVFoundation
  - MediaPlayer
  - SwiftUI
  - ServiceManagement
  - IOKit

- **外部工具**（用于下载功能）：
  - yt-dlp
  - ffmpeg

## 常见问题

1. **下载功能不可用**

   - 确保安装了 yt-dlp 和 ffmpeg
   - 可通过 Homebrew 安装: `brew install yt-dlp ffmpeg`

2. **音乐源设置**

   - 应用首次启动需要设置音乐源文件夹
   - 可通过菜单重新设置音乐源

3. **均衡器设置**
   - 均衡器设置会被保存并在下次启动时应用

## 进阶开发

### 添加新功能

1. 在适当的 Manager 中添加功能逻辑
2. 更新 UI 以支持新功能
3. 添加必要的本地化字符串
4. 确保新功能与现有代码无冲突

### 修改现有功能

1. 充分理解现有代码结构和设计意图
2. 保持原有的架构模式
3. 尽量避免破坏性更改

## 版本历史

请参考项目 Git 提交历史查看详细更新记录。
