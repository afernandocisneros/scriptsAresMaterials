#!/bin/bash

#---------------#
#   OpenBabel   #
#---------------#

# Genetic Algorithm
#obabel -i smi *.smi -o xyz -O input.xyz --gen3d
#obabel input.xyz -O conformers.xyz --conformer --nconf 500 --ff UFF \
#			        --children 5 --mutability 5 --score rmsd \
#                               --writeconformers

# Oconformer
# Usage: obconformer NSteps GeomSteps <file> [forcefield]
# obconformer 250 100 input.xyz > obconformer.out

# Confab
obabel -i smi *.smi -o xyz -O input.xyz --gen3d
obabel input.xyz -O conformers.xyz --confab --conf 100000 --orignal --rcutoff 0.5 --ecutoff 50 > confab_output.txt

sed -i '$ d' confab_output.txt
genConfor=$(cat confab_output.txt | tail -1 | awk '{print $2}')
limitConfor=800

if [ "$genConfor" -lt "$limitConfor" ]; then

echo "Number of conformers: $genConfor"

#---------------#
#     Mopac     #
#---------------#

atoms=$(head -n 1 conformers.xyz)
ato=$((atoms-1))
conf_firstAtom=($(cat -n conformers.xyz | grep 'input.xyz' | awk '{print $1+1}'))
conformers=(${#conf_firstAtom[@]})


mkdir conformers
echo "# Conformer       Energy" > conformers/energyVSconf.txt

for (( i=0; i<$conformers; i++ ))
do
   mkdir conformers/conf_$i

   echo "PM7 opt" > conformers/conf_$i/conf_$i.mop
   echo "Semiempirical calculation" >> conformers/conf_$i/conf_$i.mop
   echo " " >> conformers/conf_$i/conf_$i.mop
 
   conf_lastAtom=$( echo "${conf_firstAtom[$i]}+$ato" | bc -l )
   sed -n "${conf_firstAtom[$i]}, $conf_lastAtom p" conformers.xyz >> conformers/conf_$i/conf_$i.xyz
   sed -n "${conf_firstAtom[$i]}, $conf_lastAtom p" conformers.xyz >> conformers/conf_$i/conf_$i.mop
   
   /opt/mopac/MOPAC2016.exe conformers/conf_$i/conf_$i.mop
   echo ":D"

   # Extraction of energy
   echo -n "$i            " >> conformers/energyVSconf.txt
   cat conformers/conf_$i/conf_$i.out | grep "TOTAL ENERGY" | awk '{print $4}' >> conformers/energyVSconf.txt

done

else
   echo "El numero de conformeros generados: $genConfor, es mayor al limite: $limitConfor."
   exit
fi



#---------------#
#    Gnuplot    #
#---------------#

# Plot Energy vs Number of conformer with Gnuplot
echo "set terminal eps enhanced" >> conformers/plot_Energy_vs_Conformer.gnu
echo "set output 'energyVSconformer.eps'" >> conformers/plot_Energy_vs_Conformer.gnu
echo "set xlabel 'Conformers'" >> conformers/plot_Energy_vs_Conformer.gnu
echo "set ylabel 'Energy (eV)'" >> conformers/plot_Energy_vs_Conformer.gnu
echo "set xtics 1" >> conformers/plot_Energy_vs_Conformer.gnu
echo "set grid" >> conformers/plot_Energy_vs_Conformer.gnu
echo "unset key" >> conformers/plot_Energy_vs_Conformer.gnu
echo "plot 'energyVSconf.txt' u 1:2 w lp pt 7 ps 0.5 lc rgb 'blue'" >> conformers/plot_Energy_vs_Conformer.gnu

cd conformers/
gnuplot plot_Energy_vs_Conformer.gnu
cd ..

#---------------#
#     Orca      #  
#---------------#

mkdir orca

# Index of minimum energy conformer
c=$(sort -k2 -n conformers/energyVSconf.txt | head -n 1 | awk '{print $1}')

echo "# Orca calculation" > orca/minenergyConformer.inp
echo "! B3LYP 6-31++G** Grid4 FinalGrid5 TightOpt Opt Freq" >> orca/minenergyConformer.inp
echo " " >> orca/minenergyConformer.inp
echo "# Number of procs" >> orca/minenergyConformer.inp
echo "%pal" >> orca/minenergyConformer.inp
echo "   nprocs 12" >> orca/minenergyConformer.inp
echo "end" >> orca/minenergyConformer.inp
echo "  " >> orca/minenergyConformer.inp
echo "# Polarizability" >> orca/minenergyConformer.inp
echo "%elprop" >> orca/minenergyConformer.inp
echo "   Polar 1 " >> orca/minenergyConformer.inp
echo "end" >> orca/minenergyConformer.inp
echo "  " >> orca/minenergyConformer.inp
echo "# Cartesian Coordinates in Angstroms" >> orca/minenergyConformer.inp
echo "* xyz 0 1" >> orca/minenergyConformer.inp

fA=$(cat -n conformers/conf_$c/conf_$c.out | grep "                            CARTESIAN COORDINATES" | awk '{print $1}')

firstAtom=$((fA+2))
lastAtom=$( echo "$firstAtom+$ato" | bc -l )
#lastAtom=$((firstAtom+ato))

sed -n "$firstAtom, $lastAtom p" conformers/conf_$c/conf_$c.out >> temporal.txt
cat temporal.txt | awk '{print $2 "          " $3 "   " $4 "   " $5}' >> orca/minenergyConformer.inp
rm temporal.txt

echo "*" >> orca/minenergyConformer.inp

mv orca/minenergyConformer.inp orca/minenergyConformer_$c.inp

echo "Orca calculating..."
/home/fernando/Orca/orca_4_2_1_linux_x86-64_openmpi314/orca orca/minenergyConformer_$c.inp > orca/minenergyConformer_$c.out &

#-----------------------#
echo " "
echo "Finish! Shoo shoo"
#-----------------------#
