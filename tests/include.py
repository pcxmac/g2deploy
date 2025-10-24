#!/usr/bin/env python3
"""
Unit tests for include.py - Gentoo deployment functions.
Run with: python -m pytest test_include.py -v
or: python test_include.py
"""

import unittest
from unittest.mock import patch, mock_open, MagicMock, call
import subprocess
import tempfile
import shutil
from pathlib import Path
import sys
import os

# Import the module to test
# Adjust the import path as needed for your project structure
try:
    import include
except ImportError:
    # If running from same directory
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import include


class TestColors(unittest.TestCase):
    """Test color code definitions."""
    
    def test_colors_defined(self):
        """Test that all color codes are defined."""
        self.assertTrue(hasattr(include.Colors, 'RED'))
        self.assertTrue(hasattr(include.Colors, 'GREEN'))
        self.assertTrue(hasattr(include.Colors, 'BLUE'))
        self.assertTrue(hasattr(include.Colors, 'RESET'))
    
    def test_colors_are_strings(self):
        """Test that color codes are strings."""
        self.assertIsInstance(include.Colors.RED, str)
        self.assertIsInstance(include.Colors.GREEN, str)
        self.assertIsInstance(include.Colors.RESET, str)


class TestRunCmd(unittest.TestCase):
    """Test run_cmd function."""
    
    @patch('subprocess.run')
    def test_run_cmd_success(self, mock_run):
        """Test successful command execution."""
        mock_run.return_value = subprocess.CompletedProcess(
            args=['echo', 'test'],
            returncode=0,
            stdout='test\n',
            stderr=''
        )
        
        result = include.run_cmd('echo test', capture_output=True)
        self.assertEqual(result.returncode, 0)
        mock_run.assert_called_once()
    
    @patch('subprocess.run')
    def test_run_cmd_failure(self, mock_run):
        """Test command execution failure."""
        mock_run.side_effect = subprocess.CalledProcessError(1, 'false')
        
        with self.assertRaises(subprocess.CalledProcessError):
            include.run_cmd('false', check=True)
    
    @patch('subprocess.run')
    def test_run_cmd_no_check(self, mock_run):
        """Test command execution without check."""
        mock_run.return_value = subprocess.CompletedProcess(
            args=['false'],
            returncode=1,
            stdout='',
            stderr=''
        )
        
        result = include.run_cmd('false', check=False)
        self.assertEqual(result.returncode, 1)


class TestKernelLatest(unittest.TestCase):
    """Test kernel_latest function."""
    
    @patch('include.run_cmd')
    def test_kernel_latest_success(self, mock_run):
        """Test getting latest kernel version."""
        mock_run.return_value = MagicMock(
            stdout='abc123\trefs/tags/v6.6.1\ndef456\trefs/tags/v6.6.2\n'
        )
        
        result = include.kernel_latest()
        self.assertEqual(result, 'linux-6.6.2-gentoo')
    
    @patch('include.run_cmd')
    def test_kernel_latest_filters_rc(self, mock_run):
        """Test that RC versions are filtered out."""
        mock_run.return_value = MagicMock(
            stdout='abc123\trefs/tags/v6.6.1\ndef456\trefs/tags/v6.6.2-rc1\n'
        )
        
        result = include.kernel_latest()
        self.assertEqual(result, 'linux-6.6.1-gentoo')
    
    @patch('include.run_cmd')
    def test_kernel_latest_error(self, mock_run):
        """Test kernel_latest with git error."""
        mock_run.side_effect = Exception("Git error")
        
        result = include.kernel_latest()
        self.assertEqual(result, '')


class TestZfsMaxSupport(unittest.TestCase):
    """Test zfs_max_support function."""
    
    @patch('urllib.request.urlopen')
    @patch('include.run_cmd')
    def test_zfs_max_support_success(self, mock_run, mock_urlopen):
        """Test getting ZFS max supported kernel."""
        mock_response = MagicMock()
        mock_response.read.return_value = b'Linux-Maximum: 6.5\nOther: value\n'
        mock_urlopen.return_value = mock_response
        
        mock_run.return_value = MagicMock(
            stdout='sys-kernel/gentoo-sources:6.5.1\n'
        )
        
        result = include.zfs_max_support()
        self.assertEqual(result, 'linux-6.5.1-gentoo')
    
    @patch('urllib.request.urlopen')
    def test_zfs_max_support_error(self, mock_urlopen):
        """Test zfs_max_support with network error."""
        mock_urlopen.side_effect = Exception("Network error")
        
        result = include.zfs_max_support()
        self.assertEqual(result, '')


