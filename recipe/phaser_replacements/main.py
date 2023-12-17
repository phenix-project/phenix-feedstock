# LIBTBX_SET_DISPATCHER_NAME phenix.phaser

# XXX: imports which rely on compiled modules are postponed (for speed)
from __future__ import print_function

import sys, os
import libtbx.load_env
from libtbx import easy_run
from libtbx.utils import Sorry, Usage

def run_binary (args) :
  exe = ""
  if (os.name == "nt"): exe = ".exe"
  phaser_path = libtbx.env.under_build(path="phaser/exe/phaser"+exe)
  if not os.path.isfile(phaser_path) :
    phaser_path = libtbx.env.under_build(path="exe/phaser"+exe)
  if libtbx.env.installed:
    phaser_path = abs(libtbx.env.bin_path / 'phaser')
  assert os.path.isfile(phaser_path)
  assert phaser_path.find('"') < 0
  if "LIBTBX__VALGRIND_FLAG__" in os.environ :
    if not "LIBTBX_VALGRIND" in os.environ :
      raise Sorry("LIBTBX_VALGRIND not defined - exiting.")
    cmd = '%s "%s"' % (os.environ["LIBTBX_VALGRIND"], phaser_path)
  else :
    cmd = '"'+phaser_path+'"'
  qargs = []
  for arg in args:
    assert arg.find('"') < 0
    qargs.append('"'+arg+'"')
  return easy_run.call("%s %s" % (cmd, " ".join(qargs)))

def phaser_wrapper (args) :
  started_phaser = False;
  exit_code = 0
  if (len(args) == 0) :
    exit_code = run_binary(args)
    started_phaser = True
  elif "--version" in args :
    exit_code = run_binary(args)
    started_phaser = True
  elif "--changelog" in args :
    exit_code = run_binary(args)
    started_phaser = True
  elif "--phenix" in args :
    exit_code = run_binary(args)
    started_phaser = True
  elif "--help" in args or "--options" in args or "--usage" in args :
    started_phaser = False
  elif "--show-defaults" in args :
    from phaser import phenix_interface
    phenix_interface.master_phil().show()
    started_phaser = True
  elif (len(args) > 0) :
    from phaser.phenix_interface import driver
    driver.run(args)
    started_phaser = True
  if not started_phaser :
    raise Usage("""
phenix.phaser is a multi-function command: it can launch either the binary
version, which accepts CCP4-style keyword input, or the Python version, which
uses the standard Phenix configuration file syntax.  If called with no
arguments or the recognized command-line flags, the binary will be launched;
if a valid Phenix configuration file is provided on the command line, it
will run the Python version.

CCP4 style:
  phenix.phaser
  phenix.phaser [--version]
  phenix.phaser [--changelog]

Phenix style:
  phenix.phaser [params.eff] [<param_name>=<param_value> ...]
  phenix.phaser --show_defaults
""")
  sys.exit(exit_code)

if __name__ == "__main__" :
  phaser_wrapper(sys.argv[1:])
