# iPad Professional Teleprompter（Production Ready）

## 项目目标

开发一款专业级 iPad 提词器。

支持：

- 本地滚动
- 镜像显示
- 局域网控制
- Web 实时改稿
- Bonjour 自动发现
- 蓝牙翻页器
- 外接键盘
- 大文稿支持（10万字以上）
- 后续扩展 OBS 联动
- 后续扩展 iPhone 控制端

技术要求：

- SwiftUI + UIKit 混合架构
- iPadOS 17+
- FlyingFox（第一版）
- Network.framework
- CoreText
- CADisplayLink

---

# 项目开发原则

## 架构原则

采用以下分层架构：

```text
UI Layer
│
├── SwiftUI Views
├── UIKit Renderer
│
Application Layer
│
├── PrompterEngine
├── ScriptManager
├── NetworkManager
│
Infrastructure Layer
│
├── FlyingFox
├── Network.framework
├── CoreText
└── Persistence
```

要求：

- UI 与网络层严格解耦
- 网络层不得直接修改 View
- 所有状态统一由状态中心管理
- 所有功能必须支持后续扩展

---

# Info.plist 配置

必须添加：

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>核心功能需要访问本地网络以允许同局域网设备远程控制提词器。</string>
```

Bonjour Services：

```xml
<key>NSBonjourServices</key>
<array>
    <string>_http._tcp</string>
    <string>_http-alt._tcp</string>
</array>
```

---

# Milestone 1

# 专业滚屏渲染引擎

## 目标

构建商业级提词器核心渲染能力。

渲染架构核心：

采用 GPU 硬件加速模式应对超长文稿：
- 禁止使用 SwiftUI 原生 `ScrollView` 驱动渲染（以避免不受控的更新陷阱）。
- 使用底层封装的 `UIScrollView` 作为承载容器，以 Core Animation 控制位移（GPU 加速丝滑滚动）。
- 承载视图层采用 `CATiledLayer` 实现万字长文的后台线程异步分块光栅化渲染（Tile Render）。
- 严禁使用原生 `Text(scriptContent)` 渲染超过千字的全文。

---

## 目录结构

```text
Core/
├── Engine/
│   ├── PrompterEngine.swift
│   ├── DisplayLinkController.swift
│   └── RenderState.swift
│
├── Renderer/
│   ├── CoreTextRenderer.swift        (纯静态排版与绘制分析引擎)
│   ├── PrompterRenderView.swift      (SwiftUI 到 UIKit 桥接层)
│   ├── PrompterScrollView.swift      (GPU 加速的 UIScrollView 滑动容器)
│   └── PrompterContentView.swift     (CATiledLayer 瓦片渲染画板)
│
└── Model/
    ├── ScriptDocument.swift
    └── Paragraph.swift
```

---

## ScriptDocument

设计：

```swift
struct ScriptDocument {
    let id: UUID
    var title: String
    var rawContent: String
    var paragraphs: [Paragraph]
}
```

---

## RenderState & 高频数据直通通道

统一维护全局状态：

```swift
isPlaying
scrollSpeed
fontSize
scrollProgress
mirrorEnabled
focusLineEnabled
textColor
backgroundColor
```

**性能设计限制 (高频直通代理)**：
对于由 `CADisplayLink` 产生的每秒 60-120 次更新的 `currentOffset`，属于极高频突变数据。
必须**彻底绕过** SwiftUI 的 `@Observable` 系统，利用无锁闭包（如 `onOffsetChange`）把坐标直通传递给底层 `UIScrollView` 的 `contentOffset` 控制器。
同时，`offset` 传递给视图前，必须经过基于 `UIScreen.main.scale` 的**亚像素取整对齐**计算，防止边缘出现抗锯齿抖动！

---

## DisplayLinkController

必须使用：

```swift
CADisplayLink
```

驱动滚动。

算法：

```swift
offset += speed * deltaTime
```

要求：

- 支持 60Hz
- 支持 120Hz ProMotion
- 不允许固定步长滚动

---

## CoreTextRenderer & 瓦片层

必须使用：

```swift
CoreText
```

进行精准排版与文本静帧绘制。

要求与性能指标：

- **禁止 CPU 全量重绘**：废除原先通过逐帧平移 CGContext 并全文画一遍的机制。
- **瓦片渲染 (TiledLayer)**：采用系统级 `CATiledLayer`，在进入屏幕区域时异步光栅化，将文本切分为尺寸合适的碎片进行单次静止绘制。
- 支持 1万字。
- 支持 5万字甚至 10万字超长文稿。
- 保证商业级标准下的满帧（60/120 FPS），**0** 掉帧、**0** 可感知的渲染延迟。

---

## 镜像模式

支持：

```swift
mirrorEnabled
```

实现：

- 水平镜像
- 适配提词器反射玻璃

---

## 焦点线

支持：

```swift
focusLineEnabled
```

显示：

```text
───────────────
```

作为主播视线参考线。

---

## 本地调试界面

提供：

- 播放
- 暂停
- 调速
- 字号
- 镜像
- 焦点线

用于独立测试。

---

## Milestone 1 验收标准

- 真机运行
- 滚动流畅
- 无明显抖动
- 无明显掉帧
- 镜像功能正常
- 焦点线正常显示

---

# Milestone 2

# 文稿系统

## 目标

支持大型文稿管理、本地文件导入、Web 远程上传与热更新。

---

## 目录结构

```text
Core/
├── Script/
│   ├── ScriptManager.swift          (文稿生命周期管理，协调导入/索引/热更/导航)
│   ├── ScriptImporter.swift         (文件读取，后台 I/O 与主 actor 文档构造分离)
│   └── ParagraphIndexer.swift       (O(P) 段落索引，基于预计算字符偏移)

