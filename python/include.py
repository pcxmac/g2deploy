#!/usr/bin/env python3
"""
Gentoo Linux deployment and system management functions.
Converted from bash to Python.
"""

import os
import sys
import subprocess
import json
import yaml
import re
import shutil
from pathlib import Path
from typing import Optional, Dict, List, Tuple
from datetime import datetime
import urllib.request
import urllib.parse
import tempfile

# Color codes for terminal output
class Colors:
    NORMAL = "\033[1;30m"
    RED = "\033[1;31m"
    GREEN = "\033[1;32m"
    YELLOW = "\033[1;33m"
    BLUE = "\033[1;34m"
    PINK = "\033[1;35m"
    TEAL = "\033[1;36m"
    WHITE = "\033[1;37m"
    RESET = "\033[m"

# Script directory
SCRIPT_DIR = Path(__file__).resolve().parent.parent


def run_cmd(cmd: str, shell: bool = True, check: bool = True, 
            capture_output: bool = False) -> subprocess.CompletedProcess:
    """Execute shell command with error handling."""
    try:
        result = subprocess.run(
            cmd, 
            shell=shell, 
            check=check, 
            capture_output=capture_output,
            text=True
        )
        return result
    except subprocess.CalledProcessError as e:
        print(f"{Colors.RED}Command failed: {cmd}{Colors.RESET}", file=sys.stderr)
        raise


def kernel_latest() -> str:
    """Get the latest kernel version from kernel.org git."""
    try:
        result = run_cmd(
            "git ls-remote https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git",
            capture_output=True
        )
        lines = [l for l in result.stdout.split('\n') if 'rc' not in l.lower()]
        if lines:
            last = lines[-1]
            version = last.split('/')[-1].strip()
            version = version.replace('v', '').replace('^{}', '')
            return f"linux-{version}-gentoo"
    except Exception as e:
        print(f"Error fetching kernel version: {e}", file=sys.stderr)
    return ""


def zfs_max_support() -> str:
    """Get maximum supported kernel version for ZFS."""
    try:
        response = urllib.request.urlopen(
            'https://raw.githubusercontent.com/openzfs/zfs/master/META'
        )
        content = response.read().decode('utf-8')
        
        for line in content.split('\n'):
            if 'Linux-Maximum' in line:
                version = line.split(':')[1].strip()
                # Query for matching gentoo-sources
                result = run_cmd(
                    f'equery -CN list -po gentoo-sources 2>/dev/null | grep "{version}" | tail -1',
                    capture_output=True
                )
                if result.stdout:
                    pkg = result.stdout.strip().split()[0]
                    version = pkg.split(':')[1] if ':' in pkg else version
                    return f"linux-{version}-gentoo"
    except Exception as e:
        print(f"Error getting ZFS max support: {e}", file=sys.stderr)
    return ""


def find_uuid(device: str) -> str:
    """Find UUID for a given device."""
    if not device:
        return ""
    
    try:
        result = run_cmd(
            f'ls /dev/disk/by-uuid/ -ail | grep "{os.path.basename(device)}"',
            capture_output=True
        )
        if result.stdout:
            return result.stdout.strip().split()[-1]
    except Exception:
        pass
    return ""


def find_boot(param: Optional[str] = None) -> str:
    """Find boot partition by UUID, device, or auto-detect."""
    r_type = ""
    
    if param:
        # Check if it's a UUID
        try:
            dev_path = Path(f"/dev/disk/by-uuid/{param}").resolve()
            if dev_path.exists():
                r_type = param
        except Exception:
            pass
        
        # Check if it's a device with FAT32
        if not r_type:
            try:
                result = run_cmd(
                    f'file -s {param} | grep "FAT (32 bit)" | grep "{param}: DOS/MBR boot sector"',
                    capture_output=True, check=False
                )
                if result.returncode == 0:
                    uuid_result = run_cmd(
                        f'ls -ail /dev/disk/by-uuid/ | grep {os.path.basename(param)}',
                        capture_output=True
                    )
                    if uuid_result.stdout:
                        r_type = uuid_result.stdout.strip().split()[-1]
            except Exception:
                pass
    
    # Auto-detect from /proc/mounts
    if not r_type:
        try:
            with open('/proc/mounts', 'r') as f:
                for line in f:
                    if ' /boot ' in line:
                        parts = line.split()
                        if parts[0].startswith('/dev/'):
                            device = os.path.basename(parts[0])
                            result = run_cmd(
                                f'ls -ail /dev/disk/by-uuid/ | grep {device}',
                                capture_output=True
                            )
                            if result.stdout:
                                r_type = result.stdout.strip().split()[-1]
                            break
        except Exception:
            pass
    
    # Check kernel command line
    if not r_type:
        try:
            with open('/proc/cmdline', 'r') as f:
                cmdline = f.read()
                if 'boot=' in cmdline:
                    for part in cmdline.split():
                        if part.startswith('boot='):
                            r_type = part.split('=')[1]
                            break
        except Exception:
            pass
    
    # Convert UUID to device path
    if r_type:
        try:
            uuid_path = Path(f"/dev/disk/by-uuid/{r_type}")
            if uuid_path.is_symlink():
                target = uuid_path.resolve()
                return str(target)
        except Exception:
            pass
    
    return ""


