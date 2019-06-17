Pod::Spec.new do |s|
  s.name             = 'HXWebView'
  s.version          = '0.0.2'
  s.summary          = 'wkwebview simple encapsulate'

  s.homepage         = 'https://github.com/yiyucanglang'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'dahuanxiong' => 'xinlixuezyj@163.com' }
  s.source           = { :git => 'https://github.com/yiyucanglang/HXWebView.git', :tag => s.version.to_s }
  s.static_framework = true

  s.ios.deployment_target = '8.0'
  s.public_header_files = '*{h}'
  s.source_files = '*.{h,m}'

  s.dependency 'KVOController'
  s.dependency 'Masonry'
 end
