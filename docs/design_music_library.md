# MacMusicPlayer 多音乐库功能设计文档

## 1. 功能概述

当前 MacMusicPlayer 仅支持从单一文件夹加载音乐文件，不支持管理多个音乐库和播放列表。本设计旨在扩展应用功能，使其支持：

- 添加、删除和管理多个音乐库
- 在不同音乐库之间快速切换
- 为每个音乐库创建自定义名称

## 2. 设计方案

### 2.1 核心组件扩展

#### 新增模型：MusicLibrary

创建一个新的模型来表示音乐库：

```swift
struct MusicLibrary: Identifiable, Codable {
    let id: UUID
    var name: String
    var path: String
    var createdAt: Date
    var lastAccessed: Date
}
```

#### LibraryManager

新增一个管理器组件负责音乐库管理：

```swift
class LibraryManager: ObservableObject {
    @Published var libraries: [MusicLibrary]
    @Published var currentLibrary: MusicLibrary?

    func addLibrary(name: String, path: String)
    func removeLibrary(id: UUID)
    func switchLibrary(id: UUID)
    func saveLibraries()
    func loadLibraries()
}
```

#### 扩展 PlayerManager

扩展 PlayerManager 以支持音乐库切换：

```swift
extension PlayerManager {
    func loadLibrary(_ library: MusicLibrary)
}
```

### 2.2 持久化存储

使用 UserDefaults 或 FileManager 存储音乐库信息：

```swift
private func saveLibraries() {
    do {
        let data = try JSONEncoder().encode(libraries)
        UserDefaults.standard.set(data, forKey: "MusicLibraries")
    } catch {
        print("Failed to save libraries: \(error)")
    }
}

private func loadLibraries() {
    guard let data = UserDefaults.standard.data(forKey: "MusicLibraries") else {
        return
    }

    do {
        libraries = try JSONDecoder().decode([MusicLibrary].self, from: data)
    } catch {
        print("Failed to load libraries: \(error)")
    }
}
```

## 3. UI 变更

### 3.1 菜单栏扩展

扩展应用的状态栏菜单以包含音乐库管理功能：

```swift
// 状态栏菜单更新
private func setupMenu() {
    // 现有菜单项...

    // 添加音乐库管理子菜单
    let libraryMenu = NSMenu()
    let libraryMenuItem = NSMenuItem(title: NSLocalizedString("音乐库", comment: ""), action: nil, keyEquivalent: "")

    // 添加现有音乐库列表
    for library in libraryManager.libraries {
        let item = NSMenuItem(title: library.name, action: #selector(switchLibrary(_:)), keyEquivalent: "")
        item.representedObject = library.id
        item.state = libraryManager.currentLibrary?.id == library.id ? .on : .off
        libraryMenu.addItem(item)
    }

    libraryMenu.addItem(NSMenuItem.separator())
    libraryMenu.addItem(NSMenuItem(title: NSLocalizedString("添加新音乐库", comment: ""), action: #selector(addNewLibrary), keyEquivalent: ""))

    // 只有当存在多个音乐库时才显示删除选项
    if libraryManager.libraries.count > 1 {
        libraryMenu.addItem(NSMenuItem(title: NSLocalizedString("删除当前音乐库", comment: ""), action: #selector(removeCurrentLibrary), keyEquivalent: ""))
    }

    libraryMenu.addItem(NSMenuItem(title: NSLocalizedString("重命名当前音乐库", comment: ""), action: #selector(renameCurrentLibrary), keyEquivalent: ""))

    libraryMenuItem.submenu = libraryMenu
    menu.addItem(libraryMenuItem)

    // 其余菜单项...
}
```

### 3.2 菜单结构变化

下面是菜单栏菜单结构的变化对比：

#### 原有菜单结构

```text
- 当前播放音乐名称
- 播放/暂停
- 上一首
- 下一首
- 播放模式
  - 随机
  - 单曲循环
  - 列表循环
- 均衡器
  - 启用均衡
  - 预设
    - 古典
    - 流行
    - ...
  - 低音
  - 中音
  - 高音
- 选择音乐文件夹
- 下载音乐
- 保持系统唤醒
- 开机启动
- 退出
```

#### 新菜单结构

