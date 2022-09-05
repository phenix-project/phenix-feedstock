from __future__ import print_function
import os, sys
import pickle

from elbow.utilities import looping_utils
from elbow.utilities import Utilities
from elbow.chemistry import ChiralClass

#from mmtbx.monomer_library import linking_utils

class saccharide_manager(object):
  def __init__ (self):
    pass

  def __call__ (self, chemical_components_code) :
    # the actual implementation is elsewhere
    return process_saccharide( chemical_components_code )

def run_all (
             codes,
             method="multiprocessing",
             processes=1,
             qsub_command=None,
             callback=None,
             ) :
  matcher = saccharide_manager()
  from libtbx.easy_mp import parallel_map
  return parallel_map(
    func=matcher,
    iterable=codes,
    method=method,
    processes=processes,
    callback=callback,
    qsub_command=qsub_command,
    )

def get_anomeric_carbon(mol,
                        strict=True, # only, C, O, H and no S
                        return_ring_element=False,
                       ):
  for carbon, connections in mol.AtomsWithSymbol("C", sort_on_atom_name=True):
    print(carbon) #, connections
    if len(connections.get("O", []))!=2: continue
    if return_ring_element: return "O"
    return carbon
  if strict: return None
  assert 0
  for carbon, connections in mol.AtomsWithSymbol("C"):
    if ( len(connections.get("S", []))==1 and
         len(connections.get("O", []))==1):
      if return_ring_element:
        if mol.isRingAtom(connections["S"]):
          return "S"
        return "O"
      return carbon
  return None

def get_ring_oxygen(mol, anomeric_carbon=None):
  rc = None
  if anomeric_carbon is None: anomeric_carbon = get_anomeric_carbon(mol)
  ring_element = get_anomeric_carbon(mol, return_ring_element=True)
  for oxygen, connections in mol.AtomsWithSymbol(ring_element):
    if len(connections.get("C", []))!=2: continue
    if not anomeric_carbon in connections.get("C", []): continue
    if not mol.isRingAtom(oxygen): continue
    rc = oxygen
    break
  return rc

def get_link_oxygen(mol, anomeric_carbon=None, verbose=False):
  rc = None
  if verbose: print('anomeric_carbon', anomeric_carbon)
  if anomeric_carbon is None: anomeric_carbon = get_anomeric_carbon(mol)
  if verbose: print('anomeric_carbon',anomeric_carbon)
  ring_element = get_anomeric_carbon(mol, return_ring_element=True)
  if verbose: print('ring_element',ring_element)
  for oxygen, connections in mol.AtomsWithSymbol(ring_element):
    if verbose: print('oxygen 2',oxygen)
    if not anomeric_carbon in connections.get("C", []): continue
    if verbose: print('oxygen 3',oxygen)
    if mol.isRingAtom(oxygen): continue
    if verbose: print('oxygen 4',oxygen)
    rc = oxygen
    break
  return rc

def get_reference_carbon(mol, anomeric_carbon=None):
  def _generate_reference_centres(mol,
                                  oxygen,
                                  anomeric_carbon,
                                  done=None,
                                  ):
    if done is None:
      done = [oxygen, anomeric_carbon]
    tries=0
    while 1:
      print(tries, done)
      tries+=1
      if tries>20:break
      for ba in oxygen.bonded:
        if ba.isH(): continue
        if ba in done: continue
        if not mol.isRingAtom(ba): continue
        yield ba
        oxygen = ba
        if anomeric_carbon in oxygen.bonded: return
        done.append(ba)

  if anomeric_carbon is None: anomeric_carbon = get_anomeric_carbon(mol)
  # in case of thio but seems to ruin reference R/S
  ring_element = get_anomeric_carbon(mol, return_ring_element=True)
  oxygen = get_ring_oxygen(mol, anomeric_carbon)
  for ba in _generate_reference_centres(mol, oxygen, anomeric_carbon):
    if len(ba.bonded)!=4: continue
    hydrogens=0
    for aa in ba.bonded:
      if aa.isH(): hydrogens+=1
    if hydrogens>1: continue
    break
  return ba

