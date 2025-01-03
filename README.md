# MacMusicPlayer

MacMusicPlayer 是一个简洁、轻量级的 macOS 音乐播放器，设计为菜单栏应用程序，让您可以轻松控制音乐播放而不打断工作流程。

![alt text](image.png)

## 功能特点

- 🎵 从指定文件夹加载和播放 MP3 文件
- 🔄 记住上次选择的音乐文件夹，无需重复配置
- 🖱️ 通过菜单栏图标快速访问播放控制
- ⏯️ 播放、暂停、上一曲、下一曲功能
- 📂 随时重新配置音乐文件夹
- 🎨 简洁的用户界面，最小化干扰

- 😴 支持防止 Mac 休眠（一键开启）

## 安装

1. 下载最新的 MacMusicPlayer.dmg 文件。
2. 打开 DMG 文件并将 MacMusicPlayer 应用程序拖到应用程序文件夹。
3. 首次运行时，macOS 可能会显示安全警告。请在"系统偏好设置">"安全性与隐私"中允许应用运行。
4. 如果还是报错，请执行 `sudo xattr -r -d com.apple.quarantine /Applications/MacMusicPlayer.app`

## 使用方法

1. 启动 MacMusicPlayer。首次运行时，它会要求您选择音乐文件夹。
2. 选择包含 MP3 文件的文件夹。
3. 应用程序图标将出现在菜单栏中。
4. 点击菜单栏图标访问播放控制和其他选项：
   - 播放/暂停当前曲目
   - 切换到上一曲或下一曲
   - 查看当前播放的曲目信息
   - 重新配置音乐文件夹
   - 退出应用程序

## 注意事项

- MacMusicPlayer 目前仅支持 MP3 格式的音频文件。
- 确保给予应用程序访问您选择的音乐文件夹的权限。

## 反馈与支持

如果您遇到任何问题或有改进建议，请创建一个 issue 或联系开发者。

---

感谢您使用 MacMusicPlayer！希望它能为您的音乐体验带来便利。

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=samzong/macmusicplayer&type=Timeline)](https://star-history.com/#samzong/macmusicplayer&Timeline)
