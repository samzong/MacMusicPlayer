# MacMusicPlayer

MacMusicPlayer 是一款优雅简洁的 macOS 音乐播放器，以菜单栏应用的形式为您提供流畅的音乐播放体验。它采用 SwiftUI 构建，完美融入 macOS 生态系统，为您带来极致的用户体验。

![应用截图](image.png)

## 📦 安装说明

### 方式一：Homebrew

需要先安装 Homebrew，请参考 [Homebrew 安装指南](https://brew.sh/) 安装 Homebrew。

```bash
brew tap samzong/tap
brew install samzong/tap/mac-music-player
```

### 方式二：下载 DMG

从 [Releases](https://github.com/samzong/MacMusicPlayer/releases) 页面下载最新版本的 `MacMusicPlayer.dmg`。

### ⚠️ 关于安全警告

由于应用未经过 Apple 公证，首次运行时可能会遇到"无法打开"的安全警告。这是 macOS 的安全机制，不代表应用存在安全问题。

**解决方法：**

1. **右键点击应用**，选择"打开"（而不是双击）
2. 在弹出的对话框中，点击"打开"
3. 之后应用将被系统记住，可以正常使用

**通过 Homebrew 安装的用户**：安装脚本会自动处理这个问题，无需额外操作。

**如果仍然无法打开**，请在终端中运行以下命令：
```bash
xattr -dr com.apple.quarantine /Applications/MacMusicPlayer.app
```

## ✨ 核心特性

- 🎵 轻量级菜单栏播放器，随时掌控音乐播放
- 🎨 原生 macOS 风格界面，完美支持明暗主题
- 🌍 多语言支持（简体中文、繁体中文、英语、日语、韩语）
- 🎧 支持 MP3 音频格式播放
- 🔄 多种播放模式（顺序播放、单曲循环、随机播放）
- 📥 支持从在线源下载音乐（YouTube、SoundCloud 等）
- 💾 智能记忆上次音乐文件夹位置
- 🚀 支持开机自启动
- 😴 防止系统休眠功能，确保音乐不间断
- ⌨️ 支持媒体键控制（播放/暂停/上一曲/下一曲）

## 🛠 技术架构

- **框架**: SwiftUI + AppKit
- **音频引擎**: AVFoundation
- **设计模式**: MVVM
- **本地化**: 支持多语言
- **状态管理**: 原生 SwiftUI 状态管理
- **持久化**: UserDefaults
- **系统集成**: 
  - MediaPlayer 框架用于媒体控制
  - ServiceManagement 用于开机启动
  - IOKit 用于休眠管理
- **下载引擎**:
  - yt-dlp 用于在线媒体提取
  - ffmpeg 用于音频转换

## 🚀 使用指南

1. 首次启动时，点击菜单栏图标，选择"选择音乐文件夹"
2. 选择包含 MP3 文件的文件夹
3. 通过菜单栏图标访问以下功能：
   - 播放/暂停
   - 上一曲/下一曲
   - 切换播放模式
   - 从在线源下载音乐
   - 开启/关闭防止系统休眠
   - 设置开机启动
   - 重新选择音乐文件夹

## 🔨 开发指南

### 环境要求

- macOS 13.0+
- Xcode 15.0+
- Swift 5.9+
- 音乐下载功能需要: yt-dlp 和 ffmpeg（可通过 Homebrew 安装）

### 构建步骤

1. 克隆仓库
```bash
git clone https://github.com/samzong/MacMusicPlayer.git
```

2. 打开项目
```bash
cd MacMusicPlayer
open MacMusicPlayer.xcodeproj
```

3. 构建和运行
- 使用 Xcode：Command + R
- 使用命令行：`make build`

### 项目结构

```
MacMusicPlayer/
├── Managers/           # 业务管理器
│   ├── PlayerManager   # 播放控制
│   ├── LaunchManager   # 启动管理
│   ├── SleepManager    # 休眠控制
│   └── DownloadManager # 音乐下载
├── Models/             # 数据模型
├── Views/              # 界面组件
├── Helpers/            # 工具类
└── Resources/          # 资源文件
```

### 本地化支持

项目支持多语言本地化，语言文件位于：
- `MacMusicPlayer/en.lproj/`
- `MacMusicPlayer/zh-Hans.lproj/`
- `MacMusicPlayer/zh-Hant.lproj/`
- `MacMusicPlayer/ja.lproj/`
- `MacMusicPlayer/ko.lproj/`

## 🤝 贡献指南

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 提交 Pull Request

## 📝 开发计划

- [x] 支持从在线源下载音乐
- [ ] 支持更多音频格式（FLAC、WAV、AAC等）
- [ ] 添加音频可视化效果
- [ ] 支持播放列表管理
- [ ] 添加音频均衡器
- [ ] 支持在线音乐服务集成
- [ ] 添加快捷键支持
- [ ] 支持音频格式转换

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情

## 🌟 Star History

[![Star History Chart](https://api.star-history.com/svg?repos=samzong/macmusicplayer&type=Timeline)](https://star-history.com/#samzong/macmusicplayer&Timeline)

## 🙏 鸣谢

感谢所有为这个项目做出贡献的开发者！

---

如有问题或建议，欢迎提交 Issue 或 Pull Request。 