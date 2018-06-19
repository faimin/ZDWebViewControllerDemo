
Pod::Spec.new do |s|
  s.name         = "ZDWebViewController"
  s.version      = "0.0.1"
  s.summary      = "ZDWebViewController."
  s.description  = <<-DESC
  A short description of ZDWebViewController，作为内置浏览器使用。
                   DESC
  s.homepage     = "http://10.255.223.213/iOSReaderComponent/WebViewKit"
  s.license      = "MIT"
  s.author       = { "Zero.D.Saber" => "fuxianchao@gmail.com" }
  s.platform     = :ios, "9.0"
  s.source       = { 
    :git => "http://10.255.223.213/iOSReaderComponent/WebViewKit.git", 
    :tag => "#{s.version}" 
  }
  s.source_files  = "ZDWebViewController/*.{h,m}"
  s.framework  = "WebKit"
  s.requires_arc = true

  # s.dependency "ReactiveObjC"
  # s.exclude_files = "Classes/Exclude"
end