├── Model/
│   ├── ScriptDocument.swift         (文稿模型，全文存储 + 行级段落解析)
│   └── Paragraph.swift              (段落模型，含 characterOffset + markerType)

├── Engine/
│   └── PrompterEngine.swift         (load / hotReload / seek / scrollRange / updateProgress)

└── UI/
    └── ParagraphListView.swift      (标题导航 Sheet，点击跳转)
```

---

## ScriptDocument

```swift
struct ScriptDocument {
    let id: UUID = UUID()
    var title: String
    var rawContent: String
    var paragraphs: [Paragraph]

    var totalCharacterCount: Int { rawContent.count }
}
```

`init(title:content:)` 内部调用 `parseParagraphs(from:)` 按换行符切分全文为段落数组，
同时维护 `runningCharOffset` 计数器为每个段落预计算 `characterOffset`。
后续索引阶段直接读取偏移量，消除 O(P × N) 的重复遍历。

`updateContent(_:)` 用于热更新场景：替换 `rawContent` 并重新解析段落。

---

## Paragraph 模型

```swift
struct Paragraph: Identifiable {
    let id: UUID = UUID()
    let text: String
    let characterRange: Range<String.Index>
    let characterOffset: Int          // 预计算：段落首字符在全文中的偏移
    let markerType: ParagraphMarker   // .heading / .normal
}

enum ParagraphMarker: String, CaseIterable {
    case heading
    case normal
}
```

`classify(_:)` 自动识别 `# `、`## `、`### ` 前缀的 Markdown 标题行，
其余归类为 `normal`。纯 TXT 文稿（无 # 标题）全部段落为 `.normal`。

---

## ScriptImporter

### 导入格式

| 格式 | 扩展名 | 导入路径 |
|------|--------|---------|
| 纯文本 | .txt | 本地文件 / Web 上传 |
| Markdown | .md, .markdown | 本地文件 |
| Word 文档 | .docx | Web 上传（浏览器端解析 → HTTP POST） |

`.doc` 旧格式不支持，Web 控制台提示用户转为 `.docx`。

### 文件导入（本地）

```swift
static func `import`(url: URL) async throws -> ScriptDocument
```

- 文件访问：`startAccessingSecurityScopedResource` / `stopAccessingSecurityScopedResource`
- 后台 I/O：`Task.detached(priority: .userInitiated)` 仅执行 `String(contentsOf:encoding:)`
- 主 actor 构造：`ScriptDocument(title:content:)` 在调用方 actor 上执行，避免跨 actor 传递非 Sendable 的 `Range<String.Index>`
- 错误处理：`ScriptImportError.accessDenied` / `.readFailed` / `.emptyFile`

### 内存导入

```swift
static func `import`(content: String, title: String = "未命名文稿") -> ScriptDocument
```

直接构造 `ScriptDocument`，用于示例文稿加载和 Web 控制台 `POST /upload` 场景。

---

## ScriptManager

