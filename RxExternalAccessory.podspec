Pod::Spec.new do |spec|
  spec.name           = "RxExternalAccessory"
  spec.version        = "0.0.1"
  spec.summary        = "RxSwift extensions for ExternalAccessory framework"
  spec.homepage       = "https://github.com/laxmorek/RxExternalAccessory"
  spec.license        = { :type => "MIT", :file => "LICENSE.md" }
  spec.author         = { "Kamil Harasimowicz" => "kamil.harasimowicz@gmail.com" }
  spec.source         = { :git => "https://github.com/laxmorek/RxExternalAccessory.git", :commit => spec.version.to_s }

  spec.platform       = :ios, "10.0"

  spec.source_files   = "Sources/**/*.swift"

  spec.frameworks     = "ExternalAccessory"
  
  spec.dependency 'RxSwift', '~> 4.0'
end
