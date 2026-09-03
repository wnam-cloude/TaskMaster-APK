#!/bin/bash
set -e
cd "$(dirname "$0")"
rm -f unsigned.apk aligned.apk TaskMaster.apk

mkdir -p gen/com/taskmaster/app obj dex

# Generate R.java
aapt package -m -J gen \
  -M app/src/main/AndroidManifest.xml \
  -S app/src/main/res \
  -A app/src/main/assets \
  -I /tmp/platforms/android-11/android.jar \
  --min-sdk-version 21 --target-sdk-version 30 \
  --version-code 1 --version-name 1.0

# Compile Java
javac --release 11 -cp /tmp/platforms/android-11/android.jar:gen -d obj \
  gen/com/taskmaster/app/R.java \
  app/src/main/java/com/taskmaster/app/MainActivity.java

# Convert to DEX
/tmp/build-tools-33.0.2/android-13/d8 --min-api 21 --output dex $(find obj -name "*.class")

# Package APK
aapt package -f \
  -M app/src/main/AndroidManifest.xml \
  -S app/src/main/res \
  -A app/src/main/assets \
  -I /tmp/platforms/android-11/android.jar \
  --min-sdk-version 21 --target-sdk-version 30 \
  --version-code 1 --version-name 1.0 \
  -F unsigned.apk

# Add classes.dex at root
zip -j -g unsigned.apk dex/classes.dex

# Align
zipalign -v 4 unsigned.apk aligned.apk

# Sign (generate keystore if missing)
if [ ! -f taskmaster.jks ]; then
  keytool -genkey -v -keystore taskmaster.jks -keyalg RSA -keysize 2048 -validity 10000 \
    -alias taskmaster -keypass android -storepass android \
    -dname "CN=TaskMaster, OU=Dev, O=TaskMaster, L=Local, S=Local, C=US"
fi

apksigner sign --ks taskmaster.jks --ks-pass pass:android --key-pass pass:android \
  --out TaskMaster.apk aligned.apk

echo "Build complete: TaskMaster.apk"
