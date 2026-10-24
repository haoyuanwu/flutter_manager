import pathlib
import unittest
import xml.etree.ElementTree as ET


ROOT = pathlib.Path(__file__).resolve().parents[2]


class WindowsPrivilegesTest(unittest.TestCase):
    def test_application_requires_administrator(self):
        manifest = ET.parse(ROOT / 'windows/runner/runner.exe.manifest')
        level = manifest.find(
            './/{urn:schemas-microsoft-com:asm.v3}requestedExecutionLevel')
        self.assertIsNotNone(level)
        self.assertEqual(level.attrib['level'], 'requireAdministrator')
        self.assertEqual(level.attrib['uiAccess'], 'false')

    def test_installer_launch_preserves_administrator_credentials(self):
        script = (ROOT / 'scripts/package_windows_release.ps1').read_text(
            encoding='utf-8')
        self.assertIn('\nPrivilegesRequired=admin\n', script)
        run_section = script.split('[Run]', 1)[1].split('"@', 1)[0]
        self.assertIn('WorkingDir: "{app}"', run_section)
        flags = run_section.split('Flags:', 1)[1].splitlines()[0].split()
        self.assertTrue({'postinstall', 'shellexec', 'runascurrentuser'} <= set(flags))
        self.assertNotIn('runasoriginaluser', flags)


if __name__ == '__main__':
    unittest.main()
