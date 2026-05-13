//
//  AsaTool.swift
//  QSAsa
//
//  Created by MacM2 on 5/13/26.
//

import UIKit
import AdServices
import QSJsonParser
import QSIpLocation
import QSNetRequest
internal import Alamofire

/// 将 Apple Search Ads attribution token 作为 text/plain 请求体发送的编码器。
private struct PlainTextBodyEncoding: ParameterEncoding {
    /// 需要写入 HTTP body 的纯文本内容。
    let text: String
    
    /// 将纯文本内容写入 URLRequest，并设置 Content-Type 为 text/plain。
    /// - Parameters:
    ///   - urlRequest: Alamofire 传入的原始请求。
    ///   - parameters: 本编码器不使用该参数。
    /// - Returns: 已写入纯文本 body 的 URLRequest。
    func encode(_ urlRequest: any URLRequestConvertible, with parameters: Parameters?) throws -> URLRequest {
        var request = try urlRequest.asURLRequest()
        request.httpBody = text.data(using: .utf8)
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        return request
    }
}

/// ASA 注册、归因上传和订阅数据上传工具。
public class AsaTool {
    // MARK: - key
    /// 标记归因数据是否已成功上传到业务服务器。
    private static let kIsUploadASAdAttribution = "kIsUploadASAdAttribution"
    /// 标记基础注册信息是否已成功上传到业务服务器。
    private static let kIsRegister = "kIsRegister"
    
    /// register 调用任务，统一进入队列，避免多个注册请求并发执行。
    private struct RegisterTask {
        /// 注册接口地址。
        let apiUrl: String
        /// 可选归因数据；为空时表示普通注册，不为空时表示归因注册。
        let attribution: Dictionary<String, Any>?
        /// 注册成功后的回调。
        let success: () -> Void
    }
    
    // MARK: - Func
    /// 配置 ASA 工具上传数据所需的基础参数。
    /// - Parameters:
    ///   - aesSecretKey: AES 加密密钥。
    ///   - aesIv: AES 初始化向量。
    ///   - aesSctToken: 请求头中的 sct token。
    ///   - userId: 当前业务用户 ID。
    ///   - appVersion: 当前 App 版本号。
    public static func config(aesSecretKey: String, aesIv: String, aesSctToken: String, userId: String, appVersion: String) {
        self.aesSecretKey = aesSecretKey
        self.aesIv = aesIv
        self.aesSctToken = aesSctToken
        self.userId = userId
        self.appVersion = appVersion
    }
    
    /// 上传注册数据。
    /// - Parameters:
    ///   - apiUrl: 注册接口地址。
    ///   - attribution: 可选归因数据；为空时上传普通注册数据，不为空时同时上传归因数据。
    ///   - success: 上传成功后的回调。
    public static func register(apiUrl: String, attribution: Dictionary<String, Any>?, success: @escaping (() -> Void)) {
        DispatchQueue.main.async {
            // 串行化 register：只入队，由 consumeNextRegisterTaskIfNeeded 统一消费。
            registerQueue.append(RegisterTask(apiUrl: apiUrl, attribution: attribution, success: success))
            consumeNextRegisterTaskIfNeeded()
        }
    }
    
    /// 在没有注册任务执行时，从 FIFO 队列中取出下一个任务并启动。
    private static func consumeNextRegisterTaskIfNeeded() {
        // 当前已有 register 在执行时，不再启动新的请求。
        guard !isRegisterRunning, !registerQueue.isEmpty else {
            return
        }
        
        isRegisterRunning = true
        let task = registerQueue.removeFirst()
        executeRegister(task)
    }
    
    /// 结束当前注册任务，并尝试继续执行队列中的下一个任务。
    private static func finishRegisterTask() {
        DispatchQueue.main.async {
            // 当前任务结束后释放执行状态，并继续处理队列中的下一个任务。
            isRegisterRunning = false
            consumeNextRegisterTaskIfNeeded()
        }
    }
    
