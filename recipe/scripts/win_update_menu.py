import argparse
import sys

if __name__ == '__main__':

  parser = argparse.ArgumentParser()
  parser.add_argument('--file')
  parser.add_argument('--version')
  namespace = parser.parse_args(sys.argv[1:])

  with open(namespace.file, 'r') as f:
    lines = f.readlines()


  with open(namespace.file, 'w') as f:
    for line in lines:
      line = line.replace('REPLACEME', namespace.version)
      f.write(line)
