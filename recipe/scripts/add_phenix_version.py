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
  Add PHENIX, PHENIX_PREFIX and PHENIX_VERSION to the phenix dispatcher, once,
  before its first LIBTBX_PYEXE line. On Windows the dispatcher lives in
  Library\\bin, so LIBTBX_PREFIX is <prefix>\\Library and the prefix is its
  parent; PHENIX_GUI_ENVIRONMENT is added there too (for phenix.refine
  updates). On Linux a UTF-8 locale is set only when the caller has none.
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
      added = False
      with open(phenix_dispatcher, 'w') as f:
        for line in lines:
          line = line.rstrip()
          if not added and line.startswith('LIBTBX_PYEXE'):
            if sys.platform.startswith('linux'):
              # a UTF-8 locale for the GUI, unless the caller has one
              f.write('case "${LC_ALL:-${LANG:-}}" in '
                      '*[Uu][Tt][Ff]-8*|*[Uu][Tt][Ff]8*) ;; '
                      '*) LC_ALL=C.UTF-8; export LC_ALL;; esac\n')
            f.write('PHENIX=${LIBTBX_PREFIX}\n')
            f.write('export PHENIX\n')
            f.write('PHENIX_PREFIX=${LIBTBX_PREFIX}\n')
            f.write('export PHENIX_PREFIX\n')
            f.write(f'PHENIX_VERSION="{version}"')
            f.write('\n')
            f.write('export PHENIX_VERSION\n')
            added = True
          elif not added and line.startswith('@set LIBTBX_PYEXE'):
            # the prefix is the parent of LIBTBX_PREFIX (<prefix>\Library)
            f.write('@for %%F in ("%LIBTBX_PREFIX%") do @set PHENIX=%%~dpF\n')
            f.write('@set PHENIX=%PHENIX:~0,-1%\n')
            f.write('@set PHENIX_PREFIX=%PHENIX%\n')
            f.write('@set PHENIX_GUI_ENVIRONMENT=1\n')
            f.write(f'@set PHENIX_VERSION={version}\n')
            added = True
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
