import importlib.util
import pathlib
import subprocess
import tempfile
import unittest


spec = importlib.util.spec_from_file_location('release', pathlib.Path(__file__).parents[1] / 'release.py')
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


class ReleaseTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='release-script-test-')
        self.addCleanup(self.temp.cleanup)
        base = pathlib.Path(self.temp.name)
        self.repo = base / 'repo'
        self.repo.mkdir()
        self.root = self.repo / 'fvm_manager'
        self.root.mkdir()
        self.git('init', '-b', 'main')
        self.git('config', 'user.name', 'Release Test')
        self.git('config', 'user.email', 'test@example.invalid')
        (self.root / 'pubspec.yaml').write_text(
            'name: demo\ndescription: 中文项目说明\nversion: 1.2.7+13\n', encoding='utf-8')
        self.git('add', '.')
        self.git('commit', '-m', '初始提交')
        self.remote = base / 'remote.git'
        subprocess.run(['git', 'init', '--bare', str(self.remote)], check=True, capture_output=True)
        self.git('remote', 'add', 'origin', str(self.remote))
        self.git('push', '-u', 'origin', 'main')

    def git(self, *args):
        return release.git(self.repo, *args).stdout.strip()

    def test_preview_never_writes_commits_or_tags(self):
        before = self.git('rev-parse', 'HEAD')
        release.release(self.root, '1.2.8+14', ['新增功能', '优化界面'])
        self.assertEqual(self.git('rev-parse', 'HEAD'), before)
        self.assertEqual(self.git('status', '--porcelain'), '')
        self.assertEqual(self.git('tag'), '')

    def test_publish_uses_chinese_notes_and_atomic_refs(self):
        (self.root / 'feature.dart').write_text('// feature\n', encoding='utf-8')
        self.git('add', 'fvm_manager/feature.dart')
        release.release(self.root, '1.2.8+14', ['新增功能', '优化界面'], publish=True)
        pubspec = (self.root / 'pubspec.yaml').read_text(encoding='utf-8')
        self.assertIn('1.2.8+14', pubspec)
        self.assertIn('description: 中文项目说明', pubspec)
        notes = (self.root / 'RELEASE_NOTES_v1.2.8.md').read_text(encoding='utf-8')
        self.assertIn('1. 新增功能\n2. 优化界面', notes)
        self.assertEqual(self.git('log', '-1', '--format=%s'), '发布 v1.2.8：新增功能')
        self.assertEqual(self.git('status', '--porcelain'), '')
        self.assertEqual(self.git('rev-parse', 'HEAD'), self.git('rev-parse', 'v1.2.8^{}'))
        refs = self.git('ls-remote', 'origin', 'refs/heads/main', 'refs/tags/v1.2.8^{}')
        self.assertEqual(len(refs.splitlines()), 2)
        self.assertEqual(len({line.split()[0] for line in refs.splitlines()}), 1)

    def test_unstaged_changes_are_never_automatically_added(self):
        (self.root / 'pubspec.yaml').write_text('name: changed\nversion: 1.2.7+13\n', encoding='utf-8')
        with self.assertRaisesRegex(ValueError, '未暂存'):
            release.release(self.root, '1.2.8+14', ['修复'])

    def test_untracked_files_require_explicit_choice(self):
        (self.root / 'unknown.txt').write_text('untracked', encoding='utf-8')
        with self.assertRaisesRegex(ValueError, '未跟踪'):
            release.release(self.root, '1.2.8+14', ['修复'])

    def test_version_and_build_must_both_increase(self):
        for version in ['1.2.7+14', '1.2.6+14', '1.2.8+13', '1.2.8', 'v1.2.8+14']:
            with self.subTest(version=version), self.assertRaises(ValueError):
                release.release(self.root, version, ['修复'])

    def test_refuses_existing_tags_and_wrong_branch(self):
        self.git('tag', 'v1.2.8')
        with self.assertRaisesRegex(ValueError, '标签已存在'):
            release.release(self.root, '1.2.8+14', ['修复'])
        self.git('switch', '-c', 'feature')
        with self.assertRaisesRegex(ValueError, 'main'):
            release.release(self.root, '1.2.9+15', ['修复'])

    def test_remote_tag_collision_is_checked_before_version_write(self):
        self.git('tag', 'v1.2.8')
        self.git('push', 'origin', 'v1.2.8')
        self.git('tag', '-d', 'v1.2.8')
        with self.assertRaisesRegex(ValueError, '远程标签已存在'):
            release.release(self.root, '1.2.8+14', ['修复'], publish=True)
        self.assertEqual(self.git('status', '--porcelain'), '')


if __name__ == '__main__':
    unittest.main()