```text
- 当前播放音乐名称
- 播放/暂停
- 上一首
- 下一首
- 播放模式
  - 随机
  - 单曲循环
  - 列表循环
- 均衡器
  - 启用均衡
  - 预设
    - 古典
    - 流行
    - ...
  - 低音
  - 中音
  - 高音
- **音乐库**
  - 音乐库 1 (√) [当前选中的音乐库会有勾选标记]
  - 音乐库 2
  - 音乐库 3
  - ...
  - --------- [分隔线]
  - 添加新音乐库
  - 删除当前音乐库 [仅当有多个音乐库时显示]
  - 重命名当前音乐库
- 下载音乐
- 保持系统唤醒
- 开机启动
- 退出
```

#### 主要变化

- 将原来的"选择音乐文件夹"菜单项替换为新的"音乐库"子菜单
- "音乐库"子菜单中可以看到所有已添加的音乐库，当前选中的会有勾选标记
- 通过子菜单可以快速切换、添加、删除和重命名音乐库
- 删除选项仅在存在多个音乐库时才会显示

## 4. 实现逻辑

### 4.1 初始化流程

1. 应用启动时，初始化 LibraryManager
2. LibraryManager 加载已保存的音乐库列表
3. 如果没有已保存的音乐库，创建一个默认音乐库
4. 加载最近使用的音乐库

### 4.2 添加新音乐库

1. 用户从菜单中选择"添加新音乐库"
2. 打开文件夹选择对话框
3. 用户选择文件夹并输入库名称
4. 创建新的 MusicLibrary 对象
5. 将新库添加到 LibraryManager 中
6. 保存更新后的库列表

### 4.3 切换音乐库

1. 用户从菜单中选择一个音乐库
2. LibraryManager 更新 currentLibrary 和 lastAccessed 时间
3. PlayerManager 加载新选中的音乐库的音乐文件
4. 系统通知用户切换成功

### 4.4 音乐库管理操作

1. **重命名音乐库**：

   - 用户选择"重命名当前音乐库"
   - 弹出输入对话框
   - 用户输入新名称
   - 更新并保存音乐库信息

2. **删除音乐库**：
   - 用户选择"删除当前音乐库"
   - 弹出确认对话框
   - 用户确认后，从列表中移除当前音乐库
   - 切换到另一个音乐库（如果有）

## 5. 兼容性与迁移

为确保向后兼容性，需要：

1. 迁移现有的单一音乐库

   ```swift
   private func migrateExistingSingleLibrary() {
       if let savedPath = UserDefaults.standard.string(forKey: "MusicFolderPath") {
           let defaultLibrary = MusicLibrary(
               id: UUID(),
               name: NSLocalizedString("我的音乐", comment: ""),
               path: savedPath,
               createdAt: Date(),
               lastAccessed: Date()
           )

           libraries.append(defaultLibrary)
           currentLibrary = defaultLibrary
           saveLibraries()
       }
   }
   ```

2. 保留对单一音乐库行为的支持
   - 如果只有一个音乐库，隐藏删除选项
   - 确保所有现有功能在多库环境中正常工作

## 6. 实现步骤

### 阶段 1: 基础结构实现

1. 创建 MusicLibrary 模型
2. 实现 LibraryManager 基本功能
3. 迁移现有单一音乐库配置

### 阶段 2: UI 集成

1. 扩展状态栏菜单以支持多库管理
2. 实现基本的库管理功能（添加/删除/切换/重命名）

### 阶段 3: 测试与优化

1. 测试多库环境下的所有功能
2. 优化性能，特别是大型音乐库的加载时间
3. 用户体验优化

## 7. 技术挑战与解决方案

### 7.1 性能考虑

对于大型音乐库，可能需要考虑：

- 异步加载音乐库内容
- 实现音乐文件索引和缓存机制
- 延迟加载音频资源

### 7.2 用户体验考虑

- 确保在切换音乐库时有明确的视觉反馈
- 在菜单中清晰显示当前活动的音乐库
- 提供简洁明了的操作流程

## 8. 未来扩展可能性

本设计为以下未来功能奠定基础：

1. 智能播放列表：基于音乐库中的歌曲属性自动生成
2. 跨库播放列表：从多个音乐库中选择歌曲
3. 云同步：将音乐库配置同步到多设备
4. 统计信息：跟踪每个音乐库的使用情况和播放统计

## 9. 结论

多音乐库支持功能将增强 MacMusicPlayer 的用户体验，使用户能够更灵活地组织和享受他们的音乐收藏。通过保持简洁的设计和界面，这一功能可以在不增加复杂性的同时提供更多便利。
