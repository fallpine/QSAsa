//
//  ViewController.swift
//  QSAsa
//
//  Created by MacM2 on 5/13/26.
//

import UIKit

class ViewController: UIViewController {
    private let registerApiUrl = "https://al.asmyapp.com/api/alh/6740202716/reg"
    private let registerApiUrl222 = "https://al.asmyapp.com/api/alh/6740202716/sub"
    let secretKey = "alhNenJDsXYyQUVOxwGB4Sg8cKUdC7sq"
    let iv = "UgyIR0mHd2fYYZHe"
    let sctToken = "FBwFFqartUL0wTQi"

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        configAsaTool()
        setupRegisterButton()
    }
    
    private func configAsaTool() {
        let userId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        
        AsaTool.config(aesSecretKey: secretKey,
                       aesIv: iv,
                       aesSctToken: sctToken,
                       userId: "dev_" + userId,
                       appVersion: appVersion)
        
        
    }
    
    private func setupRegisterButton() {
        var configuration = UIButton.Configuration.filled()
        configuration.title = "Register"
        configuration.cornerStyle = .medium
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 24, bottom: 12, trailing: 24)
        
        let button = UIButton(configuration: configuration)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(registerButtonTapped), for: .touchUpInside)
        view.addSubview(button)
        
        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    @objc private func registerButtonTapped() {
//        AsaTool.register(apiUrl: registerApiUrl, attribution: nil) {
//            debugPrint("register success")
//        }
        
//        AsaTool.uploadASAdAttribution(apiUrl: registerApiUrl) {
//            debugPrint("uploadASAdAttribution success")
//        }
        
        AsaTool.uploadSubscriptionData(apiUrl: registerApiUrl222, purchaseID: "sdfsfdsdfdsfsdf", subscriptionDate: "123456789") {
            debugPrint("uploadSubscriptionData success")
        }
    }
}
