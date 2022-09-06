#!/usr/bin/python

#TO DO: Send and retrieve HHpred request (other script)
#get the right chain number
#Handle Errors, Writing Directory suppressing
#Phaser send & sort script


#Start date: 18 May 2016, Nicolas.
#Update : 14 March 2017, parse SEQRES record for correct numbering
#Script to parse a list from a HHpred output HTML list
# It downloads all relevant PDB files directly from the PDB and places them in a 'pdb' folder

#Modules to import
from __future__ import print_function
import re
import sys
import urllib2
import os

##############################################################
dicRes={"ALA":'A',"CYS":'C',"ASP":'D',"GLU":'E',"PHE":'F',"GLY":'G',"HIS":'H',"ILE":'I',"LYS":'K',"LEU":'L',"MET":'M',"ASN":'N',"PRO":'P',"GLN":'Q',"ARG":'R',"SER":'S',"THR":'T',"VAL":'V',"TRP":'W',"TYR":'Y',"MSE":'M'}
##############################################################

def findShift(seq1="HHACNMQVWATG",seq2="ACNMQVWATG",window=7):
        """Compares the starting sequence of seqres with the starting sequence of the PDB and returns the residue to start with in the ATOM record"""
        decalage=0
        seqtmp=seq1
        print("Seq1: %s...\nseq2:  %s..."%(seq1,seq2))
        Error=False
        for i in range(len(seq1)):
                if (window<=len(seq2) and window <= len(seqtmp)):
                        if seqtmp[0:window] == seq2[0:window]:
                                decalage=i
                                break
                        else:
                                seqtmp=seqtmp[1:]

                else:
                        Error=True

        if Error:
                print("No match between SEQRES and ATOM records from the 'findShift' function !")
                print("restarting with a smaller window (%s)"%window)
                window=window -1

                if window>2:
                        return findShift(seq1=seq1,seq2=seq2,window=window)
                else:
                        print("Could not find any match between SEQRES and ATOM records :-(\n Shift set to 0, please inspect this PDB sequence")
                        return 0
        else:
                return decalage

#Parsing the HHpred output HTML list
try:
        fileName=sys.argv[1]                                                    #File name from the command line argument
except:
        print("Usage: python parseHHpred.py myfileFromHHpred.hhr (or html)")
        sys.exit(0)

HHpredfile=open(fileName,'r')                                           #Opening the file to parse

check=0                                                                 #variable on off to parse the file
pdblist=[]                                                              #list of hashes containing all pdb ids to download (1 hash= 1 pdb)
currentline=[]                                                          #variables to store pdbid, borders
currpdb=""
currborders=""



#looping over the lines of the input file
for line in HHpredfile:
        if re.match(' No Hit',line): check=1                            #if the line with " No Hit" at the beginning is reached, turn on check
        elif re.match('(\s+|\d){2}\d',line) and check==1:               #retrieve the pdb id

                currentline=line.split()                                #split the current line with white spaces (default)
                currpdb=currentline[1]                                  #extract pdb id
                pdbid=currpdb[0:4]
                pdbchain=currpdb[5]


                currentline.reverse()                                   #reverse the line to avoid white space problems to extract the borders
                currborders=currentline[1].split('-')                   #extract the borders

                start=int(currborders[0])
                end=int(currborders[1])

                #append the pdbchain, pdbid, start, end, as a hash added to the list of pdb files
                pdblist.append({"id":pdbid, "chain": pdbchain, "start":start, "end":end})

        elif re.match(' No',line):
                check=0                                                 #ignore all other lines


#Now going through the list of PDB files, download and cut them according to the matching bits in HHPred.
#useful variable(s)
page="http://files.rcsb.org/view/"

#regular expressions:
ATOM=re.compile('^(ATOM  |HETATM|ANISOU)')
NITROGEN=re.compile('^(ATOM  |HETATM)[\s\d]{5}\s{2}N\s{2}[\sA](\w{3})\s(.{1})')                         #regexp to count +1 at each new residue (nitrogen atom)
OTHER=re.compile("(^HEADER|^TITLE|^COMPND|^SEQRES|^SOURCE|^KEYWDS|^EXPDTA|^AUTHOR|^REVDAT|^JRNL|^CRYST1|^ORIGX[123]|^SCALE[123]|^END)")
seqresExpr=re.compile("^SEQRES .{3} (.{1}).{7}(.*)")
#creating output directory
outputFolder="TMP"

if not os.path.isdir("HHpred_trimmed_pdb"):
        outputFolder = "HHpred_trimmed_pdb"
else:
        print("directory HHpred_trimmed_pdb already exists!, writing in TMP")

os.makedirs(outputFolder)



#looping through the structure list and trimming..
for structure in pdblist:

        print("downloading and trimming "+structure["id"]+" (chain "+structure["chain"]+") between residues "+str(structure["start"])+" and "+str(structure["end"]))

        fichier = list(urllib2.urlopen(page+structure["id"]+".pdb"))            #load pdb file in memory (file-like object), transformed into list, otherwise exhausted by the first loop
#       tmpout=open(outputFolder+"/"+structure["id"]+".pdb",'w') # NS TMP
#       for line in fichier:
#               tmpout.write(line)


        output=open(outputFolder+"/"+structure["id"]+"_hhprd.pdb",'w')          #output file for trimmed pdb

        n=0                                                             #counter for residues in pdb file

        seqRes=""
        #parsing the downloaded pdb file object line by line

        #first round
        #passSeq=False  #to take only the first SEQRES record
        k=0
#       l=0                        #to take only the first 10 aa of the PDB ATOM records for
        oneletterseqres=""
        oneletterPDBseq=""

        for line in fichier:
                #First going through the SEQRES records which serve as a reference for the HHpred numbering take the begining of the SEQRES only
                m1=seqresExpr.match(line)
                m2=NITROGEN.match(line)

                if m1:

                        if m1.group(1) == structure["chain"]:
                                secuencia=m1.group(2)
                                for aminoacid in secuencia.strip().split(" "):
                                        if aminoacid in dicRes:
                                                oneletterseqres+=dicRes[aminoacid]
                                        else:
                                                oneletterseqres+="X"
                #               l+=1 #Only the first 2 SEQRES record is necessary


                elif m2 and k<10:
                        if m2.group(3) == structure["chain"]:
                                aminoacid2=m2.group(2)
                                if aminoacid2 in dicRes:
                                        oneletterPDBseq+=dicRes[aminoacid2]
                                else:
                                        oneletterPDBseq+="X"
                                k+=1
                elif k>=10:
                        break

        #shift between sequences
        leShift=findShift(seq1=oneletterseqres,seq2=oneletterPDBseq)
        print("PDB %s SHIFT BETWEEN SEQUENCES %s \n"%(structure["id"],leShift))
        structure["start"]-=leShift
        structure["end"]-=leShift

        #Second round
        goodchain=False
        for line in fichier:

                m3=ATOM.match(line)
                m4=NITROGEN.match(line)
                m5=OTHER.match(line)

                if m3:

                        if m4 and m4.group(3)==structure["chain"]:  #count residue number at each Nitrogen backbone atom
                                n+=1
                                goodchain=True

                        if (n >= structure["start"] and n<= structure["end"] and goodchain):
                                output.write(line)
                        else:
                                goodchain=False

                elif m5:
                        output.write(line)

        #fichier.close()
        output.close()