```swift
@MainActor
@Observable final class ScriptManager {
    private(set) var currentDocument: ScriptDocument?
    private(set) var paragraphPositions: [ParagraphPosition] = []

    var headingPositions: [ParagraphPosition] {
        ParagraphIndexer.headingPositions(from: paragraphPositions)
    }

    var isEmpty: Bool { currentDocument == nil }
}
```

核心方法一览：

| 方法 | 职责 |
|------|------|
| `loadDocument(from url:) async throws` | 异步导入文件 → 置为 currentDocument |
| `loadDocument(content:title:)` | 内存导入（示例文稿 / Web 上传） |
| `hotReload(newContent:engine:title:)` | 热更新 → 调用 engine.hotReload 保持滚动位置 |
| `progressForParagraph(at:)` | 按段落索引返回 estimatedProgress |
| `progressForHeading(at:)` | 按标题子集索引返回 estimatedProgress |
| `rebuildIndex(fontSize:width:)` | 重建段落位置索引（字号/宽度变化时调用） |

### hotReload 流程

```swift
func hotReload(newContent: String, engine: PrompterEngine, title: String? = nil) {
    guard let doc = currentDocument else {
        // 首次加载：创建新文稿 → engine.load
        let newDoc = ScriptImporter.import(content: newContent)
        currentDocument = newDoc
        engine.load(document: newDoc)
        rebuildIndex(...)
        return
    }
    // 已有文稿：原地更新 → engine.hotReload 保持进度
    var updatedDoc = doc
    updatedDoc.updateContent(newContent)
    updatedDoc.title = title ?? doc.title
    currentDocument = updatedDoc
    engine.hotReload(document: updatedDoc)
    rebuildIndex(...)
}
```

支持两种场景：
- **首次加载**（`currentDocument == nil`）：创建新文稿 → `engine.load`（offset 归零）
- **热更新**（已有文稿）：原地替换内容 → `engine.hotReload`（保持 scrollProgress）

---

## ParagraphIndexer

### 索引算法

```swift
static func index(document: ScriptDocument, fontSize: CGFloat, width: CGFloat) -> [ParagraphPosition]
```

- **复杂度**：O(P)，直接读取 `Paragraph.characterOffset`，无重复遍历
- **进度估算**：`estimatedProgress = characterOffset / totalCharacterCount`（字符数比例）
- **已知限制**：当前使用字符级估算；`fontSize` / `width` 参数已预留接口，待升级为像素级精确定位

### 标题过滤

```swift
static func headingPositions(from positions: [ParagraphPosition]) -> [ParagraphPosition]
```

返回仅含 `.heading` 类型的段落，供导航 Sheet 使用。

### ParagraphPosition

```swift
struct ParagraphPosition: Identifiable {
    let id: Int                     // = paragraphIndex
    let paragraphIndex: Int
    let paragraph: Paragraph
    let estimatedProgress: Double   // 0.0 ~ 1.0

    var displayLabel: String {
        // 去掉 # 前缀的展示文本，normal 类型加缩进
    }
}
```

---

## 文稿上传（Web 远程）

### 浏览器端

Web 控制台支持 `.txt` 和 `.docx` 上传：

- **.txt**：`FileReader.readAsText(file, 'UTF-8')` → HTTP POST `/upload`
- **.docx**：EOCD 方式读取 ZIP 中央目录 → 定位 `word/document.xml` → `DecompressionStream('deflate-raw')` 解压 → 剥离 XML 标签提取纯文本 → HTTP POST

### 服务端

`POST /upload` 路由（[PrompterServerManager.swift]）：

```swift
await srv.appendRoute("/upload", for: [.POST]) { [weak self] request in
    let body = try await request.bodyData
    guard let text = String(data: body, encoding: .utf8) else { ... }
    await MainActor.run {
        self.scriptManager?.hotReload(newContent: text, engine: self.engine!)
    }
    return HTTPResponse(statusCode: .ok)
}
```

使用 HTTP POST 而非 WebSocket 传输大文本，避免 WebSocket 帧丢失问题。

### 为什么不用 WebSocket 传文稿

WebSocket 文本帧在大负载下存在不稳定性（浏览器的 `ws.send()` 可能静默失败、
FlyingFox 帧处理边界、连接断连导致消息丢失）。HTTP POST 有明确的请求-响应语义
和 TCP 级别的可靠传输，更适合文件上传场景。

---

## 滚动进度系统

### 双通道架构

