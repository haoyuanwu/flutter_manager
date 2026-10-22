import hashlib
import importlib.util
import io
import pathlib
import unittest


spec = importlib.util.spec_from_file_location('verify_release', pathlib.Path(__file__).parents[1] / 'verify_github_release.py')
verifier = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verifier)


class VerifyReleaseTest(unittest.TestCase):
    def setUp(self):
        self.files = {f'Flutter-Manager-1.2.8-{arch}.dmg': arch.encode() for arch in ('arm64', 'x86_64')}
        manifest = ''.join(f'{hashlib.sha256(data).hexdigest()}  {name}\n' for name, data in self.files.items())
        self.files['SHA256SUMS.txt'] = manifest.encode()
        self.metadata = {'name': 'v1.2.8', 'tagName': 'v1.2.8', 'isDraft': False,
                         'url': 'https://example.invalid/release',
                         'assets': [{'name': name, 'url': name} for name in self.files]}

    def verify(self):
        verifier.verify('v1.2.8', self.metadata, fetch=lambda url, **_: io.BytesIO(self.files[url]))

    def test_all_downloads_and_checksums_pass(self):
        self.verify()

    def test_corrupt_download_is_not_success(self):
        self.files['Flutter-Manager-1.2.8-arm64.dmg'] = b'bad download'
        with self.assertRaisesRegex(ValueError, 'checksum mismatch'):
            self.verify()

    def test_wrong_title_is_not_success(self):
        self.metadata['name'] = 'Flutter Manager v1.2.8'
        with self.assertRaisesRegex(ValueError, 'title'):
            self.verify()

    def test_missing_architecture_is_not_success(self):
        self.metadata['assets'].pop(0)
        with self.assertRaisesRegex(ValueError, 'attachments'):
            self.verify()