def installed_kernel(boot_disk: str, pkg_root: str) -> int:
    """
    Check if kernel needs to be installed.
    Returns: 1 = do install, 0 = do nothing, -1 = error
    """
    pid = os.getpid()
    tmp_mount = f"/tmp/boot_{pid}"
    
    try:
        os.makedirs(tmp_mount, exist_ok=True)
        run_cmd(f"mount -t vfat {boot_disk} {tmp_mount}")
        
        # Get latest kernel on boot disk
        linux_dir = Path(tmp_mount) / "LINUX"
        if linux_dir.exists():
            kernels = sorted(linux_dir.iterdir(), reverse=True)
            if kernels:
                latest_kernel = kernels[0].name.replace('-gentoo', '').split('-')[0]
                latest_ref = kernels[0].name
            else:
                latest_kernel = ""
                latest_ref = ""
        else:
            latest_kernel = ""
            latest_ref = ""
        
        # Get latest build
        source_dir = Path(pkg_root) / "source"
        if source_dir.exists():
            builds = sorted(source_dir.iterdir(), reverse=True)
            if builds:
                latest_build = builds[0].name.replace('linux-', '').replace('-gentoo', '')
            else:
                latest_build = ""
        else:
            latest_build = ""
        
        # Compare configs if both exist
        diff_eq = 0
        if latest_ref and latest_build:
            config_path = linux_dir / latest_ref / "config"
            build_config = Path(pkg_root) / "source" / "linux" / ".config"
            if config_path.exists() and build_config.exists():
                result = run_cmd(
                    f"diff {config_path} {build_config} | wc -l",
                    capture_output=True
                )
                diff_eq = int(result.stdout.strip())
        
        # Unmount
        run_cmd(f"umount {tmp_mount}")
        os.rmdir(tmp_mount)
        
        # Decision logic
        if not latest_kernel:
            return 1
        if not latest_build:
            return -1
        if diff_eq > 0:
            return 1
        if latest_kernel != latest_build:
            return 1
        if latest_kernel == latest_build:
            return 0
        
    except Exception as e:
        print(f"Error checking installed kernel: {e}", file=sys.stderr)
        try:
            run_cmd(f"umount {tmp_mount}", check=False)
            if os.path.exists(tmp_mount):
                os.rmdir(tmp_mount)
        except:
            pass
        return -1
    
    return 0


def get_kver() -> str:
    """Get current kernel version from repository or local system."""
    # Try to get from repository
    try:
        # This would need the mirror.sh script implementation
        # For now, fall back to uname
        pass
    except Exception:
        pass
    
    # Fall back to uname
    try:
        result = run_cmd("uname --kernel-release", capture_output=True)
        kver = result.stdout.strip()
        return f"linux-{kver}"
    except Exception:
        return ""


def decompress(src: str, dst: str) -> None:
    """Decompress archive to destination."""
    src_path = Path(src)
    dst_path = Path(dst)
    
    # Detect compression type
    result = run_cmd(f"file {src}", capture_output=True)
    compression_type = result.stdout.strip().split()[1] if result.stdout else ""
    
    if 'XZ' in compression_type:
        run_cmd(f"pv {src} | tar xJf - -C {dst}")
    elif 'gzip' in compression_type:
        run_cmd(f"pv {src} | tar xzf - -C {dst}")
    else:
        raise ValueError(f"Unsupported compression type: {compression_type}")


def compress(src: str, dst: str) -> None:
    """Compress source to destination."""
    # Get size for progress bar
    result = run_cmd(f'du -sb "{src}"', capture_output=True)
    ksize = result.stdout.strip().split()[0]
    
    run_cmd(f'tar cfz - "{src}" | pv -s {ksize} > "{dst}"')