| 通道 | 频率 | 消费者 | 用途 |
|------|------|--------|------|
| `onOffsetChange` 回调 | 每帧 (60/120 Hz) | `PrompterScrollView` | 直接驱动 `UIScrollView.contentOffset`（旁路 SwiftUI） |
| `state.scrollProgress` | 每 10 帧 (~6-12 Hz) | `ControlPanelView` Slider | UI 进度条展示（节流避免 @Observable 无效刷新） |

### scrollRange

进度计算基于 `scrollRange`（而非 `totalContentHeight`），减去一行高度余量，
确保滚动到文稿末尾时最后一行精确停在屏幕顶部：

```swift
private var scrollRange: CGFloat {
    let raw = state.totalContentHeight
    guard raw > 0 else { return 0 }
    let font = UIFont.monospacedSystemFont(ofSize: state.fontSize, weight: .medium)
    let lineH = font.lineHeight + state.fontSize * 0.3
    return max(0, raw - lineH)
}
```

`PrompterScrollView.updateOffset()` 也同步减去了 `cachedLineHeight`，
确保引擎层和视图层的滚动边界一致。

### seek(to:)

```swift
func seek(to progress: Double) {
    let clampedProgress = max(0, min(1, progress))
    state.currentOffset = CGFloat(clampedProgress) * scrollRange
    applyOffsetClamp()
    updateProgress()
    syncOffsetToView()
    notifyStateChange()
}
```

- 本地 Slider 拖拽 + 远程 Web seek 命令均通过此方法
- Slider 拖拽中自动暂停播放（`ControlPanelView.onEditingChanged`），松手恢复

---

## 热更新机制 (engine.hotReload)

### 执行协议

```
记录当前 scrollProgress (0.0 ~ 1.0)
         ↓
替换 ScriptDocument → 重算 totalContentHeight（contentHash 置空）
         ↓
恢复偏移: currentOffset = savedProgress × scrollRange
         ↓
applyOffsetClamp() 边界钳位
         ↓
updateProgress() + syncOffsetToView() + notifyStateChange()
```

### 设计权衡

- 采用**进度比率**（而非段落锚点或内容指纹匹配）进行恢复
- 适用场景：直播中编导微调措辞（字数变化 < 5%），进度比率偏移人眼不可感知
- 已知限制：若在文稿前部大规模增删（如插入/删除整段），恢复后画面位置会产生偏移。此场景在提词器直播流程中极少发生

---

## 段落导航

### UI

右上角悬浮按钮（`list.bullet.rectangle` 图标）→ Sheet 弹出 `ParagraphListView`：

```swift
ParagraphListView(
    headings: scriptManager.headingPositions,
    onSelect: { headingIndex in
        if let progress = scriptManager.progressForHeading(at: headingIndex) {
            engine.seek(to: progress)
        }
    }
)
```

- 每个标题行显示段落文本 + 进度百分比
- 空文稿 / 无标题文稿显示 `ContentUnavailableView` 兜底提示

---

## 本地文件导入 UI

右上角悬浮按钮（`folder.badge.plus` 图标）→ SwiftUI `.fileImporter`：

```swift
.fileImporter(
    isPresented: $showFileImporter,
    allowedContentTypes: [.plainText, .text, UTType(filenameExtension: "md") ?? .text],
    allowsMultipleSelection: false
) { result in handleFileImport(result) }
```

导入成功后：`engine.load(document:)` → 重置 offset → 重建段落索引。

---

## 性能指标

| 指标 | 目标 | 实现 |
|------|------|------|
| 段落解析复杂度 | O(N) | 单次遍历换行符切分 |
| 段落索引复杂度 | < O(N) | O(P) — 预计算 characterOffset |
| 文件 I/O 线程 | 后台执行 | `Task.detached(.userInitiated)` |
| 文档构造线程 | 主 actor | `ScriptDocument` 在调用方 actor 构造 |
| 进度条刷新频率 | 不阻塞主线程 | 每 10 帧更新一次 (~6-12 Hz) |
| 大文稿支持 | 10 万字 | 已验证解析路径，无 O(N²) 热点 |
| 热更新恢复精度 | < 1% 偏差 | 进度比率恢复 + scrollRange 钳位 |
| Web 上传 | 可靠传输 | HTTP POST，绕过 WebSocket 帧大小限制 |

---

## Milestone 2 验收标准