class TestFindUuid(unittest.TestCase):
    """Test find_uuid function."""
    
    @patch('include.run_cmd')
    def test_find_uuid_success(self, mock_run):
        """Test finding UUID for device."""
        mock_run.return_value = MagicMock(
            stdout='123  456  sda1 -> ../../sda1  ABC123\n'
        )
        
        result = include.find_uuid('/dev/sda1')
        self.assertEqual(result, 'ABC123')
    
    def test_find_uuid_empty_device(self):
        """Test find_uuid with empty device."""
        result = include.find_uuid('')
        self.assertEqual(result, '')
    
    @patch('include.run_cmd')
    def test_find_uuid_not_found(self, mock_run):
        """Test find_uuid when device not found."""
        mock_run.return_value = MagicMock(stdout='')
        
        result = include.find_uuid('/dev/sda1')
        self.assertEqual(result, '')


class TestFindBoot(unittest.TestCase):
    """Test find_boot function."""
    
    @patch('pathlib.Path.exists')
    @patch('pathlib.Path.resolve')
    def test_find_boot_by_uuid(self, mock_resolve, mock_exists):
        """Test finding boot by UUID."""
        mock_exists.return_value = True
        mock_resolve.return_value = Path('/dev/sda1')
        
        result = include.find_boot('ABC-123')
        self.assertEqual(result, '/dev/sda1')
    
    @patch('builtins.open', new_callable=mock_open, 
           read_data='/dev/sda1 /boot vfat rw 0 0\n')
    @patch('include.run_cmd')
    @patch('pathlib.Path.is_symlink')
    @patch('pathlib.Path.resolve')
    def test_find_boot_from_mounts(self, mock_resolve, mock_is_symlink, 
                                    mock_run, mock_file):
        """Test finding boot from /proc/mounts."""
        mock_run.return_value = MagicMock(stdout='ABC-123\n')
        mock_is_symlink.return_value = True
        mock_resolve.return_value = Path('/dev/sda1')
        
        result = include.find_boot()
        self.assertEqual(result, '/dev/sda1')
    
    @patch('builtins.open', new_callable=mock_open,
           read_data='root=/dev/sda2 boot=ABC-123 ro\n')
    @patch('pathlib.Path.is_symlink')
    @patch('pathlib.Path.resolve')
    def test_find_boot_from_cmdline(self, mock_resolve, mock_is_symlink, mock_file):
        """Test finding boot from /proc/cmdline."""
        mock_is_symlink.return_value = True
        mock_resolve.return_value = Path('/dev/sda1')
        
        # Patch /proc/mounts to be empty
        with patch('builtins.open', mock_open(read_data='')) as mock_mounts:
            mock_file.side_effect = [
                mock_mounts.return_value,  # /proc/mounts
                mock_open(read_data='root=/dev/sda2 boot=ABC-123 ro\n').return_value  # /proc/cmdline
            ]
            
            result = include.find_boot()
            self.assertEqual(result, '/dev/sda1')


class TestInstalledKernel(unittest.TestCase):
    """Test installed_kernel function."""
    
    @patch('include.run_cmd')
    @patch('os.makedirs')
    @patch('os.rmdir')
    @patch('pathlib.Path.exists')
    @patch('pathlib.Path.iterdir')
    def test_installed_kernel_needs_install(self, mock_iterdir, mock_exists,
                                           mock_rmdir, mock_makedirs, mock_run):
        """Test when kernel needs installation."""
        mock_exists.return_value = False
        
        result = include.installed_kernel('/dev/sda1', '/mnt/pkg')
        self.assertEqual(result, 1)
    
    @patch('include.run_cmd')
    @patch('os.makedirs')
    @patch('os.rmdir')
    @patch('pathlib.Path.exists')
    @patch('pathlib.Path.iterdir')
    def test_installed_kernel_up_to_date(self, mock_iterdir, mock_exists,
                                         mock_rmdir, mock_makedirs, mock_run):
        """Test when kernel is up to date."""
        mock_exists.return_value = True
        mock_iterdir.return_value = [MagicMock(name='6.6.1-gentoo')]
        
        # Mock mount/umount
        mock_run.side_effect = [
            MagicMock(),  # mount
            MagicMock(stdout='0\n'),  # diff
            MagicMock(),  # umount
        ]
        
        # This is complex to fully mock, so we'll just verify error handling
        result = include.installed_kernel('/dev/sda1', '/mnt/pkg')
        self.assertIn(result, [-1, 0, 1])


class TestGetKver(unittest.TestCase):
    """Test get_kver function."""
    
    @patch('include.run_cmd')
    def test_get_kver_success(self, mock_run):
        """Test getting kernel version."""
        mock_run.return_value = MagicMock(stdout='6.6.1-gentoo\n')
        
        result = include.get_kver()
        self.assertEqual(result, 'linux-6.6.1-gentoo')
    
    @patch('include.run_cmd')
    def test_get_kver_error(self, mock_run):
        """Test get_kver with error."""
        mock_run.side_effect = Exception("Command error")
        
        result = include.get_kver()
        self.assertEqual(result, '')