def get_g2_profile(mountpoint: str = "/", arg: Optional[str] = None) -> str:
    """Get Gentoo profile information."""
    # Get profile from eselect
    if mountpoint == "/":
        result = run_cmd("eselect profile show | tail -n1", capture_output=True)
    else:
        result = run_cmd(
            f'chroot "{mountpoint}" eselect profile show | tail -n1',
            capture_output=True
        )
    
    profile = result.stdout.strip()
    # Remove leading numbers and whitespace
    profile = re.sub(r'^\s*\d+\.\s*', '', profile).strip()
    
    # Map to simplified profile names
    profile_map = {
        'hardened': '17.1/hardened',
        'default/linux/amd64/17.1': '17.1/openrc',
        'openrc': '17.1/openrc',
        'systemd': '17.1/systemd',
    }
    
    for key, value in profile_map.items():
        if key in profile.lower():
            profile = value
            break
    
    if 'plasma' in profile.lower():
        if 'systemd' in profile.lower():
            profile = '17.1/desktop/plasma/systemd'
        else:
            profile = '17.1/desktop/plasma'
    elif 'gnome' in profile.lower():
        if 'systemd' in profile.lower():
            profile = '17.1/desktop/gnome/systemd'
        else:
            profile = '17.1/desktop/gnome'
    elif 'selinux' in profile.lower():
        if 'hardened' in profile.lower():
            profile = '17.1/hardened/selinux'
        else:
            profile = '17.1/selinux'
    
    # Handle arguments
    if arg == '--arch':
        return profile.split('/')[0] if '/' in profile else profile
    elif arg == '--version':
        parts = profile.split('/')
        return parts[1] if len(parts) > 1 else ""
    elif arg == '--full':
        # Return full profile path
        result = run_cmd("eselect profile show | tail -n1", capture_output=True)
        return result.stdout.strip()
    
    return profile


def get_host_zpool() -> str:
    """Get the ZFS pool for root filesystem."""
    try:
        result = run_cmd('mount | grep " / "', capture_output=True)
        if result.stdout:
            pool = result.stdout.strip().split()[0]
            return pool.split('/')[0]
    except Exception:
        pass
    return ""


def get_zfs_dataset(mountpoint: str) -> str:
    """Get ZFS dataset for a given mountpoint."""
    try:
        result = run_cmd(
            f'zfs get mountpoint "{mountpoint}" 2>/dev/null | sed -n 2p',
            capture_output=True, check=False
        )
        if result.returncode == 0 and result.stdout:
            dataset = result.stdout.strip().split()[0]
            return dataset.rstrip('/')
    except Exception:
        pass
    return ""


def get_zfs_mountpoint(dataset: str) -> str:
    """Get mountpoint for a given ZFS dataset."""
    try:
        result = run_cmd(
            f'zfs get mountpoint "{dataset}" 2>/dev/null | sed -n 2p',
            capture_output=True, check=False
        )
        if result.returncode == 0 and result.stdout:
            mountpt = result.stdout.strip().split()[2]
            return mountpt.rstrip('/')
    except Exception:
        pass
    return ""


def clear_mounts(offset: str) -> None:
    """Clear all mounts under a given path."""
    offset = offset.rstrip('/')
    
    if not offset or offset == '/':
        print("Cannot clear rootfs", file=sys.stderr)
        return
    
    # Kill processes using the mount
    try:
        result = run_cmd(
            f'lsof "{offset}" 2>/dev/null | sed "1d" | awk "{{print $2}}" | uniq',
            capture_output=True, check=False
        )
        if result.stdout:
            for pid in result.stdout.strip().split('\n'):
                if pid:
                    try:
                        run_cmd(f"kill -9 {pid}", check=False)
                    except:
                        pass
    except:
        pass
    
    # Unmount all mounts under offset
    while True:
        try:
            with open('/proc/mounts', 'r') as f:
                mounts = [line.split()[1] for line in f if offset in line.split()[1]]
            
            if not mounts:
                break
            
            for mount in reversed(mounts):  # Unmount in reverse order
                try:
                    run_cmd(f"umount {mount}", check=False)
                except:
                    pass
        except:
            break


def is_host_up(host: str, port: int) -> bool:
    """Check if a host is up on a given port."""
    try:
        result = run_cmd(
            f"nc -w 3 -z -v {host} {port} 2>&1 | grep -E 'open|succeeded'",
            capture_output=True, check=False
        )
        return result.returncode == 0 and result.stdout.strip() != ""
    except:
        return False


def deploy_users() -> None:
    """Deploy default users."""
    try:
        run_cmd("usermod -s /bin/zsh root")
        run_cmd("echo 'root:@PXCW0rd' | chpasswd", check=False)
        run_cmd("useradd sysop", check=False)
        run_cmd("echo 'sysop:@PXCW0rd' | chpasswd", check=False)
        run_cmd("usermod --home /home/sysop sysop")
        run_cmd("usermod -a -G wheel,portage sysop")
        run_cmd("usermod --shell /bin/zsh sysop")
        
        # Fix permissions
        result = run_cmd("eval echo ~sysop", capture_output=True)
        homedir = result.stdout.strip()
        if homedir:
            run_cmd(f'chown sysop:sysop "{homedir}" -R', check=False)
    except Exception as e:
        print(f"Error deploying users: {e}", file=sys.stderr)


def tstamp() -> str:
    """Get current timestamp as hex."""
    timestamp = int(datetime.now().timestamp())
    return f"0x{timestamp:X}"


if __name__ == "__main__":
    # Example usage
    print(f"Script directory: {SCRIPT_DIR}")
    print(f"Current kernel: {get_kver()}")
    print(f"Current profile: {get_g2_profile()}")
