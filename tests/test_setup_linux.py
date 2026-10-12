import hashlib
import importlib.util
from pathlib import Path
import subprocess
import tarfile
import tempfile
import unittest
from unittest.mock import patch
import io

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('setup_linux', ROOT / 'scripts/setup_linux.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.home = self.base / 'home'
        self.work = self.base / 'work'
        self.home.mkdir()
        self.work.mkdir()
        self.setup = m.Setup(self.home, self.work)

    def test_architectures_and_unsupported_hosts(self):
        self.assertEqual(m.architecture('Linux', 'x86_64'), 'x86_64')
        self.assertEqual(m.architecture('Linux', 'arm64'), 'aarch64')
        for system, arch in [('Darwin', 'arm64'), ('Linux', 'riscv64')]:
            with self.assertRaises(RuntimeError):
                m.architecture(system, arch)

    def test_config_backups_and_idempotence(self):
        target = self.home / '.config/lazygit/config.yml'
        target.parent.mkdir(parents=True)
        target.write_text('old settings')
        old_zsh = self.home / '.zshenv'
        old_zsh.write_text('old shell')
        self.setup.configs()
        self.assertEqual((self.setup.backup / '.config/lazygit/config.yml').read_text(), 'old settings')
        self.assertEqual((self.setup.backup / '.zshenv').read_text(), 'old shell')
        backups = sorted(self.setup.backup.rglob('*'))
        self.setup.configs()
        self.assertEqual(backups, sorted(self.setup.backup.rglob('*')))
        self.assertTrue((self.home / '.config/zsh/.zshrc').exists())
        self.assertFalse((self.home / '.config/zsh/dot_zshrc').exists())
        self.assertTrue((self.home / '.local/state/zsh').is_dir())
        self.assertTrue((self.home / '.config/kitty').is_dir())

    def test_old_symlink_is_preserved_without_modifying_its_target(self):
        original = self.base / 'original'
        original.write_text('keep this')
        target = self.home / '.zshenv'
        target.symlink_to(original)
        self.setup.copy(ROOT / 'dot_zshenv', target)
        self.assertEqual(original.read_text(), 'keep this')
        self.assertFalse(target.is_symlink())
        self.assertTrue((self.setup.backup / '.zshenv').is_symlink())

    def test_unsafe_archive_is_rejected(self):
        archive = self.work / 'bad.tar.gz'
        with tarfile.open(archive, 'w:gz') as tar:
            entry = tarfile.TarInfo('../escaped')
            entry.size = 4
            tar.addfile(entry, io.BytesIO(b'evil'))
        with self.assertRaises(RuntimeError):
            self.setup.unpack(archive, 'bad')
        self.assertFalse((self.work / 'escaped').exists())

    def test_official_archive_layout_installs_both_yazi_binaries(self):
        archive = self.work / 'yazi.tar.gz'
        with tarfile.open(archive, 'w:gz') as tar:
            for binary in ('yazi', 'ya'):
                content = b'#!/bin/sh\necho version 26.9.1\n'
                entry = tarfile.TarInfo('yazi-build/' + binary)
                entry.mode, entry.size = 0o755, len(content)
                tar.addfile(entry, io.BytesIO(content))
        with patch.object(self.setup, 'download', return_value=archive):
            self.setup.install('yazi', {'url': 'https://example.test/yazi.tar.gz', 'sha256': ''})
        for binary in ('yazi', 'ya'):
            self.assertIn('26.9.1', subprocess.check_output([str(self.setup.bin / binary)], text=True))

    def test_interrupted_neovim_install_can_resume(self):
        archive = self.work / 'nvim-linux-arm64.tar.gz'
        content = b'#!/bin/sh\necho NVIM v0.12.6\n'
        with tarfile.open(archive, 'w:gz') as tar:
            entry = tarfile.TarInfo('nvim-linux-arm64/bin/nvim')
            entry.mode, entry.size = 0o755, len(content)
            tar.addfile(entry, io.BytesIO(content))
        bundle = self.home / '.local/lib/dotfiles/nvim-linux-arm64/bin/nvim'
        bundle.parent.mkdir(parents=True)
        bundle.write_bytes(content)
        bundle.chmod(0o755)
        with patch.object(self.setup, 'download', return_value=archive):
            self.setup.install('nvim', {'url': 'https://example.test/nvim-linux-arm64.tar.gz', 'sha256': ''})
        self.assertEqual((self.setup.bin / 'nvim').resolve(), bundle.resolve())

    def test_digest_mismatch_stops_installation(self):
        def fake_curl(*args, **kwargs):
            Path(args[args.index('-o') + 1]).write_bytes(b'wrong download')
        with patch.object(m, 'run', side_effect=fake_curl):
            with self.assertRaisesRegex(RuntimeError, 'Checksum mismatch'):
                self.setup.download('https://example.test/file', hashlib.sha256(b'expected').hexdigest(), 'file')
        self.assertFalse(self.setup.bin.exists())

    def test_minimum_versions_and_paired_commands(self):
        with patch.object(m, 'version', side_effect=lambda tool: {'nvim': (0, 11, 0), 'node': (18, 19, 1), 'yazi': (26, 9, 1)}.get(tool)):
            self.assertFalse(m.usable('nvim'))
            self.assertFalse(m.usable('node'))
            self.assertFalse(m.usable('yazi'))
        with patch.object(m, 'version', return_value=(24, 0, 0)):
            self.assertTrue(m.usable('node'))


if __name__ == '__main__':
    unittest.main()
