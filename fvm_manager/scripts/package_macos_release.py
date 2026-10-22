#!/usr/bin/env python3
"""Package both architectures without altering the original universal app."""
import hashlib
import pathlib
import re
import subprocess
import tempfile


def run(*args):
    return subprocess.check_output(args, text=True).strip()


root = pathlib.Path(__file__).resolve().parents[1]
version = re.search(r'^version:\s*(\S+)', (root / 'pubspec.yaml').read_text(), re.M).group(1)
short_version, build = version.split('+')
app = root / 'build/macos/Build/Products/Release/Flutter Manager.app'
plist = app / 'Contents/Info.plist'
assert run('plutil', '-extract', 'CFBundleShortVersionString', 'raw', '-o', '-', str(plist)) == short_version
assert run('plutil', '-extract', 'CFBundleVersion', 'raw', '-o', '-', str(plist)) == build
output = root / 'build/release'
output.mkdir(parents=True, exist_ok=True)
checksums = []
for arch in ('arm64', 'x86_64'):
    destination = output / f'Flutter-Manager-{short_version}-{arch}.dmg'
    if destination.exists():
        raise FileExistsError(f'Refusing to overwrite {destination}')
    with tempfile.TemporaryDirectory(prefix=f'flutter-manager-{arch}-') as directory:
        staging = pathlib.Path(directory)
        staged_app = staging / app.name
        run('ditto', str(app), str(staged_app))
        for file in staged_app.rglob('*'):
            if not file.is_file() or file.is_symlink():
                continue
            result = subprocess.run(['lipo', '-archs', str(file)], capture_output=True, text=True)
            if result.returncode != 0:
                continue
            architectures = result.stdout.strip().split()
            if arch not in architectures:
                raise RuntimeError(f'{file} missing {arch}: {architectures}')
            if len(architectures) > 1:
                thin = file.with_name(file.name + '.thin')
                run('lipo', str(file), '-thin', arch, '-output', str(thin))
                thin.replace(file)
        # Thinning invalidates existing signatures; sign the completed bundle.
        run('codesign', '--force', '--deep', '--sign', '-', '--entitlements',
            str(root / 'macos/Runner/Release.entitlements'), str(staged_app))
        run('codesign', '--verify', '--deep', '--strict', str(staged_app))
        (staging / 'Applications').symlink_to('/Applications')
        run('hdiutil', 'create', '-volname', f'Flutter Manager {short_version}',
            '-srcfolder', str(staging), '-format', 'UDZO', str(destination))
    run('hdiutil', 'verify', str(destination))
    with destination.open('rb') as file:
        checksum = hashlib.sha256()
        for chunk in iter(lambda: file.read(1024 * 1024), b''):
            checksum.update(chunk)
        digest = checksum.hexdigest()
    checksums.append(f'{digest}  {destination.name}\n')
    print(destination, flush=True)
(output / 'SHA256SUMS.txt').write_text(''.join(checksums))
