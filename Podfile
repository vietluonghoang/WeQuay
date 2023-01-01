# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'

target 'NightOwlCam' do
  # Comment the next line if you're not using Swift and don't want to use dynamic frameworks
  use_frameworks!

  # Pods for NightOwlCam
pod 'FMDB'
pod 'Google-Mobile-Ads-SDK'

# add the Firebase pod for Google Analytics
pod 'FirebaseAnalytics'
# or pod ‘Firebase/AnalyticsWithoutAdIdSupport’
# for Analytics without IDFA collection capability

# add pods for any other desired Firebase products
# https://firebase.google.com/docs/ios/setup#available-pods

#add the Firebase pod for Google Crashlytics 
pod 'FirebaseCrashlytics'
#when configuring the "New Script" under the "Build Phase" tab, the below script works instead of the one the described on the official instruction on Firebase website
#{}"${PODS_ROOT}/FirebaseCrashlytics/run"
#{}"${PODS_ROOT}/FirebaseCrashlytics/upload-symbols" -gsp "${PROJECT_DIR}/GoogleService-Info.plist" -p ios "${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}"

#add the Firebase pod for Google InAppMessaging
pod 'FirebaseInAppMessaging'
#add the Firebase pod for Google RemoteConfig
pod 'FirebaseRemoteConfig'
#install SwiftyJSON
pod 'SwiftyJSON'

end
