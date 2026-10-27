#!/usr/bin/env python3
"""Build using the persistent private upload key; never creates or rotates a key."""
import hashlib,json,os,pathlib,subprocess
project=pathlib.Path(__file__).resolve().parents[1]
config_path=pathlib.Path(os.environ.get('NEXTBIRTHDAY_SIGNING_CONFIG',str(pathlib.Path.home()/'.local/share/nextbirthday/android-upload/signing.json')))
if not config_path.is_file():raise SystemExit('Missing private upload signing configuration. See android/README.md. Never replace the key for an existing Play app.')
config=json.loads(config_path.read_text());env=dict(os.environ)
for key,var in [('keystore','NEXTBIRTHDAY_UPLOAD_KEYSTORE'),('storePassword','NEXTBIRTHDAY_UPLOAD_STORE_PASSWORD'),('keyPassword','NEXTBIRTHDAY_UPLOAD_KEY_PASSWORD'),('alias','NEXTBIRTHDAY_UPLOAD_KEY_ALIAS')]:env[var]=config[key]
env['NEXTBIRTHDAY_REVIEW_CODE_SHA256']=hashlib.sha256(config['reviewCode'].encode()).hexdigest()
env.setdefault('JAVA_HOME','/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home')
env.setdefault('ANDROID_HOME',str(pathlib.Path.home()/'Library/Android/sdk'))
subprocess.run([str(project/'gradlew'),'-p',str(project),'bundleRelease','assembleRelease','lintRelease'],env=env,check=True)
print('Signed bundle: android/app/build/outputs/bundle/release/app-release.aab')