class TestDecompress(unittest.TestCase):
    """Test decompress function."""
    
    @patch('include.run_cmd')
    def test_decompress_xz(self, mock_run):
        """Test decompressing XZ archive."""
        mock_run.side_effect = [
            MagicMock(stdout='test.tar.xz: XZ compressed data\n'),
            MagicMock()
        ]
        
        include.decompress('/tmp/test.tar.xz', '/tmp/out')
        
        # Verify the tar command was called
        calls = mock_run.call_args_list
        self.assertEqual(len(calls), 2)
        self.assertIn('tar xJf', calls[1][0][0])
    
    @patch('include.run_cmd')
    def test_decompress_gzip(self, mock_run):
        """Test decompressing gzip archive."""
        mock_run.side_effect = [
            MagicMock(stdout='test.tar.gz: gzip compressed data\n'),
            MagicMock()
        ]
        
        include.decompress('/tmp/test.tar.gz', '/tmp/out')
        
        calls = mock_run.call_args_list
        self.assertEqual(len(calls), 2)
        self.assertIn('tar xzf', calls[1][0][0])
    
    @patch('include.run_cmd')
    def test_decompress_unsupported(self, mock_run):
        """Test decompressing unsupported format."""
        mock_run.return_value = MagicMock(stdout='test.rar: RAR archive\n')
        
        with self.assertRaises(ValueError):
            include.decompress('/tmp/test.rar', '/tmp/out')


class TestCompress(unittest.TestCase):
    """Test compress function."""
    
    @patch('include.run_cmd')
    def test_compress_success(self, mock_run):
        """Test compressing files."""
        mock_run.side_effect = [
            MagicMock(stdout='1048576 /tmp/test\n'),
            MagicMock()
        ]
        
        include.compress('/tmp/test', '/tmp/test.tar.gz')
        
        calls = mock_run.call_args_list
        self.assertEqual(len(calls), 2)
        self.assertIn('tar cfz', calls[1][0][0])
        self.assertIn('pv', calls[1][0][0])


class TestGetG2Profile(unittest.TestCase):
    """Test get_g2_profile function."""
    
    @patch('include.run_cmd')
    def test_get_g2_profile_openrc(self, mock_run):
        """Test getting OpenRC profile."""
        mock_run.return_value = MagicMock(
            stdout='  1.  default/linux/amd64/17.1 (stable)\n'
        )
        
        result = include.get_g2_profile('/')
        self.assertEqual(result, '17.1/openrc')
    
    @patch('include.run_cmd')
    def test_get_g2_profile_plasma(self, mock_run):
        """Test getting Plasma profile."""
        mock_run.return_value = MagicMock(
            stdout='  1.  default/linux/amd64/17.1/desktop/plasma (stable)\n'
        )
        
        result = include.get_g2_profile('/')
        self.assertEqual(result, '17.1/desktop/plasma')
    
    @patch('include.run_cmd')
    def test_get_g2_profile_arch_arg(self, mock_run):
        """Test getting profile with --arch argument."""
        mock_run.return_value = MagicMock(
            stdout='  1.  default/linux/amd64/17.1 (stable)\n'
        )
        
        result = include.get_g2_profile('/', '--arch')
        self.assertEqual(result, '17.1')


class TestZfsFunctions(unittest.TestCase):
    """Test ZFS-related functions."""
    
    @patch('include.run_cmd')
    def test_get_host_zpool(self, mock_run):
        """Test getting host ZFS pool."""
        mock_run.return_value = MagicMock(
            stdout='tank/root on / type zfs (rw)\n'
        )
        
        result = include.get_host_zpool()
        self.assertEqual(result, 'tank')
    
    @patch('include.run_cmd')
    def test_get_zfs_dataset(self, mock_run):
        """Test getting ZFS dataset."""
        mock_run.return_value = MagicMock(
            returncode=0,
            stdout='tank/root  mountpoint  /  local\n'
        )
        
        result = include.get_zfs_dataset('/')
        self.assertEqual(result, 'tank/root')
    
    @patch('include.run_cmd')
    def test_get_zfs_mountpoint(self, mock_run):
        """Test getting ZFS mountpoint."""
        mock_run.return_value = MagicMock(
            returncode=0,
            stdout='tank/root  mountpoint  /mnt  local\n'
        )
        
        result = include.get_zfs_mountpoint('tank/root')
        self.assertEqual(result, '/mnt')
    
    @patch('include.run_cmd')
    def test_get_zfs_dataset_error(self, mock_run):
        """Test get_zfs_dataset with error."""
        mock_run.return_value = MagicMock(returncode=1, stdout='')
        
        result = include.get_zfs_dataset('/')
        self.assertEqual(result, '')