    /// 根据当前重试次数返回对应的延迟秒数。
    /// - Parameter retryCount: 将要执行的重试次数，从 1 开始。
    /// - Returns: 本次重试前需要等待的秒数。
    private static func registerRetryDelay(for retryCount: Int) -> TimeInterval {
        // 重试间隔：1-3 次 3 秒，4-6 次 5 秒，7-10 次 8 秒。
        if retryCount <= 3 {
            return 3
        } else if retryCount <= 6 {
            return 5
        } else {
            return 8
        }
    }
    
    /// 执行单个注册任务，包含参数构建、加密、请求发送和失败重试。
    /// - Parameter task: 从注册队列中取出的待执行任务。
    private static func executeRegister(_ task: RegisterTask) {
        guard let userId = userId,
              let appVersion = appVersion,
        let aesSecretKey = aesSecretKey,
            let aesIv = aesIv,
            let aesSctToken = aesSctToken else {
                debugPrint("请先执行config方法，配置参数")
            finishRegisterTask()
            return
        }
        
        if task.attribution != nil,
           UserDefaults.standard.value(forKey: kIsUploadASAdAttribution) as? Bool ?? false {
            // 排队期间可能已经由前一个任务完成归因上传，这里直接回调并继续队列。
            task.success()
            finishRegisterTask()
            return
        }
        
        if task.attribution == nil,
           UserDefaults.standard.value(forKey: kIsRegister) as? Bool ?? false {
            // 排队期间可能已经由前一个任务完成注册，这里直接回调并继续队列。
            task.success()
            finishRegisterTask()
            return
        }
        
        IpLocation.getIpLocation { ipModel in
            let locale = Locale.current
            let languageCode = locale.language.languageCode?.identifier ?? ""
            let countryCode = locale.region?.identifier.lowercased() ?? ""
            
            let asaToken = try? AAAttribution.attributionToken()
            if asaToken == nil {
                debugPrint("asaToken为空")
            }
            
            var paraDict = [
                "userId": userId,
                "fcmId": "",
                "appVersion": appVersion,
                "deviceType": UIDevice.current.systemName,
                "devicePlatform": getDeviceModel(),
                "deviceOSVersion": UIDevice.current.systemName + " " + UIDevice.current.systemVersion,
                "locale": "\(languageCode)_\(countryCode)",
                "timezone": ipModel?.timezone ?? TimeZone.current.identifier,
                "ipCountry": ipModel?.country ?? "",
                "ipState": ipModel?.regionName ?? "",
                "ipCity": ipModel?.city ?? "",
                "attributionToken": asaToken ?? ""
            ] as [String : Any]
            
            if let attribution = task.attribution {
                paraDict["attribution"] = attribution
            }
            
            guard let jsonStr = JsonParser.objectToString(with: paraDict),
            let jsonData = jsonStr.data(using: .utf8) else {
                debugPrint("参数解析失败")
                finishRegisterTask()
                return
            }
            
            guard let encryptData = AesTool.aesEncrypt(data: jsonData, key: aesSecretKey, iv: aesIv) else {
                debugPrint("参数加密失败")
                finishRegisterTask()
                return
            }
            
            let base64Str = encryptData.base64EncodedString()
            let maxRetryCount = 10
            
            func requestRegister(retryCount: Int) {
                // 只重试最终上传请求，参数构建、IP 获取和加密不重复执行。
                NetRequest.requestJson(urlString: task.apiUrl, methodType: .post, paraDict: ["data": base64Str],
                                       encoding: JSONEncoding.default,
                                       headers: ["sct": aesSctToken]) { response in
                    let dict = response as? Dictionary<String, Any>
                    let code = dict?["code"] as? Int
                    if code == 0 {
                        UserDefaults.standard.set(true, forKey: kIsRegister)
                        if task.attribution != nil {
                            UserDefaults.standard.set(true, forKey: kIsUploadASAdAttribution)
                        }
                        // 普通注册和归因注册成功都回调 success。
                        task.success()
                        finishRegisterTask()
                        return
                    }
                    
                    if retryCount < maxRetryCount {
                        // 服务端返回非 0 也视为失败，按规则延迟后重试。
                        let nextRetryCount = retryCount + 1
                        DispatchQueue.main.asyncAfter(deadline: .now() + registerRetryDelay(for: nextRetryCount)) {
                            requestRegister(retryCount: nextRetryCount)
                        }
                    } else {
                        debugPrint("注册失败，已达到最大重试次数", dict ?? [:])
                        finishRegisterTask()
                    }
                } onError: { error, code in
                    debugPrint(error, code ?? "")
                    
                    if retryCount < maxRetryCount {
                        // 网络错误按同一套规则重试。
                        let nextRetryCount = retryCount + 1
                        DispatchQueue.main.asyncAfter(deadline: .now() + registerRetryDelay(for: nextRetryCount)) {
                            requestRegister(retryCount: nextRetryCount)
                        }
                    } else {
                        debugPrint("注册失败，已达到最大重试次数")
                        finishRegisterTask()
                    }
                }
            }
            
            requestRegister(retryCount: 0)
        }
    }
    
