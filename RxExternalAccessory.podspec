Pod::Spec.new do |spec|
  spec.name           = "RxExternalAccessory"
  spec.version        = "1.0.0"
  spec.summary        = "RxSwift wrapper around ExternalAccessory framework"
  spec.homepage       = "https://github.com/laxmorek/RxExternalAccessory"
  spec.license        = { :type => "MIT", :file => "LICENSE" }
  spec.author         = { "Kamil Harasimowicz" => "kamil.harasimowicz@gmail.com" }
  spec.source         = { :git => "https://github.com/laxmorek/RxExternalAccessory.git", :tag => spec.version.to_s }

  spec.platform       = :ios, "10.0"

  spec.source_files   = "RxExternalAccessory/Sources/**/*.swift"

  spec.frameworks     = "ExternalAccessory"

  spec.dependency 'RxSwift', '~> 5.0'
end
