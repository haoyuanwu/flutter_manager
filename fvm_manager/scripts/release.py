#!/usr/bin/env python3
"""Preview a release, or explicitly publish its Chinese commit and Git tag.

Full tests/build/package/upload/download checks run once in GitHub Actions.
Only explicitly staged code changes and generated release metadata are committed.
"""
import argparse
import pathlib
import re
import subprocess
import sys


VERSION = re.compile(r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)\+([1-9]\d*)$')


def git(root, *args, check=True):
    return subprocess.run(['git', '-C', str(root), *args], text=True,
                          encoding='utf-8', errors='replace',
                          capture_output=True, check=check)


def parse_version(value):
    match = VERSION.fullmatch(value)
    if not match:
        raise ValueError('版本号格式须为 X.Y.Z+Build，例如 1.2.8+14')
    return tuple(map(int, match.groups()))


def release(root, version, notes, publish=False):
    wanted = parse_version(version)
    pubspec = root / 'pubspec.yaml'
    source = pubspec.read_text(encoding='utf-8')
    current = re.search(r'^version:\s*(\S+)\s*$', source, re.M)
    if not current:
        raise ValueError('pubspec.yaml 缺少 version')
    previous = parse_version(current.group(1))
    if wanted[:3] <= previous[:3] or wanted[3] <= previous[3]:
        raise ValueError('版本号和 Build No 都必须高于当前版本，禁止覆盖已有 Release')
    if not notes or any(not note.strip() or '\n' in note for note in notes):
        raise ValueError('至少提供一条非空、单行的中文更新说明（--note）')
    if git(root, 'branch', '--show-current').stdout.strip() != 'main':
        raise ValueError('请先合并并切换到 main 分支')
    if git(root, 'diff', '--quiet', check=False).returncode != 0:
        raise ValueError('存在未暂存改动。请先检查并 git add 要发布的文件；脚本不会自动暂存全部文件')
    untracked = git(root, 'ls-files', '--others', '--exclude-standard').stdout.strip()
    if untracked:
        raise ValueError('存在未跟踪文件，请先决定暂存或忽略：\n' + untracked)
    short = version.split('+')[0]
    tag = 'v' + short
    if git(root, 'rev-parse', '--verify', 'refs/tags/' + tag, check=False).returncode == 0:
        raise ValueError('本地标签已存在：' + tag)
    notes_file = root / f'RELEASE_NOTES_{tag}.md'
    if notes_file.exists():
        raise ValueError('更新说明文件已存在，未覆盖：' + str(notes_file))
    body = f'# {tag}\n\n' + ''.join(f'{i}. {note.strip()}\n' for i, note in enumerate(notes, 1))
    body += (f'\n应用版本：{short}（Build {wanted[3]}）。提供 Apple Silicon 和 Intel 两个 DMG。\n'
             '\n安装包使用临时签名，未进行 Apple Developer ID 签名或公证。\n')
    message = f'发布 {tag}：' + notes[0].strip()
    print(f'版本：{current.group(1)} → {version}\n标签与 Release 标题：{tag}\n中文提交：{message}\n\n{body}', flush=True)
    if not publish:
        print('仅预览，未修改文件、提交、打标签或推送。确认后追加 --publish。')
        return

    # Check remote state before touching version files. Push both refs atomically
    # so a failed branch push never leaves a release tag pointing at other code.
    git(root, 'fetch', 'origin', 'main')
    if git(root, 'merge-base', '--is-ancestor', 'FETCH_HEAD', 'HEAD', check=False).returncode != 0:
        raise ValueError('远程 main 有尚未合入的提交，请先同步')
    if git(root, 'ls-remote', '--tags', 'origin', 'refs/tags/' + tag).stdout.strip():
        raise ValueError('远程标签已存在：' + tag)
    pubspec.write_text(source[:current.start(1)] + version + source[current.end(1):], encoding='utf-8')
    notes_file.write_text(body, encoding='utf-8')
    git(root, 'add', '--', str(pubspec), str(notes_file))
    git(root, 'diff', '--cached', '--check')
    git(root, 'commit', '-m', message)
    git(root, 'tag', '-a', tag, '-m', message)
    git(root, 'push', '--atomic', 'origin', 'HEAD:refs/heads/main', 'refs/tags/' + tag)
    print('已推送，GitHub Actions 将完成测试、双架构打包、上传和下载校验。\n'
          '请在 Actions 成功后确认 Release；推送成功不代表发布已完成。', flush=True)


def main():
    # Redirected output on Windows may otherwise use a legacy code page.
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, 'reconfigure'):
            stream.reconfigure(encoding='utf-8', errors='replace')
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('version', help='经确认的新版本号，例如 1.2.8+14')
    parser.add_argument('--note', action='append', required=True, help='一条更新要点，可重复传入；自动编号')
    parser.add_argument('--publish', action='store_true', help='更新版本、中文提交、原子推送 main 和版本标签')
    args = parser.parse_args()
    try:
        release(pathlib.Path(__file__).resolve().parents[1], args.version, args.note, args.publish)
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f'发布已停止：{error}', file=sys.stderr)
        if isinstance(error, subprocess.CalledProcessError):
            print(error.stderr, file=sys.stderr)
        print('若已生成本地提交或标签，请检查 git status / git log / git tag；脚本不会自动回滚或覆盖。', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