- [x] 成功导入 TXT 文件（本地 + Web 上传）
- [x] 成功导入 Markdown 文件（本地）
- [x] 文件导入错误处理（空文件、无权限、读失败）
- [x] 段落索引准确（标题过滤、进度估算）
- [x] 标题列表导航（点击跳转到对应位置）
- [x] 热更新后位置保持（不闪烁、不跳页、不重置）
- [x] 空文稿 / 无标题文稿优雅降级（不崩溃）
- [x] Web 文稿上传（.txt + .docx 解析）
- [x] .doc/.docx 格式区分与错误提示

---

# Milestone 3

# 局域网控制系统

## 目标

实现基于 HTTP + WebSocket 的浏览器远程控制台，支持多客户端同步与文稿上传。

---

## FlyingFox 依赖

通过 SPM 引入：

```
https://github.com/swhitty/FlyingFox.git (>= 0.17.0)
```

产物依赖：
- `FlyingFox` — HTTP 服务器 + WebSocket 支持
- `FlyingSocks` — 底层 socket 抽象（IPv4 绑定）

项目配置：`XCRemoteSwiftPackageReference` + `XCSwiftPackageProductDependency` 写入 `project.pbxproj`。

---

## 目录结构

```text
Network/
├── PrompterServerManager.swift   (HTTP/WS 服务生命周期、路由、命令分发、权限触发)
├── WebSocketManager.swift        (ControlCommand 枚举、MessageReceiver、WebSocketBroadcaster、
│                                   PerConnectionHandler、CommandParser)
├── ClientManager.swift           (ClientInfo 模型 — 含 lastSeenAt 心跳时间戳)
└── LocalIPAddress.swift          (本地 IP 地址获取)

WebConsole/
├── index.html                   (Material Design 3 控制台界面)
├── app.js                       (WebSocket 客户端、心跳、文件上传、.docx 解析)
└── style.css                    (Material Design 3 样式系统)
```

---

## HTTP 服务

### 启动

```swift
// PrompterServerManager.start()
let srv = HTTPServer(address: sockaddr_in.inet(port: 8080))
```

必须显式绑定 `sockaddr_in.inet`（IPv4 `0.0.0.0`）。默认 `HTTPServer(port:)` 绑定 IPv6 `::`，
iOS 上 `IPV6_V6ONLY` 会导致 IPv4 客户端无法连接。

### 静态文件路由

| 路由 | 文件 | MIME |
|------|------|------|
| `/` | index.html | text/html |
| `/app.js` | app.js | application/javascript |
| `/style.css` | style.css | text/css |

文件通过 `Bundle.main.url(forResource:withExtension:)` 从 app bundle 根目录加载。
路由闭包捕获预加载的 `HTTPResponse` 对象（而非每次请求重读文件），避免跨 actor 调用
`@MainActor` 的 `fileResponse` 函数。

### IPv4 监听验证

启动日志：
```
starting server port: 8080
```

客户端通过 `http://<iPad IP>:8080` 访问。

---

## iOS 本地网络权限

### 权限声明 (Info.plist)

```
INFOPLIST_KEY_NSLocalNetworkUsageDescription = "核心功能需要访问本地网络..."
INFOPLIST_KEY_NSBonjourServices = (_http._tcp)
```

### 权限触发

iOS 14+ 要求在 app 实际调用网络 API 时才弹出权限弹窗。`triggerNetworkPermission()` 使用组合策略：

1. **`NWListener`**（端口 0，含 `newConnectionHandler`）— 绑定 TCP socket，直接触发系统权限检测
2. **`NWConnection`** → `224.0.0.251:5353`（mDNS 组播）— 主动出站连接作为备用触发
3. **`NetService.publish()`** — Bonjour 广播（辅助）

`NWBrowser` 不可用于权限触发：它本身需要权限才能工作（`DNSServiceBrowse failed: NoAuth(-65555)`），形成死锁。

---

## WebSocket 服务

### 路由

```
/ws
```

### 架构

```
客户端 A ──┐
客户端 B ──┼── FlyingFox WebSocket ──► PerConnectionHandler (每连接一个实例)
客户端 C ──┘                              │
                                    ┌─────┴─────┐
                                    │ MessageReceiver (actor)
                                    │   → CommandParser.parse()
                                    │   → PrompterServerManager.handleCommand()
                                    │
                                    │ WebSocketBroadcaster (actor)
                                    │   → broadcast() 到所有客户端
                                    └───────────┘
```

### PerConnectionHandler