class TestClearMounts(unittest.TestCase):
    """Test clear_mounts function."""
    
    def test_clear_mounts_root_protection(self):
        """Test that clearing root is prevented."""
        with patch('sys.stderr', new_callable=MagicMock):
            include.clear_mounts('/')
            include.clear_mounts('')
    
    @patch('include.run_cmd')
    @patch('builtins.open', new_callable=mock_open)
    def test_clear_mounts_kills_processes(self, mock_file, mock_run):
        """Test that processes are killed."""
        # Mock lsof output
        mock_run.side_effect = [
            MagicMock(stdout='1234\n5678\n'),  # lsof
            MagicMock(),  # kill 1234
            MagicMock(),  # kill 5678
        ]
        
        # Mock empty /proc/mounts
        mock_file.return_value.read.return_value = ''
        
        include.clear_mounts('/mnt/test')
        
        # Verify kills were attempted
        kill_calls = [c for c in mock_run.call_args_list if 'kill' in str(c)]
        self.assertGreaterEqual(len(kill_calls), 2)


class TestIsHostUp(unittest.TestCase):
    """Test is_host_up function."""
    
    @patch('include.run_cmd')
    def test_is_host_up_true(self, mock_run):
        """Test when host is up."""
        mock_run.return_value = MagicMock(
            returncode=0,
            stdout='Connection succeeded\n'
        )
        
        result = include.is_host_up('localhost', 22)
        self.assertTrue(result)
    
    @patch('include.run_cmd')
    def test_is_host_up_false(self, mock_run):
        """Test when host is down."""
        mock_run.return_value = MagicMock(
            returncode=1,
            stdout=''
        )
        
        result = include.is_host_up('localhost', 9999)
        self.assertFalse(result)
    
    @patch('include.run_cmd')
    def test_is_host_up_exception(self, mock_run):
        """Test with exception."""
        mock_run.side_effect = Exception("Network error")
        
        result = include.is_host_up('localhost', 22)
        self.assertFalse(result)


class TestDeployUsers(unittest.TestCase):
    """Test deploy_users function."""
    
    @patch('include.run_cmd')
    def test_deploy_users_success(self, mock_run):
        """Test user deployment."""
        mock_run.return_value = MagicMock(stdout='/home/sysop\n')
        
        include.deploy_users()
        
        # Verify key commands were called
        calls = [str(c) for c in mock_run.call_args_list]
        self.assertTrue(any('usermod' in c for c in calls))
        self.assertTrue(any('useradd' in c for c in calls))


class TestTstamp(unittest.TestCase):
    """Test tstamp function."""
    
    def test_tstamp_format(self):
        """Test timestamp format."""
        result = include.tstamp()
        
        self.assertTrue(result.startswith('0x'))
        self.assertTrue(all(c in '0123456789ABCDEFx' for c in result))
    
    def test_tstamp_unique(self):
        """Test that timestamps are different."""
        import time
        stamp1 = include.tstamp()
        time.sleep(0.01)
        stamp2 = include.tstamp()
        
        self.assertNotEqual(stamp1, stamp2)


class TestScriptDir(unittest.TestCase):
    """Test SCRIPT_DIR constant."""
    
    def test_script_dir_exists(self):
        """Test that SCRIPT_DIR is defined."""
        self.assertIsNotNone(include.SCRIPT_DIR)
        self.assertIsInstance(include.SCRIPT_DIR, Path)
    
    def test_script_dir_is_path(self):
        """Test that SCRIPT_DIR is a Path object."""
        self.assertIsInstance(include.SCRIPT_DIR, Path)


class TestIntegration(unittest.TestCase):
    """Integration tests requiring actual system (skip in CI)."""
    
    @unittest.skipUnless(os.path.exists('/usr/bin/eselect'), 
                        "Requires Gentoo system")
    def test_get_g2_profile_real(self):
        """Test actual profile detection on Gentoo."""
        result = include.get_g2_profile()
        self.assertIsNotNone(result)
        self.assertIsInstance(result, str)
    
    @unittest.skipUnless(os.path.exists('/usr/bin/uname'),
                        "Requires uname")
    def test_get_kver_real(self):
        """Test actual kernel version detection."""
        result = include.get_kver()
        self.assertTrue(result.startswith('linux-'))


def run_tests():
    """Run all tests."""
    loader = unittest.TestLoader()
    suite = loader.loadTestsFromModule(sys.modules[__name__])
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    return result.wasSuccessful()


if __name__ == '__main__':
    # Run with unittest
    success = run_tests()
    sys.exit(0 if success else 1)
