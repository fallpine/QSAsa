# QSAsa

QSAsa 是一个用于 iOS App 注册信息上传、Apple Search Ads 归因获取与上传的 Swift 工具库。

## 环境要求

- iOS 16.0+
- Swift 5
- CocoaPods

## 安装

在 `Podfile` 中添加：

```ruby
pod 'QSAsa'
```

然后执行：

```bash
pod install
```

## 使用方法

先在需要使用的文件中导入：

```swift
import QSAsa
```

### 1. 应用启动时配置参数

建议在 `AppDelegate` 的 `application(_:didFinishLaunchingWithOptions:)` 中调用 `config`：

```swift
func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
) -> Bool {
    AsaTool.config(
        aesSecretKey: "your_aes_secret_key",
        aesIv: "your_aes_iv",
        aesSctToken: "your_sct_token",
        userId: "current_user_id",
        appVersion: "1.0.0"
    )

    return true
}
```

参数说明：

- `aesSecretKey`：AES 加密密钥
- `aesIv`：AES 初始化向量
- `aesSctToken`：上传接口请求头中的 `sct` token
- `userId`：当前业务用户 ID
- `appVersion`：当前 App 版本号

### 2. 每次进入前台时注册并上传 ASA 归因

建议在 `SceneDelegate` 的 `sceneWillEnterForeground(_:)` 中调用：

```swift
func sceneWillEnterForeground(_ scene: UIScene) {
    let apiUrl = "https://example.com/your/register/api"

    AsaTool.register(apiUrl: apiUrl, attribution: nil) {
        print("注册信息上传成功")
    }

    AsaTool.uploadASAdAttribution(apiUrl: apiUrl) {
        print("ASA 归因上传成功")
    }
}
```

如果项目没有使用 `SceneDelegate`，也可以在 `AppDelegate` 的 `applicationWillEnterForeground(_:)` 中调用。

## 其他接口

### 获取 ASA 归因数据

```swift
AsaTool.getASAdAttribution { attribution in
    print(attribution ?? [:])
}
```

### 上传订阅数据

```swift
AsaTool.uploadSubscriptionData(
    apiUrl: "https://example.com/your/subscription/api",
    purchaseID: "origin_transaction_id",
    subscriptionDate: "original_purchase_date_ms"
) {
    print("订阅数据上传成功")
}
```

## 注意事项

- 调用 `register`、`uploadASAdAttribution`、`uploadSubscriptionData` 前必须先执行 `config`。
- `register` 和 `uploadASAdAttribution` 内部会记录上传状态，避免重复上传已成功的数据。
- 上传接口成功时需要返回 `code = 0`，否则会按内置重试策略进行重试。

## License

MIT