```swift
final class PerConnectionHandler: WSMessageHandler, Sendable {
    func makeMessages(for client: AsyncStream<WSMessage>) async throws -> AsyncStream<WSMessage> {
        let (id, outgoing) = await broadcaster.register()
        Task {
            for await message in client {
                await broadcaster.touchClient(id: id)  // 刷新心跳时间戳
                if !text.contains("\"ping\"") {
                    await receiver.receive(text)         // 非 ping 消息分发
                }
            }
            await broadcaster.unregister(id: id)         // 连接关闭 → 清理
        }
        return outgoing
    }
}
```

### WebSocketBroadcaster（多客户端广播器）

- `register()` → 分配 UUID，创建 `AsyncStream<WSMessage>` 对，加入 `continuations` 和 `clients` 字典
- `unregister(id:)` → finish continuation，移除字典条目，通知计数变化
- `broadcast(_:)` → 遍历所有 continuation 发送消息
- `touchClient(id:)` → 更新 `ClientInfo.lastSeenAt`

---

## 心跳与客户端计数

### 问题

页面刷新导致旧 WebSocket 未及时关闭，新旧连接短暂共存，客户端计数虚高。
TCP 连接静默断开时服务端无法感知，"已连接"指示长期误报。

### 算法

```
客户端 (浏览器)                          服务端 (WebSocketBroadcaster)
──────────────                         ─────────────────────────────
┌─ 每 5 秒 ─┐                         startHeartbeat():
│ send({     │                          每 5 秒扫描 clients 字典
│  action:   │    ──── ping ────►        now - lastSeenAt > 10s ?
│  'ping'    │                               → unregister(id)
│ })         │                          (超时客户端强制清理)
└────────────┘

┌─ 每 1 秒 ─┐
│ 检查距上次  │   ◄── state broadcast ── (服务端每 30 帧广播状态)
│ 收到消息 > 8s? │
│   → ws.close() │                      每条消息到达 →
│   → reconnect  │                          touchClient(id)
└────────────┘                              lastSeenAt = .now

beforeunload / pagehide:
  ws.close()                              stream 结束 →
                                            unregister(id)
```

### 关键参数

| 参数 | 值 | 位置 |
|------|-----|------|
| 客户端 ping 间隔 | 5 秒 | `app.js` `PING_INTERVAL_MS` |
| 客户端死连检测 | 8 秒无消息 | `app.js` `STALE_TIMEOUT_MS` |
| 服务端清理周期 | 5 秒 | `WebSocketBroadcaster.cleanupInterval` |
| 服务端超时阈值 | 10 秒 | `WebSocketBroadcaster.staleTimeout` |
| 页面卸载清理 | beforeunload + pagehide | `app.js` `disconnect()` |

---

## 控制协议

基于 JSON，通过 WebSocket 文本帧发送。

### 命令一览

| action | value 类型 | 说明 |
|--------|-----------|------|
| `play` | — | 开始播放 |
| `pause` | — | 暂停播放 |
| `speed` | Double | 滚动速度 (1–200) |
| `fontSize` | Double | 字号 (16–160) |
| `seek` | Double | 跳转进度 (0.0–1.0) |
| `mirror` | — | 切换镜像 |
| `focusLine` | — | 切换焦点线 |
| `scrollDirection` | — | 切换滚动方向 (up/down) |
| `updateText` | String | 更新文稿内容 |
| `ping` | — | 心跳（仅刷新 lastSeenAt，不分发） |

### 示例

```json
{ "action": "play" }
{ "action": "speed", "value": 45 }
{ "action": "seek", "value": 0.5 }
{ "action": "updateText", "value": "新的提词内容..." }
```

### 命令解析流程

```
WebSocket 文本帧
  → PerConnectionHandler: touchClient + 非 ping 消息转发
  → MessageReceiver.receive(text) (actor)
  → PrompterServerManager 的 @MainActor handler
  → CommandParser.parse(from:) → ControlCommand 枚举
  → handleCommand(_:)
      ├─ .play / .pause → engine.play() / engine.pause()
      ├─ .speed / .fontSize → engine.updateSpeed / updateFontSize
      ├─ .seek → engine.seek(to:)
      ├─ .mirror / .focusLine → engine.state 直接 toggle
      ├─ .scrollDirection → engine.state.scrollDirection toggle
      └─ .updateText → scriptManager.hotReload + contentDirty = true
```

---

## 状态广播

### 广播时机

- **周期性广播**：`PrompterEngine.handleTick` 中每 30 帧 (`broadcastInterval = 30`) 调用 `notifyStateChange()`
- **即时广播**：本地/远程 `play`、`pause`、`seek`、`speed`、`fontSize`、`mirror` 等操作后立即 `notifyStateChange()`

