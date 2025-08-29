'''
Script for copying package-specific binaries to a custom directory to
avoid cluttering the user's path
'''

import argparse
import os
import sys

from pathlib import Path

# =============================================================================
def add_phenix_version(prefix, version):

  '''
  Add PHENIX_VERSION to phenix dispatcher
  Add PHENIX_GUI_ENVIRONMENT to Windows dispatcher as well (for phenix.refine updates)
  '''

  # change version *.*.* to *.*-*
  split_version = version.split('.')
  version = '.'.join(split_version[:-1]) + '-' + split_version[-1]

  # find Phenix dispatcher
  prefix = Path(os.path.abspath(prefix))
  bin_directories = ['bin', 'Library/bin', 'Scripts']

  for bin_dir in bin_directories:
    bin_dir = prefix / bin_dir

    if sys.platform == 'win32':
      phenix_dispatcher = bin_dir / 'phenix.bat'
    else:
      phenix_dispatcher = bin_dir / 'phenix'
    if phenix_dispatcher.exists():
      with open(phenix_dispatcher, 'r') as f:
        lines = f.readlines()
      with open(phenix_dispatcher, 'w') as f:
        for line in lines:
          line = line.rstrip()
          if line.startswith('LIBTBX_PYEXE'):
            if sys.platform.startswith('linux'):
              f.write('LC_ALL=en_US.UTF-8\n')
              f.write('export LC_ALL\n')
            f.write('PHENIX=${LIBTBX_PREFIX}\n')
            f.write('export PHENIX\n')
            f.write('PHENIX_PREFIX=${LIBTBX_PREFIX}\n')
            f.write('export PHENIX_PREFIX\n')
            f.write(f'PHENIX_VERSION="{version}"')
            f.write('\n')
            f.write('export PHENIX_VERSION\n')
          elif line.startswith('@set LIBTBX_PYEXE'):
            f.write('@set PHENIX=%LIBTBX_PREFIX%\n')
            f.write('@set PHENIX_PREFIX=%LIBTBX_PREFIX%\n')
            f.write('@set PHENIX_GUI_ENVIRONMENT=1\n')
            f.write(f'@set PHENIX_VERSION="{version}"')
            f.write('\n')
          f.write(line)
          f.write('\n')

# =============================================================================
if __name__ == '__main__':
  parser = argparse.ArgumentParser(description=__doc__,
                                   formatter_class=argparse.RawDescriptionHelpFormatter)
  parser.add_argument('--prefix', type=str,
    help='''The prefix of the installation. The conda-meta directory must exist in this directory.''',
    required=True)
  parser.add_argument('--version', type=str,
    help='''The Phenix version to add.''',
    required=True)

  namespace = parser.parse_args()

  add_phenix_version(namespace.prefix, namespace.version)

# =============================================================================
# end
