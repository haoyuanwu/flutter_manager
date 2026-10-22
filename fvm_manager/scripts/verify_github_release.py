#!/usr/bin/env python3
"""Verify published release metadata, downloads and SHA-256 (CI only)."""
import hashlib
import json
import os
import re
import subprocess
import urllib.request


def verify(tag, metadata, fetch=urllib.request.urlopen):
    if not re.fullmatch(r'v\d+\.\d+\.\d+', tag):
        raise ValueError('Invalid release tag')
    if metadata['name'] != tag or metadata['tagName'] != tag or metadata['isDraft']:
        raise ValueError('Release title, tag or publication state does not match')
    assets = {asset['name']: asset['url'] for asset in metadata['assets']}
    expected = {f'Flutter-Manager-{tag[1:]}-{arch}.dmg' for arch in ('arm64', 'x86_64')}
    if set(assets) != expected | {'SHA256SUMS.txt'}:
        raise ValueError('Release attachments do not match the two expected architectures')
    with fetch(assets['SHA256SUMS.txt'], timeout=60) as response:
        lines = response.read().decode().splitlines()
    checksums = {}
    for line in lines:
        digest, filename = line.split(maxsplit=1)
        if filename in checksums or not re.fullmatch(r'[0-9a-f]{64}', digest):
            raise ValueError('Invalid checksum manifest')
        checksums[filename] = digest
    if set(checksums) != expected:
        raise ValueError('Checksum manifest does not match attachments')
    for filename in sorted(expected):
        checksum = hashlib.sha256()
        with fetch(assets[filename], timeout=60) as response:
            for chunk in iter(lambda: response.read(1024 * 1024), b''):
                checksum.update(chunk)
        if checksum.hexdigest() != checksums[filename]:
            raise ValueError('Downloaded attachment checksum mismatch: ' + filename)
        print('下载及校验通过：' + filename, flush=True)
    print('发布确认：' + metadata['url'], flush=True)


if __name__ == '__main__':
    tag = os.environ['RELEASE_TAG']
    metadata = json.loads(subprocess.check_output(
        ['gh', 'release', 'view', tag, '--json', 'name,tagName,assets,url,isDraft'],
        text=True, encoding='utf-8'))
    verify(tag, metadata)