### StateSnapshot

```swift
struct StateSnapshot: Codable {
    let isPlaying: Bool
    let scrollSpeed: Double
    let fontSize: Double
    let scrollProgress: Double
    let mirrorEnabled: Bool
    let focusLineEnabled: Bool
    let scrollDirection: String      // "up" / "down"
    let content: String              // 全文（仅 contentDirty 时发送正文，否则置空）
    var clientCount: Int             // 在线客户端数量（注入）
}
```

### 节流策略

| 数据 | 更新频率 | 原因 |
|------|---------|------|
| `currentOffset` → `scrollView.contentOffset` | 每帧 (60/120 Hz) | 走 `onOffsetChange` 闭包旁路 @Observable |
| `scrollProgress` → Slider | 每 10 帧 (~6-12 Hz) | `progressUpdateInterval = 10`，避免 @Observable 无效刷新 |
| `StateSnapshot` → WebSocket 广播 | 每 30 帧 + 即时 | `broadcastInterval = 30`，减少 WebSocket 负载 |
| 文稿正文 (content) | 仅在 `contentDirty = true` 时 | 避免每次广播都携带大段文本 |

---

## Web 控制台

### UI 设计

Material Design 3 设计语言：
- 深色主题 (`#121212` 背景 + `#2a2a2a` 卡片)
- 色彩系统：`--md-primary-container` (紫调 `#4f378b`)、`--md-on-surface`、`--md-outline-variant`
- 组件：md-card（圆角 16px + elevation 阴影）、md-button（胶囊形）、md-chip（toggle 组件）、md-icon-btn（圆形图标按钮）
- 排版：Roboto / system font 栈，14px body / 12px caption

### 功能模块

| 模块 | 控件 | 说明 |
|------|------|------|
| 状态栏 | 连接指示点 + 设备在线数 | 绿点(已连接)/红点(未连接)，心跳检测驱动 |
| 播放控制 | 播放/暂停按钮 | 图标自动切换 ▶ ↔ ⏸，文字同步 |
| 速度 | − / + 按钮 | 步长 5，范围 1–200 |
| 字号 | − / + 按钮 | 步长 2，范围 20–120 |
| 进度 | Slider (range input) | 拖拽即 seek，拖拽时自动暂停、松手恢复 |
| 镜像/焦点线 | Chip 切换按钮 | active 态填充色 |
| 文稿上传 | 文件选择按钮 | 支持 .txt（UTF-8 直接读取）和 .docx（ZIP 解压 → word/document.xml → 剥离 XML 提取纯文本） |

### 文件上传实现

1. `<input type="file" accept=".txt,.docx,...">` 选择文件
2. `.txt`：`FileReader.readAsText(file, 'UTF-8')`
3. `.docx`：`file.arrayBuffer()` → 扫描 ZIP local file headers → 定位 `word/document.xml` → `DecompressionStream('deflate')` 解压 → 剥离 XML/HTML 实体解码 → 提取纯文本
4. 文本通过 `{ action: 'updateText', value: text }` 发送

---

## 双通道滚动同步

本地 DisplayLink 滚动与远程 Slider seek 通过共享 `PrompterEngine.state` 同步：

| 操作来源 | 数据流 |
|---------|--------|
| 本地 DisplayLink | `handleTick` → `state.currentOffset` → `onOffsetChange` → `UIScrollView.contentOffset` |
| 本地 Slider 拖拽 | `engine.seek(to:)` → `state.currentOffset` → `syncOffsetToView()` |
| 远程 seek 命令 | WebSocket → `handleCommand(.seek)` → `engine.seek(to:)` |
| 远程速度/字号 | WebSocket → `handleCommand` → `engine.updateSpeed/updateFontSize` |
| 远程文稿更新 | WebSocket → `handleCommand(.updateText)` → `scriptManager.hotReload` |

---

## 多客户端同步

- 所有连接的客户端共享同一个 `WebSocketBroadcaster`
- 任一客户端发送命令 → 服务端执行 → `notifyStateChange()` → `broadcastSnapshot()` → 所有客户端收到最新状态
- 客户端断开 → `unregister` → `clientCount` 更新 → 广播通知剩余客户端
- 服务端 10 秒心跳超时 → 强制清理僵尸客户端 → 广播 `clientCount` 更新

---

