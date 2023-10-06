'''
Script for finding Visual Studio items in the Windows %PATH%
'''

import os
op = os.path

# =============================================================================
# copied from libtbx/env_config.py
def unique_paths(paths):
  hash = set()
  result = []
  for path in paths:
    try: path_normcase = abs(path.normcase())
    except AttributeError: path_normcase = op.normcase(path)
    if (path_normcase in hash): continue
    hash.add(path_normcase)
    result.append(path)
  return result

# -----------------------------------------------------------------------------
if __name__ == '__main__':
  paths = os.environ.get('PATH', None)
  if paths is not None:
    paths = paths.split(';')
  new_paths = unique_paths(paths)
  new_paths = ';'.join(new_paths)
  print(new_paths)

# =============================================================================
# end