    /// 获取并上传 Apple Search Ads 归因数据。
    /// - Parameters:
    ///   - apiUrl: 注册接口地址。
    ///   - success: 归因数据上传成功后的回调。
    public static func uploadASAdAttribution(apiUrl: String, success: @escaping (() -> Void)) {
        if UserDefaults.standard.value(forKey: kIsUploadASAdAttribution) as? Bool ?? false {
            success()
            return
        }
        getASAdAttribution { datas in
            if let attribution = datas {
                register(apiUrl: apiUrl, attribution: attribution) {
                    success()
                }
            }
        }
    }
    
    /// 获取 Apple Search Ads 归因数据。
    /// - Parameter completion: 获取完成后的回调；失败或没有 token 时返回 nil。
    public static func getASAdAttribution(completion: @escaping ((Dictionary<String, Any>?) -> Void)) {
        if let attribution = asaAttribution {
            completion(attribution)
            return
        }
        let token = try? AAAttribution.attributionToken()
        guard let token = token else { completion(nil); return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NetRequest.requestJson(urlString: "https://api-adservices.apple.com/api/v1/",
                                   methodType: .post,
                                   paraDict: nil,
                                   encoding: PlainTextBodyEncoding(text: token),
                                   headers: nil) { response in
                asaAttribution = response as? Dictionary<String, Any>
                completion(asaAttribution)
            } onError: { error, code in
                debugPrint(error, code ?? "")
                completion(nil)
            }
        }
    }
    
