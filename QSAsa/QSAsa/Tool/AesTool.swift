//
//  AesTool.swift
//  QSAsa
//
//  Created by MacM2 on 5/13/26.
//

import CryptoSwift

public class AesTool {
    /// AES 加密方法
    ///
    /// - Parameters:
    ///   - data: 要加密的原始数据
    ///   - key: 加密密钥 (必须是 16 字节, 32 字节, 或 24 字节)
    ///   - iv: 初始化向量 (必须是 16 字节)
    /// - Returns: 加密后的数据
    public static func aesEncrypt(data: Data, key: String, iv: String) -> Data? {
        do {
            let aes = try AES(key: key.bytes, blockMode: CBC(iv: iv.bytes), padding: .pkcs7)
            let encrypted = try aes.encrypt(Array(data))
            return Data(encrypted)
        } catch {
            debugPrint("AES 加密失败: \(error)")
            return nil
        }
    }
    
    /// AES 解密方法
    ///
    /// - Parameters:
    ///   - data: 要解密的加密数据
    ///   - key: 加密密钥
    ///   - iv: 初始化向量
    /// - Returns: 解密后的数据
    public static func aesDecrypt(data: Data, key: String, iv: String) -> Data? {
        do {
            let aes = try AES(key: key.bytes, blockMode: CBC(iv: iv.bytes), padding: .pkcs7)
            let decrypted = try aes.decrypt(Array(data))
            return Data(decrypted)
        } catch {
            debugPrint("AES 解密失败: \(error)")
            return nil
        }
    }
}