def get_chiral(mol, atom):
  def _standard_order(atom1, atom2):
    # hydrogen
    if atom1.isH() and atom2.isH(): assert 0
    if atom1.isH(): return -1
    elif atom2.isH(): return 1
    # sort oxygens
    if atom1.symbol=="O" and atom2.symbol=="O":
      if atom1 is get_ring_oxygen(mol, atom): return 1
      elif atom2 is get_ring_oxygen(mol, atom): return -1
    elif atom1.symbol=="O": return -1
    elif atom2.symbol=="O": return 1
    # sort carbons linked to reference carbon
    if atom1.symbol=="C" and atom2.symbol=="C":
      if mol.isRingAtom(atom1): return -1
      elif mol.isRingAtom(atom2): return 1
    return 0
  atoms = []
  for ba in atom.bonded:
    atoms.append(ba)
  atoms.sort(_standard_order)
  atoms.insert(1, atom)
  cc = ChiralClass.ChiralClass(atoms)
  print(cc)
  print(cc.GetChiralVolume())
  for i, atom in enumerate(atoms):
    atoms[i]=atom.name.strip()
  return cc, atoms

class empty(object):
  def __init__(self):
    self.linear = []
    self.multiple = []
    self.names = {}
    self.done = []
    self.hands = {}
    self.volumes = {}
    self.polymer = {}
    self.chiral_atoms = {}
    self.identifiers = {}

  def __repr__(self):
    outl = "empty"
    for attr in sorted(self.__dict__):
      outl += "\n  %s" % attr
      outl += "\n    %s" %  getattr(self, attr)
    return outl

  def __iadd__(self, other):
    if other is None: return self
    print('__iadd__',self,other)
    for attr in sorted(self.__dict__):
      if type(getattr(self, attr))==type([]):
        s = getattr(self, attr)
        o = getattr(other, attr)
        for item in o:
          if item not in s: s.append(item)
      if type(getattr(self, attr))==type({}):
        s = getattr(self, attr)
        o = getattr(other, attr)
        s.update(o)
    return self

  def process_names(self):
    def _match_sacchadride_strings(s1, s2, pairs):
      s1=s1.lower()
      s2=s2.lower()
      for m1, m2 in pairs:
        if s1.find(m1)>-1 and s2.find(m2)>-1:
          s1 = s1.replace(m1,"")
          s2 = s2.replace(m2,"")
          if s1==s2: return True
      return False
    def _match_alpha_beta(s1, s2):
      return _match_sacchadride_strings(s1,
                                        s2,
                                        [["alpha-l", "beta-l"],
                                         ["alpha-d", "beta-d"],
                                         ["beta-d", "alpha-d"],
                                         ["beta-l", "alpha-l"],
                                        ])
    def _match_l_d(s1, s2):
      return _match_sacchadride_strings(s1,
                                        s2,
                                        [["alpha-l", "alpha-d"],
                                         ["alpha-d", "alpha-l"],
                                         ["beta-d", "beta-l"],
                                         ["beta-l", "beta-d"],
                                        ])
    #
    ab={}
    ld={}
    for i, key1 in enumerate(sorted(self.names)):
      for j, key2 in enumerate(sorted(self.names)):
        if i==j: break
        if _match_alpha_beta(self.names[key1], self.names[key2]):
          if self.names[key1].lower().find("alpha")>-1:
            ab[key1]=key2
          else:
            ab[key2]=key1
        if _match_l_d(self.names[key1], self.names[key2]):
          if self.names[key1].lower().find("-l-")>-1:
            ld[key1]=key2
          else:
            ld[key2]=key1
    return ab, ld

def get_header_field(code, field):
  header = Utilities.get_header_from_chemical_components(code)
  name = ''
  for line in header.split("\n"):
    if line.find(".%s" % field)>-1:
      name = line.split()[1]
      name = name.replace('"',"")
      break
  else: assert 0
  return name

def get_polymer(mol, anomeric_carbon=None):
  # currently only for C1
  # need C2???
  if anomeric_carbon is None: anomeric_carbon = get_anomeric_carbon(mol)
  oxygen=get_link_oxygen(mol, anomeric_carbon=anomeric_carbon)
  if oxygen is None: return False
  count=0
  for ba in oxygen.bonded:
    if ba.isH(): continue
    if ba is anomeric_carbon: continue
    print(ba)
    count+=1
  return not count

