#!/usr/bin/env python3
"""Build the Java-only Godot AAR against the exact export-template library.
Requires JDK 17+, Android SDK platform 35 and Godot export templates installed.
Also installs the matching Android Gradle source template for Godot exports.
"""
import argparse
import json
import shutil
import os
from pathlib import Path
import subprocess
import tempfile
import zipfile

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--templates', type=Path, required=True)
parser.add_argument('--configure-export', action='store_true', help='Configure Android SDK/JDK and debug keystore in Godot editor settings')
args = parser.parse_args()
sdk = Path(os.environ.get('ANDROID_HOME') or os.environ.get('ANDROID_SDK_ROOT') or '')
android_jar = sdk / 'platforms/android-35/android.jar'
if not android_jar.is_file():
    raise SystemExit('Install Android SDK platforms;android-35 first')
source_zip = args.templates / 'android_source.zip'
if not source_zip.is_file():
    raise SystemExit(f'Missing {source_zip}')
build = root / 'android/build'
build.mkdir(parents=True, exist_ok=True)
(build / '.gdignore').touch()
with zipfile.ZipFile(source_zip) as archive:
    archive.extractall(build)
# Godot checks this marker before performing a Gradle export.
(root / 'android/.build_version').write_text(args.templates.name)
wrapper = build / 'gradlew'
if wrapper.exists():
    wrapper.chmod(0o755)
libraries = sorted(build.rglob('*.aar'))
if not libraries:
    raise SystemExit('Android source template contains no Godot AAR')
with tempfile.TemporaryDirectory(prefix='petverse-bt-') as temp:
    temp = Path(temp)
    with zipfile.ZipFile(libraries[0]) as archive:
        (temp / 'godot.jar').write_bytes(archive.read('classes.jar'))
    classes = temp / 'classes'
    classes.mkdir()
    sources = sorted((root / 'android/plugins/petverse_bluetooth/src').rglob('*.java'))
    subprocess.run(['javac', '-source', '17', '-target', '17', '-classpath',
                    os.pathsep.join([str(android_jar), str(temp / 'godot.jar')]),
                    '-d', str(classes), *map(str, sources)], check=True)
    jar = temp / 'classes.jar'
    subprocess.run(['jar', 'cf', str(jar), '-C', str(classes), '.'], check=True)
    output = root / 'addons/petverse_bluetooth/bin/PetVerseBluetooth.aar'
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as archive:
        archive.write(jar, 'classes.jar')
        archive.write(root / 'android/plugins/petverse_bluetooth/AndroidManifest.xml', 'AndroidManifest.xml')
        archive.writestr('R.txt', '')
print(f'Built {output.relative_to(root)}')

if args.configure_export:
    java = Path(os.environ.get('JAVA_HOME') or Path(shutil.which('javac')).resolve().parents[1])
    key = Path.home() / '.android/debug.keystore'
    key.parent.mkdir(parents=True, exist_ok=True)
    if not key.is_file():
        subprocess.run([str(java / 'bin/keytool'), '-genkeypair', '-keystore', str(key),
                        '-storepass', 'android', '-alias', 'androiddebugkey', '-keypass', 'android',
                        '-keyalg', 'RSA', '-keysize', '2048', '-validity', '10000',
                        '-dname', 'CN=Android Debug,O=Android,C=US'], check=True)
    minor = '.'.join(args.templates.name.split('.')[:2])
    config = Path(os.environ.get('XDG_CONFIG_HOME', Path.home() / '.config')) / 'godot'
    config.mkdir(parents=True, exist_ok=True)
    settings = config / f'editor_settings-{minor}.tres'
    options = {'export/android/android_sdk_path': str(sdk.resolve()),
               'export/android/java_sdk_path': str(java.resolve()),
               'export/android/debug_keystore': str(key),
               'export/android/debug_keystore_user': 'androiddebugkey',
               'export/android/debug_keystore_pass': 'android'}
    text = settings.read_text() if settings.exists() else '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
    lines = [line for line in text.splitlines() if line.split(' = ', 1)[0] not in options]
    lines.extend(f'{name} = {json.dumps(value)}' for name, value in options.items())
    settings.write_text('\n'.join(lines) + '\n')
    print('Configured Godot Android export settings')
