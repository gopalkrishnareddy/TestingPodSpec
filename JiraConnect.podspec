Pod::Spec.new do |s|
  s.name         = "JiraMobileConnect"
  s.version      = "1.0.0"
  s.license      = { :type => 'Apache 2.0', :file => 'LICENSE' }
  s.summary      = "Jira Mobile Connect library"
  s.homepage     = "https://bitbucket.org/atlassian/jiraconnect-ios"
  s.author       = { "Atlassian Software" => "info@atlassian.com" }
  s.source       = { :git => "https://github.com/gopalkrishnareddy/TestingPodSpec.git", :tag => "v#{s.version}" }
  s.platform     = :ios, '5.0'
  s.source_files = 'JIRAConnect/JMCClasses/Base/*.{h,m}', 'JIRAConnect/JMCClasses/Core/**/*.{h,m}'
  s.requires_arc = true
  s.prefix_header_file = "JIRAConnect/JIRAConnect-Prefix.pch"
  s.vendored_frameworks = '**/CrashReporter.framework'

  s.frameworks = 'Foundation', 'UIKit', 'CoreGraphics', 'CFNetwork', 'SystemConfiguration', 'MobileCoreServices', 'CoreGraphics', 'AVFoundation', 'CoreLocation', 'libsqlite3'

end
