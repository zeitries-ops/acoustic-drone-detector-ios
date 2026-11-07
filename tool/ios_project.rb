# iOS Runner hedefini App Store'a hazırlar (setup_platforms.sh çağırır; macOS'ta CocoaPods ile gelen xcodeproj gem'i gerekir).
#  - PrivacyInfo.xcprivacy kaynak olarak eklenir (Apple yüklemede ister)
#  - Runner.entitlements: zamana duyarlı bildirim (SOS uyarısı Odak modlarında da görünsün)
#  - Paket kimliği, ekip, iPhone + iPad, iOS 15+ (Flutter'ın asgari sürümü)
#  - 27 dilde InfoPlist.strings (mikrofon izni metni) ve bilinen bölgeler
#
#   ruby tool/ios_project.rb [paket_kimliği] [ekip_kimliği]
require 'xcodeproj'

bundle_id = ARGV[0].to_s.strip
team_id = ARGV[1].to_s.strip

project = Xcodeproj::Project.open('ios/Runner.xcodeproj')
target = project.targets.find { |t| t.name == 'Runner' } or abort('Runner hedefi yok')
group = project.main_group['Runner'] or abort('Runner grubu yok')

unless group.files.any? { |f| f.path == 'PrivacyInfo.xcprivacy' }
  ref = group.new_reference('PrivacyInfo.xcprivacy')
  target.resources_build_phase.add_file_reference(ref, true)
end
unless group.files.any? { |f| f.path == 'Runner.entitlements' }
  group.new_reference('Runner.entitlements')
end

langs = File.readlines('tool/platform_l10n/ios/languages.txt').map(&:strip).reject(&:empty?)
variant = group.children.find { |c| c.isa == 'PBXVariantGroup' && c.name == 'InfoPlist.strings' } ||
          group.new_variant_group('InfoPlist.strings')
langs.each do |l|
  path = "#{l}.lproj/InfoPlist.strings"
  next if variant.files.any? { |f| f.path == path }
  ref = variant.new_reference(path)
  ref.name = l
  ref.last_known_file_type = 'text.plist.strings'
end
target.resources_build_phase.add_file_reference(variant, true)
project.root_object.known_regions = (project.root_object.known_regions + langs + ['Base']).uniq

target.build_configurations.each do |c|
  s = c.build_settings
  s['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
  s['TARGETED_DEVICE_FAMILY'] = '1,2'
  s['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
  s['PRODUCT_BUNDLE_IDENTIFIER'] = bundle_id unless bundle_id.empty?
  unless team_id.empty?
    s['DEVELOPMENT_TEAM'] = team_id
    s['CODE_SIGN_STYLE'] = 'Automatic'
  end
end
project.save
puts "Runner: gizlilik bildirimi + yetkiler + #{langs.size} dil eklendi#{bundle_id.empty? ? '' : ", kimlik #{bundle_id}"}#{team_id.empty? ? '' : ", ekip #{team_id}"}"