## Milestone 3 验收标准

- [x] 浏览器可访问 HTTP 控制台 (Material Design 3 UI)
- [x] WebSocket 正常连接 (心跳保活)
- [x] 播放/暂停正常 (按钮图标联动)
- [x] 调速正常 (步进 ±5)
- [x] 字号正常 (步进 ±2)
- [x] 进度条 seek 正常 (拖拽暂停/松手恢复)
- [x] 镜像/焦点线切换正常 (实时刷新)
- [x] 滚动方向切换正常 (远程同步)
- [x] 文稿上传正常 (.txt + .docx 解析)
- [x] 多客户端同步正常 (状态广播)
- [x] 客户端计数准确 (心跳算法去重)
- [x] 连接状态真实 (客户端 + 服务端双重心跳检测)
- [x] 本地网络权限弹窗正常 (NWListener 触发)
- [x] IPv4/IPv6 双栈兼容 (显式 sockaddr_in.inet 绑定)

---

# Milestone 4

# Bonjour 自动发现

## 目标

免输 IP。

---

## 实现

使用：

```swift
NetService
```

或：

```swift
NWListener
```

发布：

```text
MyTeleprompter.local
```

---

## 用户访问

```text
http://MyTeleprompter.local:8080
```

即可连接。

---

## Milestone 4 验收标准

- 自动发现成功
- 无需输入 IP
- 同局域网直接访问

---

# Milestone 5

# 外设控制

## 目标

兼容市面主流翻页器。

---

## 支持按键

播放暂停：

```text
Space
```

---

## 调速

```text
ArrowUp
ArrowDown
```

---

## 段落跳转

```text
PageUp
PageDown
```

---

## 蓝牙翻页器

兼容：

```text
Volume+
Volume-
```

---

## 按键映射系统

设计：

```swift
KeyMapping
```

支持：

```json
{
  "VolumeUp":"speedUp",
  "VolumeDown":"speedDown"
}
```

用户自定义配置。

---

## Milestone 5 验收标准

- 外接键盘正常
- 蓝牙翻页器正常
- 支持自定义映射

---

# Milestone 6

# 生命周期与稳定性

## 后台处理

进入后台：

```swift
暂停 DisplayLink
```

恢复前台：

```swift
恢复 DisplayLink
```

---

## 网络异常

WiFi 断开：

```text
关闭 HTTP
关闭 WebSocket
```

WiFi 恢复：

```text
自动重连
自动恢复服务
```

---

## 内存检查

重点检查：

```swift
CADisplayLink
```

以及：

```swift
WebSocket
```

避免：

- 循环引用
- 内存泄漏
- Zombie 对象

---

## Milestone 6 验收标准

- 多次切后台正常
- 网络断开恢复正常
- 无明显内存增长
- 无崩溃

---

# Milestone 7

# 商业化扩展能力

## OBS 联动

预留：

```text
OBS WebSocket
```

接口。

---

## iPhone 控制端

预留：

```text
Native Remote Controller
```

架构。

---

## 云同步

预留：

```text
iCloud
```

同步能力。

---

## 远程控制

预留：

```text
Cloud Relay
```

架构。

---

## 多设备同步

支持未来扩展：

```text
iPad
Mac
iPhone
```

统一文稿。

---

# AI 编码要求（必须遵守）

## 通用要求

1. 优先生成可运行代码。
2. 不允许伪代码。
3. 不允许省略关键实现。
4. 所有代码必须可编译。
5. 所有新增文件必须给出完整内容。
6. 所有目录结构必须明确列出。
7. 所有代码遵循 Swift 6 规范。
8. 所有异步逻辑使用 async/await。

---

## 架构要求

1. 网络层与 UI 层严格分离。
2. WebSocket 不允许写入 View。
3. HTTP 服务不允许写入 View。
4. Renderer 不允许依赖网络层。
5. 状态统一管理。

---

## 性能要求

1. 不允许使用 Timer 替代 CADisplayLink。
2. 不允许使用巨大 Text 渲染超长文稿。
3. 必须考虑 120Hz ProMotion。
4. 必须支持 10万字以上文稿。
5. 必须避免频繁 SwiftUI 全局重绘。

---

## 开发流程要求

每完成一个 Milestone：

1. 编译检查
2. 架构检查
3. 内存检查
4. 性能检查
5. 代码审查

全部通过后再进入下一阶段。

禁止跨阶段实现功能。
优先保证当前阶段稳定可运行。