def standardise_molecule(molecule):
  lookups = {
    "F" : "H",
    "S" : "O"
    }
  for atom in molecule:
    if atom.symbol in lookups:
      atom.symbol = lookups[atom.symbol]
  for atom in molecule:
    print(atom)
    assert atom.symbol in ["C", "H", "O",
                           "N", "P"], (atom, atom.resName)
  return molecule

def generate_carbon_in_order(mol):
  # based on name
  for i in range(1,9):
    name = "C%s" % i
    for carbon, connections in mol.AtomsWithSymbol("C"):
      if carbon.name.strip().find(name)==-1: continue
      yield carbon, connections

def flatten_ring_and_put_in_xy_plane(mol):
  atom_selection = []
  for atom in mol:
    if not mol.isRingAtom(atom): continue
    else:
      atom_selection.append(atom)
    # atom.xyz.z = 0
  mol.planar_atom_selection = atom_selection
  mol.OptimiseToXYPlane()
  for atom in atom_selection:
    z = atom.xyz.z
    atom.xyz.z=0
    for ba in atom.bonded:
      print(ba)
      if mol.isRingAtom(ba): continue
      ba.xyz.z -= z
  return mol

def get_fischer_projection(mol):
  # only mono cyclic
  mol = flatten_ring_and_put_in_xy_plane(mol)
  for carbon, connections in generate_carbon_in_order(mol):
    if not mol.isRingAtom(carbon): continue
    print(carbon) #, connections

def process_saccharide(code):
  print('process_saccharide',code)
  holder = empty()
  code = code.upper()
  mol = Utilities.get_elbow_molecule_from_chemical_components(code)
  mol.SetCCTBX(True)
  mol.UpdateBonded()
  for atom in mol:
    atom.input_xyz = atom.xyz
  mol.Ringise()
  for atom in mol:
    atom.xyz = atom.input_xyz
  print(mol.DisplayBrief())
  if len(mol.ring_class)==0:
    holder.linear.append(code)
    return holder
  elif len(mol.ring_class)>1:
    holder.multiple.append(code)
    return holder
  name = get_header_field(code, "name")
  identifiers = Utilities.get_any_cif_field(code, '_pdbx_chem_comp_identifier', 'identifier')
  holder.names[code]=name
  if not identifiers: identifiers=[]
  holder.identifiers[code]=identifiers
  #
  try: mol = standardise_molecule(mol)
  except:
    print('failed to standardise_molecule')
    return None
  # get_fischer_projection(mol)
  #
  anomeric_carbon = get_anomeric_carbon(mol)
  print('anomeric_carbon',anomeric_carbon)
  try: cc1, atoms1 = get_chiral(mol, anomeric_carbon)
  except: return holder
  holder.chiral_atoms[code]=atoms1
  rs1 = cc1.GetRSNotation()
  reference_carbon = get_reference_carbon(mol,
                                          anomeric_carbon=anomeric_carbon)
  print('reference_carbon',reference_carbon)
  cc2, atoms2 = get_chiral(mol, reference_carbon)
  rs2 = cc2.GetRSNotation()
  assert rs1
  assert rs2
  if rs1==rs2:
    hand = "alpha"
  else:
    hand = "beta"
  print('hand',hand)
  holder.hands[code]=hand
  holder.volumes[code]=cc1.GetChiralVolume()
  holder.polymer[code]=get_polymer(mol)
  # print holder; assert 0
  other_hand = {'alpha':'beta','beta':'alpha'}[hand]
  for name in [holder.names[code]] + holder.identifiers[code]:
    print('NAME',name)
    if (name.upper().find("%s-D" % other_hand.upper())>-1 or
        name.upper().find("%s-L" % other_hand.upper())>-1):
      print('OVERWRITE %s "%s" using name %s' % (code, hand, name))
      holder.hands[code]={'alpha':'beta','beta':'alpha'}[hand]
      holder.names[code]=name
      break
  return holder

