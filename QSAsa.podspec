Pod::Spec.new do |spec|
  spec.name          = "QSAsa"
  spec.version       = "1.0.0"
  spec.summary       = "注册、归因"
  spec.description   = "注册、归因工具"
  spec.homepage      = "https://github.com/fallpine/QSAsa"
  spec.license       = { :type => "MIT", :file => "LICENSE" }
  spec.author        = { "QiuSongChen" => "791589545@qq.com" }
  spec.platform      = :ios, "16.0"
  spec.source        = { :git => "https://github.com/fallpine/QSAsa.git", :tag => "#{spec.version}" }
  spec.swift_version = "5"
  spec.source_files  = "QSAsa/QSAsa/Tool/*.{swift}"

  spec.dependency "CryptoSwift", "1.10.0"
  spec.dependency "QSJsonParser", "1.0.2"
  spec.dependency "QSIpLocation", "1.0.4"
  spec.dependency "QSNetRequest", "1.0.3"
end
