#!/usr/bin/env python3
"""Install Jon's terminal setup in the current Linux user's home directory."""
import argparse
import filecmp
import gzip
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import time
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def run(*args, **kwargs):
    return subprocess.run(args, check=True, **kwargs)


def architecture(system=None, machine=None):
    if (system or platform.system()) != 'Linux':
        raise RuntimeError('This installer is for Linux only.')
    machine = machine or platform.machine()
    aliases = {'x86_64': 'x86_64', 'amd64': 'x86_64', 'aarch64': 'aarch64', 'arm64': 'aarch64'}
    if machine not in aliases:
        raise RuntimeError('Supported architectures: x86_64 and ARM64; found ' + machine)
    return aliases[machine]


def version(tool):
    try:
        result = run(tool, '--version', capture_output=True, text=True)
        match = re.search(r'\b[vV]?(\d+)\.(\d+)(?:\.(\d+))?', result.stdout)
        return tuple(int(n or 0) for n in match.groups()) if match else None
    except (OSError, subprocess.CalledProcessError):
        return None


def usable(tool):
    minimum = {'nvim': (0, 12, 0), 'fzf': (0, 48, 0), 'fd': (10, 0, 0),
               'tree-sitter': (0, 26, 1), 'node': (22, 0, 0)}.get(tool, (0, 0, 0))
    found = version(tool)
    if not found or found < minimum:
        return False
    if tool == 'node':
        return version('npm') is not None and version('npx') is not None
    if tool == 'yazi':
        return version('ya') is not None
    return True


class Setup:
    def __init__(self, home, work):
        self.home = Path(home)
        self.work = Path(work)
        self.bin = self.home / '.local/bin'
        self.backup = self.home / '.local/state/dotfiles/backups' / time.strftime('%Y%m%d-%H%M%S')

    def preserve(self, path):
        path = Path(path)
        if path.exists() or path.is_symlink():
            target = self.backup / path.relative_to(self.home)
            target.parent.mkdir(parents=True, exist_ok=True)
            # Keep backups from separate runs within the same second distinct.
            while target.exists() or target.is_symlink():
                target = target.with_name(target.name + '.bak')
            shutil.copy2(path, target, follow_symlinks=False)

    def copy(self, source, target, executable=False):
        source, target = Path(source), Path(target)
        if target.is_file() and not target.is_symlink() and filecmp.cmp(source, target, shallow=False):
            return
        self.preserve(target)
        target.parent.mkdir(parents=True, exist_ok=True)
        # Do not follow old config symlinks into unrelated files.
        if target.is_symlink():
            target.unlink()
        shutil.copy2(source, target)
        if executable:
            target.chmod(0o755)

    def link(self, source, target):
        target = Path(target)
        if target.is_symlink() and target.resolve() == Path(source).resolve():
            return
        self.preserve(target)
        target.parent.mkdir(parents=True, exist_ok=True)
        if target.exists() or target.is_symlink():
            target.unlink()
        target.symlink_to(source)

    def download(self, url, digest, name):
        target = self.work / name
        run('curl', '-fL', '--retry', '2', '--connect-timeout', '15', '-o', str(target), url)
        actual = hashlib.sha256(target.read_bytes()).hexdigest()
        if actual != digest:
            raise RuntimeError('Checksum mismatch for ' + name)
        return target

    def unpack(self, archive, name):
        dest = self.work / (name + '-extracted')
        dest.mkdir()
        if zipfile.is_zipfile(archive):
            with zipfile.ZipFile(archive) as z:
                for entry in z.infolist():
                    safe_member(dest, entry.filename)
                    if (entry.external_attr >> 16) & 0o170000 == 0o120000:
                        raise RuntimeError('Unexpected symlink in zip archive')
                z.extractall(dest)
        elif str(archive).endswith('.tar.gz'):
            with tarfile.open(archive) as tar:
                for entry in tar.getmembers():
                    safe_member(dest, entry.name)
                    if entry.issym():
                        safe_member(dest, str(Path(entry.name).parent / entry.linkname))
                    elif entry.islnk():
                        safe_member(dest, entry.linkname)
                    elif not (entry.isfile() or entry.isdir()):
                        raise RuntimeError('Unexpected archive entry: ' + entry.name)
                if hasattr(tarfile, 'data_filter'):
                    tar.extractall(dest, filter='data')
                else:
                    tar.extractall(dest)
        else:
            with gzip.open(archive, 'rb') as src, (dest / name).open('wb') as out:
                shutil.copyfileobj(src, out)
        return dest

    def install(self, tool, asset):
        archive = self.download(asset['url'], asset['sha256'], asset['url'].rsplit('/', 1)[1])
        extracted = self.unpack(archive, tool)
        if tool == 'nvim':
            candidates = list(extracted.glob('*/bin/nvim'))
            if len(candidates) != 1:
                raise RuntimeError('Unexpected Neovim archive layout')
            candidates[0].chmod(0o755)
            run(str(candidates[0]), '--version', stdout=subprocess.DEVNULL)
            bundle = self.home / '.local/lib/dotfiles' / archive.name.removesuffix('.tar.gz')
            if bundle.exists():
                # Resume an interrupted run that moved the bundle before linking it.
                run(str(bundle / 'bin/nvim'), '--version', stdout=subprocess.DEVNULL)
            else:
                bundle.parent.mkdir(parents=True, exist_ok=True)
                shutil.move(str(candidates[0].parents[1]), bundle)
            self.link(bundle / 'bin/nvim', self.bin / 'nvim')
        else:
            for binary in ([tool, 'ya'] if tool == 'yazi' else [tool]):
                matches = [p for p in extracted.rglob(binary) if p.is_file()]
                if len(matches) != 1:
                    raise RuntimeError('Unexpected archive layout for ' + binary)
                matches[0].chmod(0o755)
                run(str(matches[0]), '--version', stdout=subprocess.DEVNULL)
                self.copy(matches[0], self.bin / binary, executable=True)

    def node(self, arch):
        # Current Node 24 LTS includes npm and npx, unlike some distro installs.
        index = self.work / 'node-shasums.txt'
        base = 'https://nodejs.org/dist/latest-v24.x/'
        run('curl', '-fsSL', '--retry', '2', '-o', str(index), base + 'SHASUMS256.txt')
        suffix = '-linux-' + ('x64' if arch == 'x86_64' else 'arm64') + '.tar.gz'
        entries = [line.split() for line in index.read_text().splitlines() if line.endswith(suffix)]
        if len(entries) != 1:
            raise RuntimeError('Could not select official Node 24 archive')
        digest, name = entries[0]
        archive = self.download(base + name, digest, name)
        extracted = self.unpack(archive, 'node')
        candidate = extracted / name.removesuffix('.tar.gz')
        run(str(candidate / 'bin/node'), '--version', stdout=subprocess.DEVNULL)
        bundle = self.home / '.local/lib/dotfiles' / candidate.name
        if not bundle.exists():
            bundle.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(candidate), bundle)
        for binary in ('node', 'npm', 'npx'):
            self.link(bundle / 'bin' / binary, self.bin / binary)

    def configs(self, root=ROOT):
        config = self.home / '.config'
        for directory in ('nvim', 'zsh', 'lazygit', 'bat', 'fsh'):
            source = root / 'dot_config' / directory
            for path in sorted(source.rglob('*')):
                rel = path.relative_to(source)
                if any(part.startswith('.') or part == 'plugins' and directory == 'zsh' for part in rel.parts):
                    continue
                if path.is_file():
                    parts = [('.' + p[4:]) if p.startswith('dot_') else p for p in rel.parts]
                    self.copy(path, config / directory / Path(*parts))
        self.copy(root / 'dot_config/starship.toml', config / 'starship.toml')
        self.copy(root / 'dot_zshenv', self.home / '.zshenv')
        for directory in ('.cache/zsh', '.local/state/zsh', '.local/share', '.config/kitty'):
            (self.home / directory).mkdir(parents=True, exist_ok=True)
        # Preserve theme sync for local Linux Kitty, too.
        self.copy(root / 'base16-kitty/colors/south.conf', self.home / 'base16-kitty/colors/south.conf')