def run(only_i=None,
        only_code=None,
        nproc=1,
       ):
  try: only_i=int(only_i)
  except: only_i=None
  if only_code in ["None"]: only_code=None
  try: nproc=int(nproc)
  except: nproc=1
  pickle_filename = "saccharide_hands.pickle"
  try:
    f = open(pickle_filename, 'r')
    holder = pickle.load(f)
    f.close()
  except:
    holder = empty()

  for attr in holder.__dict__:
    if attr in ["done"]: continue
    for key in getattr(holder, attr):
      if key not in holder.done:
        holder.done.append(key)

  if nproc>1:
    results = run_all(looping_utils.generate_code_by_type(saccharide=True,
                                                          #only_code=only_code,
                                                          #max_results=100,
                                                          #verbose=True,
                                                      ),
                      processes=nproc,
                  )
    print(results)
  else:
    results = []
    print(holder.done)
    for i, code in enumerate(looping_utils.generate_code_by_type(
          saccharide=True,
          only_code=only_code,
          )):
      if only_i is not None and only_i!=i+1: continue
      if code in holder.done: continue
      rc = process_saccharide(code)
      #print '-'*80
      #print holder
      if rc is None:
        print('\n\tFailed to get data')
        continue
      print('-'*80)
      holder += rc
      holder.done.append(code)
      print(len(holder.done))
      print('-'*80)
      if i%10==9:
        f = open(pickle_filename, 'w')
        pickle.dump(holder, f)
        f.close()
        # break
      print(rc)

  for h in results:
    print('h',h)
    holder += h
  #print holder

  f = open(pickle_filename, 'w')
  pickle.dump(holder, f)
  f.close()

  ab, ld = holder.process_names()
  print()
  print('Alpha/Beta')
  for key in sorted(ab):
    try:
      print("  %s : %s | %4.1f : %4.1f" % (key,
                                           ab[key],
                                           holder.volumes.get(key),
                                           holder.volumes.get(ab[key]),
                                          ))
    except:
      print("  %s : %s | %s : %s" % (key,
                                     ab[key],
                                     holder.volumes.get(key),
                                     holder.volumes.get(ab[key]),
                                    ))
  print()
  print('L/D')
  for key in sorted(ld):
    print("  %s : %s | %4.1f : %4.1f" % (key,
                                         ld[key],
                                         holder.volumes.get(key),
                                         holder.volumes.get(ld[key]),
                                         ))
  print()

  print('Hand Volume')
  for hand, sign in [ [ "alpha",  1],
                      [ "beta",  -1],
                      [ "alpha", -1],
                      [ "beta",   1],
                    ]:
    printed = 0
    for key in holder.hands:
      if holder.hands[key]!=hand: continue
      volume = holder.volumes.get(key, 0)
      if volume is None: assert 0
      if volume==0: assert 0
      if abs(volume/abs(volume)-sign)>.1: continue
      print("  %s %-5s %4.1f" % (key,
                                 holder.hands[key],
                                 volume,
                                 ))
      printed +=1
    print('-',printed)

  print('-'*80)
  outl = """from __future__ import absolute_import, division, print_function

volumes = {"""
  #
  for key in sorted(holder.volumes):
    outl += "\n  '%s' : %5.1f," % (key,holder.volumes[key])
  outl += "\n}"
  #
  outl += """
alpha_beta = {"""
  for key in sorted(holder.hands):
    outl += "\n  '%s' : '%s'," % (key,holder.hands[key])
  outl += "\n}"
  outl += """

if __name__=="__main__":
  for code in ["MAN",
               "BMA",
               "NAG",
               "FUL",
               "FUC",
              ]:
    print(code, alpha_beta.get(code, None),volumes.get(code, None))
"""
  print(outl)
  f = open("glyco_chiral_values.py", 'w')
  f.write(outl)
  f.close()

  # ALL code
  print(holder)
  outl = "carb_names = ["
  for attr in [
      "linear",
      "multiple",
      "names",
      ]:
    print('attr',attr)
    outl += "\n  # %s" % attr
    for code in sorted(getattr(holder, attr, [])):
      outl += '\n  "%s",' % code
  outl += "\n]"
  print(outl)
  f = open("all_glyco_codes.py", 'w')
  f.write(outl)
  f.close()

if __name__=="__main__":
  args = sys.argv[1:]
  del sys.argv[1:]
  run(*tuple(args))