    /// 上传订阅数据。
    /// - Parameters:
    ///   - apiUrl: 订阅数据上传接口地址。
    ///   - purchaseID: 原始交易 ID。
    ///   - subscriptionDate: 原始购买时间戳。
    ///   - success: 订阅数据上传成功后的回调。
    public static func uploadSubscriptionData(apiUrl: String, purchaseID: String, subscriptionDate: String, success: @escaping (() -> Void)) {
        guard let userId = userId,
              let appVersion = appVersion,
        let aesSecretKey = aesSecretKey,
            let aesIv = aesIv,
            let aesSctToken = aesSctToken else {
                debugPrint("请先执行config方法，配置参数")
            return
        }
        
        // 获取归因数据
        getASAdAttribution { datas in
            IpLocation.getIpLocation { ipModel in
                
                let locale = Locale.current
                let languageCode = locale.language.languageCode?.identifier ?? ""
                let countryCode = locale.region?.identifier.lowercased() ?? ""
                
                let asaToken = try? AAAttribution.attributionToken()
                if asaToken == nil {
                    debugPrint("asaToken为空")
                }
                
                var paraDict = [
                    "userId": userId,
                    "originTransactionId": purchaseID,
                    "originalPurchaseDateMs": subscriptionDate,
                    "fcmId": "",
                    "appVersion": appVersion,
                    "deviceType": UIDevice.current.systemName,
                    "devicePlatform": getDeviceModel(),
                    "deviceOSVersion": UIDevice.current.systemName + " " + UIDevice.current.systemVersion,
                    "locale": "\(languageCode)_\(countryCode)",
                    "timezone": ipModel?.timezone ?? TimeZone.current.identifier,
                    "ipCountry": ipModel?.country ?? "",
                    "ipState": ipModel?.regionName ?? "",
                    "ipCity": ipModel?.city ?? "",
                    "attributionToken": asaToken ?? ""
                ] as [String : Any]
                if let attribution = datas {
                    paraDict["attribution"] = attribution
                }
                
                guard let jsonStr = JsonParser.objectToString(with: paraDict),
                let jsonData = jsonStr.data(using: .utf8) else {
                    debugPrint("参数解析失败")
                    return
                }
                
                guard let encryptData = AesTool.aesEncrypt(data: jsonData, key: aesSecretKey, iv: aesIv) else {
                    debugPrint("参数加密失败")
                    return
                }
                
                let base64Str = encryptData.base64EncodedString()
                let maxRetryCount = 10
                
                func retryDelay(for retryCount: Int) -> TimeInterval {
                    // 重试间隔：1-3 次 3 秒，4-6 次 5 秒，7-10 次 8 秒。
                    if retryCount <= 3 {
                        return 3
                    } else if retryCount <= 6 {
                        return 5
                    } else {
                        return 8
                    }
                }
                
                func requestUpload(retryCount: Int) {
                    // 只重试最终上传请求，避免重复获取归因、IP 或重新加密参数。
                    NetRequest.requestJson(urlString: apiUrl, methodType: .post, paraDict: ["data": base64Str],
                                           encoding: JSONEncoding.default,
                                           headers: ["sct": aesSctToken]) { response in
                        let dict = response as? Dictionary<String, Any>
                        let code = dict?["code"] as? Int
                        if code == 0 {
                            success()
                            return
                        }
                        
                        if retryCount < maxRetryCount {
                            // 服务端返回非 0 也视为失败，按规则延迟后重试。
                            let nextRetryCount = retryCount + 1
                            DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay(for: nextRetryCount)) {
                                requestUpload(retryCount: nextRetryCount)
                            }
                        } else {
                            debugPrint("上传订阅数据失败，已达到最大重试次数", dict ?? [:])
                        }
                    } onError: { error, code in
                        debugPrint(error, code ?? "")
                        
                        if retryCount < maxRetryCount {
                            // 网络错误按同一套规则重试。
                            let nextRetryCount = retryCount + 1
                            DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay(for: nextRetryCount)) {
                                requestUpload(retryCount: nextRetryCount)
                            }
                        } else {
                            debugPrint("上传订阅数据失败，已达到最大重试次数")
                        }
                    }
                }
                
                requestUpload(retryCount: 0)
            }
        }
    }
    
    /// 获取当前设备型号标识。
    /// - Returns: 设备型号字符串，例如 iPhone 机型标识。
    private static func getDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let model = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        
        return model
    }
    
    // MARK: - Property
    /// AES 加密密钥。
    private static var aesSecretKey: String?;
    /// AES 初始化向量。
    private static var aesIv: String?;
    /// 上传接口请求头中的 sct token。
    private static var aesSctToken: String?;
    /// 当前业务用户 ID。
    private static var userId: String?
    /// 当前 App 版本号。
    private static var appVersion: String?
    /// 内存缓存的 Apple Search Ads 归因数据。
    private static var asaAttribution: Dictionary<String, Any>?
    /// register FIFO 队列，用于防止并发注册请求。
    private static var registerQueue: [RegisterTask] = []
    /// 标记当前是否已有 register 任务正在执行。
    private static var isRegisterRunning = false
}
