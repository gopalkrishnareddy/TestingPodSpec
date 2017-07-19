
Pod::Spec.new do |s|
    s.name                  = 'JMC'
    s.version               = '1.0.0'
    s.summary               = 'Pod that will contain all JMC classes'
    s.homepage              = "http://pgd-stash.fpl.com:7990/scm/JMC/JMC-ios/browse"
    s.license               = 'NEE'
    s.authors               = 'Andy Newby'
    s.source                = { :git => 'http://pgd-stash.fpl.com:7990/scm/JMC/JMC-ios.git', :tag => 'v1.0.0' }
    s.platform              = :ios
    s.ios.deployment_target = '6.0'
    s.source_files          = 'JMC/JMCClasses/**/*'
    s.prefix_header_file    = 'JMC/JMC-Prefix.pch'
    s.resource_bundles      = {'JMCBundle' => 'JMC/JMCClasses/Libraries/**/*'}
    s.framework             = 'CrashReporter'
    s.pod_target_xcconfig   = {'ENABLE_NS_ASSERTIONS' => 'YES',}
end


