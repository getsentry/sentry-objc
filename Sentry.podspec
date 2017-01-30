Pod::Spec.new do |s|
  IOS_DEPLOYMENT_TARGET = '6.0' unless defined? IOS_DEPLOYMENT_TARGET

  s.name         = "Sentry"
  s.version      = "1.2.0"
  s.summary      = "Objective-C client for Sentry"
  s.homepage     = "https://github.com/getsentry/sentry-objc"
  s.license      = { :type => 'Sentry license agreement', :file => 'LICENSE' }
  s.authors      = { "Karl Stenerud" => "kstenerud@gmail.com" }
  s.ios.deployment_target =  IOS_DEPLOYMENT_TARGET
  s.tvos.deployment_target =  '9.0'
  s.watchos.deployment_target =  '2.0'
  s.osx.deployment_target =  '10.8'
  s.source       = { :git => "https://github.com/getsentry/sentry-objc", :tag=>s.version.to_s }
  s.source_files = 'Source/*.{h,m,mm,c}'

  s.dependency 'KSCrash/Installations', '~> 1.15.2'
  s.dependency 'KSCrash/Recording', '~> 1.15.2'

end