def safe_member(dest, name):
    target = (dest / name).resolve()
    if target != dest.resolve() and dest.resolve() not in target.parents:
        raise RuntimeError('Unsafe archive path: ' + name)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true', help='report missing tools without downloading or changing files')
    args = parser.parse_args()
    if sys.version_info < (3, 9):
        raise RuntimeError('Python 3.9 or newer is required.')
    arch = architecture()
    for tool in ('python3', 'curl', 'git', 'zsh', 'make', 'cc'):
        if not shutil.which(tool):
            raise RuntimeError('Install prerequisite with your distribution package manager: ' + tool)
    if platform.libc_ver()[0] != 'glibc':
        raise RuntimeError('This binary installer requires glibc Linux; Alpine/musl needs distro packages.')
    home = Path.home()
    os.environ['PATH'] = str(home / '.local/bin') + os.pathsep + os.environ['PATH']
    manifest = json.loads((ROOT / 'scripts/linux-tools.json').read_text())
    tools = list(manifest) + ['node']
    missing = [tool for tool in tools if not usable(tool)]
    for tool in tools:
        print(tool + ': ' + ('install/upgrade' if tool in missing else 'ready'), flush=True)
    if args.check:
        return
    # Avoid a user's old bat theme config breaking the binary verification.
    os.environ['BAT_CONFIG_PATH'] = '/dev/null'
    with tempfile.TemporaryDirectory(prefix='dotfiles-linux-') as work:
        setup = Setup(home, work)
        for tool in missing:
            print('Installing ' + tool, flush=True)
            if tool == 'node':
                setup.node(arch)
            else:
                setup.install(tool, manifest[tool][arch])
        setup.configs()
        os.environ.pop('BAT_CONFIG_PATH', None)
        run('bat', 'cache', '--build')
        # ZLE needs a terminal. Noninteractive installs defer plugin setup to
        # the user's first interactive shell instead of printing ZLE errors.
        if sys.stdin.isatty():
            run('zsh', '-lic', 'true')
        else:
            print('Zsh plugins will install when you start an interactive shell.')
        for tool in tools:
            if not usable(tool):
                raise RuntimeError('Verification failed for ' + tool)
        print('\nSetup complete. Start Zsh with: exec zsh -l')
        print('Backups (if any): ' + str(setup.backup))
        print('Open nvim to install its plugins; run :checkhealth afterwards.')
        print('Kitty runs on your client. Use kitten ssh from Kitty.')


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, OSError, subprocess.CalledProcessError) as error:
        sys.exit('Setup stopped: ' + str(error))
