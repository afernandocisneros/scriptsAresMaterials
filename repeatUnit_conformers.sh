#!/bin/bash

#---------------#
#   OpenBabel   #
#---------------#

# Conversion smile to xyz file
# obabel -i smi *.smi -o xyz -O input.xyz --gen3d

# Genetic Algorithm
obabel input.xyz -O conformers_ga.xyz --conformer --nconf 3 --ff --score energy --writeconformers > geneticAlgorithm.txt

# Oconformer for generate random conformers using a Monte Carlo search
# Usage: obconformer NSteps GeomOptSteps <file> [forcefield]
# obconformer #ofconformers #ofoptimizationsteps filename 
obconformer 10 100 input.xyz > obconformer.xyz
sed -i 's/^$/input.xyz/g' obconformer.xyz

# Confab
obabel input.xyz -O conformers_confab.xyz --confab --conf 100 --orignal --rcutoff 1.0 --ecutoff 100 --writeconformers > confab_output.txt

# Union conformers coordinates 
cat conformers_ga.xyz      > conformers.xyz
cat obconformer.xyz       >> conformers.xyz
cat conformers_confab.xyz >> conformers.xyz

# Count number of conformers generated
totalConformers=$(cat conformers.xyz | grep 'input.xyz' | wc -l)

sed -i '$ d' confab_output.txt
genConfor=$(cat confab_output.txt | tail -1 | awk '{print $2}')
limitConfor=1000

if [ "$genConfor" -ge "1" ] && [ "$genConfor" -lt "$limitConfor" ]; then

echo "Number of conformers generated by confab: $genConfor"
echo " "
echo "Total Number of conformers: $totalConformers"

#---------------#
#     Mopac     #
#---------------#

echo ""
echo "#--------------------------------#"
echo "   Mopac calculating conformers"
echo "#--------------------------------#"
echo ""

atoms=$(head -n 1 conformers.xyz)
ato=$((atoms-1))
conf_firstAtom=($(cat -n conformers.xyz | grep 'input.xyz' | awk '{print $1+1}'))
conformers=(${#conf_firstAtom[@]})


mkdir conformers
#echo "# Conformer       Energy" > conformers/energyVSconf.txt

for (( i=0; i<$conformers; i++ ))
do
   mkdir conformers/conf_$i
   
   #relscf=1.0
   echo "PM7 THREADS=2 gnorm=10 polar dipole opt" > conformers/conf_$i/conf_$i.mop
   echo "Semiempirical calculation" >> conformers/conf_$i/conf_$i.mop
   echo " " >> conformers/conf_$i/conf_$i.mop
 
   conf_lastAtom=$( echo "${conf_firstAtom[$i]}+$ato" | bc -l )
   sed -n "${conf_firstAtom[$i]}, $conf_lastAtom p" conformers.xyz >> conformers/conf_$i/conf_$i.xyz
   sed -n "${conf_firstAtom[$i]}, $conf_lastAtom p" conformers.xyz >> conformers/conf_$i/conf_$i.mop
   
   /opt/mopac/MOPAC2016.exe conformers/conf_$i/conf_$i.mop

   # ------------------------------------- #
   # Extraction of properties at PM7 level #
   # ------------------------------------- #

   # Cosmo volume in ANG**3
   echo -n "$i            "                                                               >> conformers/cosmoVolumeVSconf.txt
   cat conformers/conf_$i/conf_$i.out | grep 'COSMO VOLUME' | awk '{print $4}'            >> conformers/cosmoVolumeVSconf.txt

   # HOMO Energies in eV
   echo -n "$i            "                                                               >> conformers/homoVSconf.txt
   cat conformers/conf_$i/conf_$i.out | grep 'HOMO' | awk '{print $6}'                    >> conformers/homoVSconf.txt
   
   # LUMO Energies in eV
   echo -n "$i            "                                                               >> conformers/lumoVSconf.txt
   cat conformers/conf_$i/conf_$i.out | grep 'LUMO' | awk '{print $7}'                    >> conformers/lumoVSconf.txt
   
   # Polarizability in ANG**3
   echo -n "$i            "                                                               >> conformers/alphaVSconf.txt
   cat conformers/conf_$i/conf_$i.out | grep 'ISOTROPIC' | tail -1 | awk '{print $8}'     >> conformers/alphaVSconf.txt
   
   # Dipole Moment in Debye
   echo -n "$i            "                                                               >> conformers/dipoleMomentVSconf.txt
   cat conformers/conf_$i/conf_$i.out | grep 'SUM' | awk '{print $5}'                     >> conformers/dipoleMomentVSconf.txt

   # Total Energy in eV
   echo -n "$i            "                                                               >> conformers/energyVSconf.txt
   cat conformers/conf_$i/conf_$i.out | grep "TOTAL ENERGY" | awk '{print $4}'            >> conformers/energyVSconf.txt
   
   # Heat of formation in Kcal/mol
   echo -n "$i            "                                                               >> conformers/heatVSconf.txt
   cat conformers/conf_$i/conf_$i.out | grep "FINAL HEAT OF FORMATION" | awk '{print $6}' >> conformers/heatVSconf.txt

done

else
   echo "El numero de conformeros generados: $genConfor, es mayor al limite: $limitConfor."
   exit
fi


#---------------#
#    Gnuplot    #
#---------------#

# Cosmo Volume vs Conformer 
echo "set terminal eps enhanced"             > conformers/plot_cosmoVolume_vs_Conformer.gnu
echo "set output 'cosmoVolVSconformer.eps'" >> conformers/plot_cosmoVolume_vs_Conformer.gnu
echo " "                                    >> conformers/plot_cosmoVolume_vs_Conformer.gnu
echo "set multiplot layout 2,1"             >> conformers/plot_cosmoVolume_vs_Conformer.gnu
echo " "                                    >> conformers/plot_cosmoVolume_vs_Conformer.gnu
echo "set xlabel 'Conformers'"              >> conformers/plot_cosmoVolume_vs_Conformer.gnu
echo "set ylabel 'Cosmo Volume (ANG**3)'"   >> conformers/plot_cosmoVolume_vs_Conformer.gnu
echo "set xtics 5 font ',8' rotate by 80 offset 0.0,-0.8"   >> conformers/plot_cosmoVolume_vs_Conformer.gnu
echo "set grid"                             >> conformers/plot_cosmoVolume_vs_Conformer.gnu
echo "unset key"                            >> conformers/plot_cosmoVolume_vs_Conformer.gnu
echo "plot 'cosmoVolumeVSconf.txt' u 1:2 w lp pt 7 ps 0.2 lc rgb 'blue'" >> conformers/plot_cosmoVolume_vs_Conformer.gnu
echo " "                                    >> conformers/plot_cosmoVolume_vs_Conformer.gnu
echo "unset xtics"                          >> conformers/plot_cosmoVolume_vs_Conformer.gnu
echo "set xlabel 'Cosmo Volume (ANG**3)'"   >> conformers/plot_cosmoVolume_vs_Conformer.gnu
echo "set ylabel 'Number of Conformers'"    >> conformers/plot_cosmoVolume_vs_Conformer.gnu
echo "set xtics 5 font ',8' rotate by 80 offset 0.0,-1.2"   >> conformers/plot_cosmoVolume_vs_Conformer.gnu
echo "set grid"                             >> conformers/plot_cosmoVolume_vs_Conformer.gnu
echo "unset key"                            >> conformers/plot_cosmoVolume_vs_Conformer.gnu
echo "set style fill solid 0.5"             >> conformers/plot_cosmoVolume_vs_Conformer.gnu
echo "binwidth=5"                           >> conformers/plot_cosmoVolume_vs_Conformer.gnu
echo "bin(x,width)=width*floor(x/width)"    >> conformers/plot_cosmoVolume_vs_Conformer.gnu
echo "set style data histogram"             >> conformers/plot_cosmoVolume_vs_Conformer.gnu
echo "plot 'cosmoVolumeVSconf.txt' using (bin(\$2,binwidth)):(1.0) smooth freq with boxes lc rgb '#008000'" >> conformers/plot_cosmoVolume_vs_Conformer.gnu
echo "unset multiplot"                      >> conformers/plot_cosmoVolume_vs_Conformer.gnu

# HOMO Energy vs Conformer 
echo "set terminal eps enhanced"             > conformers/plot_homoE_vs_Conformer.gnu
echo "set output 'homoVSconformer.eps'"     >> conformers/plot_homoE_vs_Conformer.gnu
echo " "                                    >> conformers/plot_homoE_vs_Conformer.gnu
echo "set multiplot layout 2,1"             >> conformers/plot_homoE_vs_Conformer.gnu
echo " "                                    >> conformers/plot_homoE_vs_Conformer.gnu
echo "set xlabel 'Conformers'"              >> conformers/plot_homoE_vs_Conformer.gnu
echo "set ylabel 'HOMO Energy (eV)'"        >> conformers/plot_homoE_vs_Conformer.gnu
echo "set xtics 5 font ',8' rotate by 80 offset 0.0,-0.8"   >> conformers/plot_homoE_vs_Conformer.gnu
echo "set grid"                             >> conformers/plot_homoE_vs_Conformer.gnu
echo "unset key"                            >> conformers/plot_homoE_vs_Conformer.gnu
echo "plot 'homoVSconf.txt' u 1:2 w lp pt 7 ps 0.2 lc rgb 'blue'" >> conformers/plot_homoE_vs_Conformer.gnu
echo " "                                    >> conformers/plot_homoE_vs_Conformer.gnu
echo "unset xtics"                          >> conformers/plot_homoE_vs_Conformer.gnu
echo "set xlabel 'HOMO Energy (eV)'"        >> conformers/plot_homoE_vs_Conformer.gnu
echo "set ylabel 'Number of Conformers'"    >> conformers/plot_homoE_vs_Conformer.gnu
echo "set xtics 0.2 font ',8'"                >> conformers/plot_homoE_vs_Conformer.gnu
echo "set grid"                             >> conformers/plot_homoE_vs_Conformer.gnu
echo "unset key"                            >> conformers/plot_homoE_vs_Conformer.gnu
echo "set style fill solid 0.5"             >> conformers/plot_homoE_vs_Conformer.gnu
echo "binwidth=0.1"                         >> conformers/plot_homoE_vs_Conformer.gnu
echo "bin(x,width)=width*floor(x/width)"    >> conformers/plot_homoE_vs_Conformer.gnu
echo "set style data histogram"             >> conformers/plot_homoE_vs_Conformer.gnu
echo "plot 'homoVSconf.txt' using (bin(\$2,binwidth)):(1.0) smooth freq with boxes lc rgb '#008000'" >> conformers/plot_homoE_vs_Conformer.gnu
echo "unset multiplot"                      >> conformers/plot_homoE_vs_Conformer.gnu

# LUMO Energy vs Conformer 
echo "set terminal eps enhanced"             > conformers/plot_lumoE_vs_Conformer.gnu
echo "set output 'lumoVSconformer.eps'"     >> conformers/plot_lumoE_vs_Conformer.gnu
echo " "                                    >> conformers/plot_lumoE_vs_Conformer.gnu
echo "set multiplot layout 2,1"             >> conformers/plot_lumoE_vs_Conformer.gnu
echo " "                                    >> conformers/plot_lumoE_vs_Conformer.gnu
echo "set xlabel 'Conformers'"              >> conformers/plot_lumoE_vs_Conformer.gnu
echo "set ylabel 'LUMO Energy (eV)'"        >> conformers/plot_lumoE_vs_Conformer.gnu
echo "set xtics 5 font ',8' rotate by 80 offset 0.0,-0.8"   >> conformers/plot_lumoE_vs_Conformer.gnu
echo "set grid"                             >> conformers/plot_lumoE_vs_Conformer.gnu
echo "unset key"                            >> conformers/plot_lumoE_vs_Conformer.gnu
echo "plot 'lumoVSconf.txt' u 1:2 w lp pt 7 ps 0.2 lc rgb 'blue'" >> conformers/plot_lumoE_vs_Conformer.gnu
echo " "                                    >> conformers/plot_lumoE_vs_Conformer.gnu
echo "unset xtics"                          >> conformers/plot_lumoE_vs_Conformer.gnu
echo "set xlabel 'LUMO Energy (eV)'"        >> conformers/plot_lumoE_vs_Conformer.gnu
echo "set ylabel 'Number of Conformers'"    >> conformers/plot_lumoE_vs_Conformer.gnu
echo "set xtics 0.2 font ',8'"                >> conformers/plot_lumoE_vs_Conformer.gnu
echo "set grid"                             >> conformers/plot_lumoE_vs_Conformer.gnu
echo "unset key"                            >> conformers/plot_lumoE_vs_Conformer.gnu
echo "set style fill solid 0.5"             >> conformers/plot_lumoE_vs_Conformer.gnu
echo "binwidth=0.1"                         >> conformers/plot_lumoE_vs_Conformer.gnu
echo "bin(x,width)=width*floor(x/width)"    >> conformers/plot_lumoE_vs_Conformer.gnu
echo "set style data histogram"             >> conformers/plot_lumoE_vs_Conformer.gnu
echo "plot 'lumoVSconf.txt' using (bin(\$2,binwidth)):(1.0) smooth freq with boxes lc rgb '#008000'" >> conformers/plot_lumoE_vs_Conformer.gnu
echo "unset multiplot"                      >> conformers/plot_lumoE_vs_Conformer.gnu

# Polarizability vs Conformer 
echo "set terminal eps enhanced"               > conformers/plot_Alpha_vs_Conformer.gnu
echo "set output 'alphaVSconformer.eps'"      >> conformers/plot_Alpha_vs_Conformer.gnu
echo " "                                      >> conformers/plot_Alpha_vs_Conformer.gnu
echo "set multiplot layout 2,1"               >> conformers/plot_Alpha_vs_Conformer.gnu
echo " "                                      >> conformers/plot_Alpha_vs_Conformer.gnu
echo "set xlabel 'Number of Conformers'"      >> conformers/plot_Alpha_vs_Conformer.gnu
echo "set ylabel 'Polarizability (ANG**3)'"   >> conformers/plot_Alpha_vs_Conformer.gnu
echo "set xtics 5 font ',8' rotate by 80 offset 0.0,-0.8" >> conformers/plot_Alpha_vs_Conformer.gnu
echo "set ytics font ',10'"                   >> conformers/plot_Alpha_vs_Conformer.gnu
echo "set grid"                               >> conformers/plot_Alpha_vs_Conformer.gnu
echo "unset key"                              >> conformers/plot_Alpha_vs_Conformer.gnu
echo "plot 'alphaVSconf.txt' u 1:2 w lp pt 7 ps 0.2 lc rgb 'blue'" >> conformers/plot_Alpha_vs_Conformer.gnu
echo " "                                      >> conformers/plot_Alpha_vs_Conformer.gnu
echo "unset xtics"                            >> conformers/plot_Alpha_vs_Conformer.gnu
echo "set xlabel 'Polarizability (ANG.**3)'"  >> conformers/plot_Alpha_vs_Conformer.gnu
echo "set ylabel 'Number of Conformers'"      >> conformers/plot_Alpha_vs_Conformer.gnu
echo "set xtics 1 font ',8'"                  >> conformers/plot_Alpha_vs_Conformer.gnu
echo "set grid"                               >> conformers/plot_Alpha_vs_Conformer.gnu
echo "unset key"                              >> conformers/plot_Alpha_vs_Conformer.gnu
echo "set style fill solid 0.5"               >> conformers/plot_Alpha_vs_Conformer.gnu
echo "binwidth=0.5"                           >> conformers/plot_Alpha_vs_Conformer.gnu
echo "bin(x,width)=width*floor(x/width)"      >> conformers/plot_Alpha_vs_Conformer.gnu
echo "set style data histogram"               >> conformers/plot_Alpha_vs_Conformer.gnu
echo "plot 'alphaVSconf.txt' using (bin(\$2,binwidth)):(1.0) smooth freq with boxes lc rgb '#008000'" >> conformers/plot_Alpha_vs_Conformer.gnu
echo "unset multiplot"                        >> conformers/plot_Alpha_vs_Conformer.gnu

# Dipole Moment vs Conformer 
echo "set terminal eps enhanced"                  > conformers/plot_dipole_vs_Conformer.gnu
echo "set output 'dipoleMomentVSconformer.eps'"  >> conformers/plot_dipole_vs_Conformer.gnu
echo " "                                         >> conformers/plot_dipole_vs_Conformer.gnu
echo "set multiplot layout 2,1"                  >> conformers/plot_dipole_vs_Conformer.gnu
echo " "                                         >> conformers/plot_dipole_vs_Conformer.gnu
echo "set xlabel 'Conformers'"                   >> conformers/plot_dipole_vs_Conformer.gnu
echo "set ylabel 'Dipole Moment (Debye)'"        >> conformers/plot_dipole_vs_Conformer.gnu
echo "set xtics 5 font ',8' rotate by 80 offset 0.0,-0.8" >> conformers/plot_dipole_vs_Conformer.gnu
echo "set grid"                                  >> conformers/plot_dipole_vs_Conformer.gnu
echo "unset key"                                 >> conformers/plot_dipole_vs_Conformer.gnu
echo "plot 'dipoleMomentVSconf.txt' u 1:2 w lp pt 7 ps 0.2 lc rgb 'blue'" >> conformers/plot_dipole_vs_Conformer.gnu
echo " "                                         >> conformers/plot_dipole_vs_Conformer.gnu
echo "unset xtics"                               >> conformers/plot_dipole_vs_Conformer.gnu
echo "set xlabel 'Dipole Moment (Debye)'"        >> conformers/plot_dipole_vs_Conformer.gnu
echo "set ylabel 'Number of Conformers'"         >> conformers/plot_dipole_vs_Conformer.gnu
echo "set xtics 1 font ',8'"                     >> conformers/plot_dipole_vs_Conformer.gnu
echo "set grid"                                  >> conformers/plot_dipole_vs_Conformer.gnu
echo "unset key"                                 >> conformers/plot_dipole_vs_Conformer.gnu
echo "set style fill solid 0.5"                  >> conformers/plot_dipole_vs_Conformer.gnu
echo "binwidth=0.4"                              >> conformers/plot_dipole_vs_Conformer.gnu
echo "bin(x,width)=width*floor(x/width)"         >> conformers/plot_dipole_vs_Conformer.gnu
echo "set style data histogram"                  >> conformers/plot_dipole_vs_Conformer.gnu
echo "plot 'dipoleMomentVSconf.txt' using (bin(\$2,binwidth)):(1.0) smooth freq with boxes lc rgb '#008000'" >> conformers/plot_dipole_vs_Conformer.gnu
echo "unset multiplot"                           >> conformers/plot_dipole_vs_Conformer.gnu

# Energy vs Conformer 
echo "set terminal eps enhanced"          >> conformers/plot_Energy_vs_Conformer.gnu
echo "set output 'energyVSconformer.eps'" >> conformers/plot_Energy_vs_Conformer.gnu
echo " "                                  >> conformers/plot_Energy_vs_Conformer.gnu
echo "set multiplot layout 2,1"           >> conformers/plot_Energy_vs_Conformer.gnu
echo " "                                  >> conformers/plot_Energy_vs_Conformer.gnu
echo "set xlabel 'Conformers'"            >> conformers/plot_Energy_vs_Conformer.gnu
echo "set ylabel 'Total Energy (eV)'"     >> conformers/plot_Energy_vs_Conformer.gnu
echo "set xtics 5 font ',8' rotate by 80 offset 0.0,-0.8" >> conformers/plot_Energy_vs_Conformer.gnu
echo "set grid"                           >> conformers/plot_Energy_vs_Conformer.gnu
echo "unset key"                          >> conformers/plot_Energy_vs_Conformer.gnu
echo "plot 'energyVSconf.txt' u 1:2 w lp pt 7 ps 0.2 lc rgb 'blue'" >> conformers/plot_Energy_vs_Conformer.gnu
echo " "                                  >> conformers/plot_Energy_vs_Conformer.gnu
echo "unset xtics"                        >> conformers/plot_Energy_vs_Conformer.gnu
echo "set xlabel 'Total Energy (eV)'"     >> conformers/plot_Energy_vs_Conformer.gnu
echo "set ylabel 'Number of Conformers'"  >> conformers/plot_Energy_vs_Conformer.gnu
echo "set xtics 1 font ',8'"              >> conformers/plot_Energy_vs_Conformer.gnu
echo "set grid"                           >> conformers/plot_Energy_vs_Conformer.gnu
echo "unset key"                          >> conformers/plot_Energy_vs_Conformer.gnu
echo "set style fill solid 0.5"           >> conformers/plot_Energy_vs_Conformer.gnu
echo "binwidth=0.1"                       >> conformers/plot_Energy_vs_Conformer.gnu
echo "bin(x,width)=width*floor(x/width)"  >> conformers/plot_Energy_vs_Conformer.gnu
echo "set style data histogram"           >> conformers/plot_Energy_vs_Conformer.gnu
echo "plot 'energyVSconf.txt' using (bin(\$2,binwidth)):(1.0) smooth freq with boxes lc rgb '#008000'" >> conformers/plot_Energy_vs_Conformer.gnu
echo "unset multiplot"                    >> conformers/plot_Energy_vs_Conformer.gnu

# Heat of formation vs Conformer 
echo "set terminal eps enhanced"                 >> conformers/plot_Heat_vs_Conformer.gnu
echo "set output 'heatVSconformer.eps'"          >> conformers/plot_Heat_vs_Conformer.gnu
echo " "                                         >> conformers/plot_Heat_vs_Conformer.gnu
echo "set multiplot layout 2,1"                  >> conformers/plot_Heat_vs_Conformer.gnu
echo " "                                         >> conformers/plot_Heat_vs_Conformer.gnu
echo "set xlabel 'Conformers'"                   >> conformers/plot_Heat_vs_Conformer.gnu
echo "set ylabel 'Heat of Formation (Kcal/mol)'" >> conformers/plot_Heat_vs_Conformer.gnu
echo "set xtics 5 font ',8' rotate by 80 offset 0.0,-0.8" >> conformers/plot_Heat_vs_Conformer.gnu
echo "set grid"                                  >> conformers/plot_Heat_vs_Conformer.gnu
echo "unset key"                                 >> conformers/plot_Heat_vs_Conformer.gnu
echo "plot 'heatVSconf.txt' u 1:2 w lp pt 7 ps 0.2 lc rgb 'blue'" >> conformers/plot_Heat_vs_Conformer.gnu
echo " "                                         >> conformers/plot_Heat_vs_Conformer.gnu
echo "unset xtics"                               >> conformers/plot_Heat_vs_Conformer.gnu
echo "set xlabel 'Heat of Formation (Kcal/mol)'" >> conformers/plot_Heat_vs_Conformer.gnu
echo "set ylabel 'Number of Conformers'"         >> conformers/plot_Heat_vs_Conformer.gnu
echo "set xtics 2 font ',8'"                     >> conformers/plot_Heat_vs_Conformer.gnu
echo "set grid"                                  >> conformers/plot_Heat_vs_Conformer.gnu
echo "unset key"                                 >> conformers/plot_Heat_vs_Conformer.gnu
echo "set style fill solid 0.5"                  >> conformers/plot_Heat_vs_Conformer.gnu
echo "binwidth=1"                                >> conformers/plot_Heat_vs_Conformer.gnu
echo "bin(x,width)=width*floor(x/width)"         >> conformers/plot_Heat_vs_Conformer.gnu
echo "set style data histogram"                  >> conformers/plot_Heat_vs_Conformer.gnu
echo "plot 'heatVSconf.txt' using (bin(\$2,binwidth)):(1.0) smooth freq with boxes lc rgb '#008000'" >> conformers/plot_Heat_vs_Conformer.gnu
echo "unset multiplot"                           >> conformers/plot_Heat_vs_Conformer.gnu

cd conformers/
gnuplot plot_cosmoVolume_vs_Conformer.gnu
gnuplot plot_homoE_vs_Conformer.gnu
gnuplot plot_lumoE_vs_Conformer.gnu
gnuplot plot_Alpha_vs_Conformer.gnu
gnuplot plot_dipole_vs_Conformer.gnu
gnuplot plot_Energy_vs_Conformer.gnu
gnuplot plot_Heat_vs_Conformer.gnu
cd ..

# -------------------------------------------------------------------------------------------------- #
#                                       Average of properties                                        #
# -------------------------------------------------------------------------------------------------- #

sum_CosVol=0.0	
sum_homo=0.0	
sum_lumo=0.0	
sum_polar=0.0	
sum_dipole=0.0
sum_energy=0.0
sum_heat=0.0

cosVolConf=($(cat conformers/cosmoVolumeVSconf.txt | awk '{print $2}'))
homoConf=($(cat conformers/homoVSconf.txt | awk '{print $2}'))
lumoConf=($(cat conformers/lumoVSconf.txt | awk '{print $2}'))
polarConf=($(cat conformers/alphaVSconf.txt | awk '{print $2}'))
dipoleConf=($(cat conformers/dipoleMomentVSconf.txt | awk '{print $2}'))
energyConf=($(cat conformers/energyVSconf.txt | awk '{print $2}'))
heatConf=($(cat conformers/heatVSconf.txt | awk '{print $2}'))

for (( i=0; i<$conformers; i++ ))
do
   sum_CosVol=$(echo "scale=4; $sum_CosVol + ${cosVolConf[$i]}" | bc -l)
   sum_homo=$(echo "scale=4; $sum_homo + ${homoConf[$i]}" | bc -l) 
   sum_lumo=$(echo "scale=4; $sum_lumo + ${lumoConf[$i]}" | bc -l) 
   sum_polar=$(echo "scale=4; $sum_polar + ${polarConf[$i]}" | bc -l) 
   sum_dipole=$(echo "scale=4; $sum_dipole + ${dipoleConf[$i]}" | bc -l) 
   sum_energy=$(echo "scale=4; $sum_energy + ${energyConf[$i]}" | bc -l) 
   sum_heat=$(echo "scale=4; $sum_heat + ${heatConf[$i]}" | bc -l) 
done

cosVol_mean=$(echo "scale=4; $sum_CosVol / $conformers" | bc -l) 
homo_mean=$(echo "scale=4; $sum_homo / $conformers" | bc -l) 
lumo_mean=$(echo "scale=4; $sum_lumo / $conformers" | bc -l) 
polar_mean=$(echo "scale=4; $sum_polar / $conformers" | bc -l) 
dipole_mean=$(echo "scale=4; $sum_dipole / $conformers" | bc -l) 
energy_mean=$(echo "scale=4; $sum_energy / $conformers" | bc -l) 
heat_mean=$(echo "scale=4; $sum_heat / $conformers" | bc -l) 

mkdir conformers/plot_properties
mv conformers/*.eps conformers/plot_properties
mv conformers/*.txt conformers/plot_properties
mv conformers/*.gnu conformers/plot_properties
cp conformers/plot_properties/heatVSconf.txt conformers
cp conformers/plot_properties/energyVSconf.txt conformers


#---------------#
#  Mopac-MinE   #  
#---------------#

echo ""
echo "# --------------------------------------------- #"
echo "    Mopac: Conformer Minimum Heat of Formation   "
echo "# --------------------------------------------- #"
echo ""

# Index of minimum heat of formation conformer
c_heat=$(sort -k2 -n conformers/heatVSconf.txt | head -n 1 | awk '{print $1}')

cosVol_minC_Heat=$(cat conformers/conf_$c_heat/conf_$c_heat.out | grep 'COSMO VOLUME' | awk '{print $4}')
homo_minC_Heat=$(cat conformers/conf_$c_heat/conf_$c_heat.out | grep 'HOMO' | awk '{print $6}')
lumo_minC_Heat=$(cat conformers/conf_$c_heat/conf_$c_heat.out | grep 'LUMO' | awk '{print $7}')
polar_minC_Heat=$(cat conformers/conf_$c_heat/conf_$c_heat.out | grep 'ISOTROPIC' | tail -1 | awk '{print $8}')
dipole_minC_Heat=$(cat conformers/conf_$c_heat/conf_$c_heat.out | grep 'SUM' | awk '{print $5}')
energy_minC_Heat=$(cat conformers/conf_$c_heat/conf_$c_heat.out | grep "TOTAL ENERGY" | awk '{print $4}')
heat_minC_Heat=$(cat conformers/conf_$c_heat/conf_$c_heat.out | grep "FINAL HEAT OF FORMATION" | awk '{print $6}')


fA=$(cat -n conformers/conf_$c_heat/conf_$c_heat.out | grep "                            CARTESIAN COORDINATES" | awk '{print $1}')

firstAtom=$((fA+2))
lastAtom=$( echo "$firstAtom+$ato" | bc -l )
#lastAtom=$((firstAtom+ato))

sed -n "$firstAtom, $lastAtom p" conformers/conf_$c_heat/conf_$c_heat.out >> temporal.txt
cat temporal.txt | awk '{print $2 "          " $3 "   " $4 "   " $5}' >> conf_minHeatForm.xyz
rm temporal.txt

mkdir conf_$c_heat-MopacMinE-Heat

# Polarizability
echo "PM7 relscf=0.01 gnorm=0.01 dipole polar mullik aux graph graphf gradients opt" > conf_$c_heat-MopacMinE-Heat/conf_$c_heat-minE-polar.mop
echo "Semiempirical Calculation" >> conf_$c_heat-MopacMinE-Heat/conf_$c_heat-minE-polar.mop
echo " "                         >> conf_$c_heat-MopacMinE-Heat/conf_$c_heat-minE-polar.mop
cat conf_minHeatForm.xyz         >> conf_$c_heat-MopacMinE-Heat/conf_$c_heat-minE-polar.mop
/opt/mopac/MOPAC2016.exe conf_$c_heat-MopacMinE-Heat/conf_$c_heat-minE-polar.mop

# Thermodynamics and Frequencies 
echo "PM7 relscf=0.01 gnorm=0.01 thermo opt force" > conf_$c_heat-MopacMinE-Heat/conf_$c_heat-minE-thermo.mop
echo "Semiempirical Calculation" >> conf_$c_heat-MopacMinE-Heat/conf_$c_heat-minE-thermo.mop
echo " "                         >> conf_$c_heat-MopacMinE-Heat/conf_$c_heat-minE-thermo.mop
cat conf_minHeatForm.xyz         >> conf_$c_heat-MopacMinE-Heat/conf_$c_heat-minE-thermo.mop
/opt/mopac/MOPAC2016.exe conf_$c_heat-MopacMinE-Heat/conf_$c_heat-minE-thermo.mop

cosVol_minHeat=$(cat conf_$c_heat-MopacMinE-Heat/conf_$c_heat-minE-polar.out | grep 'COSMO VOLUME' | awk '{print $4}')           
homo_minHeat=$(cat conf_$c_heat-MopacMinE-Heat/conf_$c_heat-minE-polar.out | grep 'HOMO' | awk '{print $6}')                       
lumo_minHeat=$(cat conf_$c_heat-MopacMinE-Heat/conf_$c_heat-minE-polar.out | grep 'LUMO' | awk '{print $7}')                    
polar_minHeat=$(cat conf_$c_heat-MopacMinE-Heat/conf_$c_heat-minE-polar.out | grep 'ISOTROPIC' | tail -1 | awk '{print $8}')     
dipole_minHeat=$(cat conf_$c_heat-MopacMinE-Heat/conf_$c_heat-minE-polar.out | grep 'SUM' | awk '{print $5}')                     
energy_minHeat=$(cat conf_$c_heat-MopacMinE-Heat/conf_$c_heat-minE-polar.out | grep "TOTAL ENERGY" | awk '{print $4}')            
heat_minHeat=$(cat conf_$c_heat-MopacMinE-Heat/conf_$c_heat-minE-polar.out | grep "FINAL HEAT OF FORMATION" | awk '{print $6}') 


echo ""
echo "# --------------------------------------------- #"
echo "      Mopac: Conformer Minimum Total Energy      "
echo "# --------------------------------------------- #"
echo ""

# Index of minimum electronic energy conformer
c_total=$(sort -k2 -n conformers/energyVSconf.txt | head -n 1 | awk '{print $1}')

cosVol_minC_Total=$(cat conformers/conf_$c_total/conf_$c_total.out | grep 'COSMO VOLUME' | awk '{print $4}')
homo_minC_Total=$(cat conformers/conf_$c_total/conf_$c_total.out | grep 'HOMO' | awk '{print $6}')
lumo_minC_Total=$(cat conformers/conf_$c_total/conf_$c_total.out | grep 'LUMO' | awk '{print $7}')
polar_minC_Total=$(cat conformers/conf_$c_total/conf_$c_total.out | grep 'ISOTROPIC' | tail -1 | awk '{print $8}')
dipole_minC_Total=$(cat conformers/conf_$c_total/conf_$c_total.out | grep 'SUM' | awk '{print $5}')
energy_minC_Total=$(cat conformers/conf_$c_total/conf_$c_total.out | grep "TOTAL ENERGY" | awk '{print $4}')
heat_minC_Total=$(cat conformers/conf_$c_total/conf_$c_total.out | grep "FINAL HEAT OF FORMATION" | awk '{print $6}')


fA=$(cat -n conformers/conf_$c_total/conf_$c_total.out | grep "                            CARTESIAN COORDINATES" | awk '{print $1}')

firstAtom=$((fA+2))
lastAtom=$( echo "$firstAtom+$ato" | bc -l )
#lastAtom=$((firstAtom+ato))

sed -n "$firstAtom, $lastAtom p" conformers/conf_$c_total/conf_$c_total.out >> temporal.txt
cat temporal.txt | awk '{print $2 "          " $3 "   " $4 "   " $5}' >> conf_minETotal.xyz
rm temporal.txt

mkdir conf_$c_total-MopacMinETotal

# Polarizability
echo "PM7 relscf=0.01 gnorm=0.01 dipole polar mullik aux graph graphf gradients opt" > conf_$c_total-MopacMinETotal/conf_$c_total-minE-polar.mop
echo "Semiempirical Calculation" >> conf_$c_total-MopacMinETotal/conf_$c_total-minE-polar.mop
echo " "                         >> conf_$c_total-MopacMinETotal/conf_$c_total-minE-polar.mop
cat conf_minETotal.xyz           >> conf_$c_total-MopacMinETotal/conf_$c_total-minE-polar.mop
/opt/mopac/MOPAC2016.exe conf_$c_total-MopacMinETotal/conf_$c_total-minE-polar.mop

# Thermodynamics and Frequencies 
echo "PM7 relscf=0.01 gnorm=0.01 thermo opt force" > conf_$c_total-MopacMinETotal/conf_$c_total-minE-thermo.mop
echo "Semiempirical Calculation" >> conf_$c_total-MopacMinETotal/conf_$c_total-minE-thermo.mop
echo " "                         >> conf_$c_total-MopacMinETotal/conf_$c_total-minE-thermo.mop
cat conf_minETotal.xyz           >> conf_$c_total-MopacMinETotal/conf_$c_total-minE-thermo.mop
/opt/mopac/MOPAC2016.exe conf_$c_total-MopacMinETotal/conf_$c_total-minE-thermo.mop

cosVol_minTotal=$(cat conf_$c_total-MopacMinETotal/conf_$c_total-minE-polar.out | grep 'COSMO VOLUME' | awk '{print $4}')           
homo_minTotal=$(cat conf_$c_total-MopacMinETotal/conf_$c_total-minE-polar.out | grep 'HOMO' | awk '{print $6}')                       
lumo_minTotal=$(cat conf_$c_total-MopacMinETotal/conf_$c_total-minE-polar.out | grep 'LUMO' | awk '{print $7}')                    
polar_minTotal=$(cat conf_$c_total-MopacMinETotal/conf_$c_total-minE-polar.out | grep 'ISOTROPIC' | tail -1 | awk '{print $8}')     
dipole_minTotal=$(cat conf_$c_total-MopacMinETotal/conf_$c_total-minE-polar.out | grep 'SUM' | awk '{print $5}')                     
energy_minTotal=$(cat conf_$c_total-MopacMinETotal/conf_$c_total-minE-polar.out | grep "TOTAL ENERGY" | awk '{print $4}')            


# --------------------------------------------------- #
# --- Recolection of Quantum Chemical Descriptors --- #
# --------------------------------------------------- #

echo "#Property                              Mean                MinE_Heat (gnorm=10)           MinE_Heat (gnorm0.01)        MinE_Total (gnorm=10)     MinE_Total (gnorm=0.01)"     >  propConfPM7_Mean-Min.txt

echo -n "Cosmo Volume (ANG**3)               " >> propConfPM7_Mean-Min.txt
echo -n $cosVol_mean "                "        >> propConfPM7_Mean-Min.txt
echo -n $cosVol_minC_Heat  "               "   >> propConfPM7_Mean-Min.txt
echo -n $cosVol_minHeat    "               "   >> propConfPM7_Mean-Min.txt
echo -n $cosVol_minC_Total "               "   >> propConfPM7_Mean-Min.txt
echo $cosVol_minTotoal     "               "   >> propConfPM7_Mean-Min.txt

echo -n "HOMO Energy (eV)                    " >> propConfPM7_Mean-Min.txt
echo -n $homo_mean   "                "        >> propConfPM7_Mean-Min.txt
echo -n $homo_minC_Heat    "                "  >> propConfPM7_Mean-Min.txt
echo -n $homo_minHeat      "                "  >> propConfPM7_Mean-Min.txt
echo -n $homo_minC_Total   "                "  >> propConfPM7_Mean-Min.txt
echo $homo_minTotal                            >> propConfPM7_Mean-Min.txt

echo -n "LUMO Energy (eV)                   "  >> propConfPM7_Mean-Min.txt
echo -n $lumo_mean   "                 "       >> propConfPM7_Mean-Min.txt
echo -n $lumo_minC_Heat    "                "  >> propConfPM7_Mean-Min.txt
echo -n $lumo_minHeat      "                "  >> propConfPM7_Mean-Min.txt
echo -n $lumo_minC_Total   "                "  >> propConfPM7_Mean-Min.txt
echo $lumo_minTotal                            >> propConfPM7_Mean-Min.txt

echo -n "Polarizability (ANG**3)            "  >> propConfPM7_Mean-Min.txt
echo -n $polar_mean "                 "        >> propConfPM7_Mean-Min.txt
echo -n $polar_minC_Heat   "                "  >> propConfPM7_Mean-Min.txt
echo -n $polar_minHeat     "                "  >> propConfPM7_Mean-Min.txt
echo -n $polar_minC_Total  "                "  >> propConfPM7_Mean-Min.txt
echo $polar_minHeat                            >> propConfPM7_Mean-Min.txt

echo -n "Dipole Moment (Debye)              "  >> propConfPM7_Mean-Min.txt
echo -n $dipole_mean "                  "      >> propConfPM7_Mean-Min.txt
echo -n $dipole_minC_Heat  "                 " >> propConfPM7_Mean-Min.txt
echo -n $dipole_minHeat    "                 " >> propConfPM7_Mean-Min.txt
echo -n $dipole_minC_Total "                 " >> propConfPM7_Mean-Min.txt
echo $dipole_minTotal                          >> propConfPM7_Mean-Min.txt

echo -n "Total Energy (a.u.)                "  >> propConfPM7_Mean-Min.txt
echo -n $energy_mean "           "             >> propConfPM7_Mean-Min.txt
echo -n $energy_minC_Heat  "                "  >> propConfPM7_Mean-Min.txt
echo -n $energy_minHeat    "                "  >> propConfPM7_Mean-Min.txt
echo -n $energy_minC_Total "                "  >> propConfPM7_Mean-Min.txt
echo $energy_minTotal                          >> propConfPM7_Mean-Min.txt

echo -n "Heat of Formation (Kcal/mol)       "  >> propConfPM7_Mean-Min.txt
echo -n $heat_mean   "                "        >> propConfPM7_Mean-Min.txt
echo -n $heat_minC_Heat    "                "  >> propConfPM7_Mean-Min.txt
echo -n $heat_minHeat      "                "  >> propConfPM7_Mean-Min.txt
echo -n $heat_minC_Total   "                "  >> propConfPM7_Mean-Min.txt
echo $heat_minTotal                            >> propConfPM7_Mean-Min.txt



#---------------#
#     Orca      #  
#---------------#

mkdir orca_conformer-$c_total 

# Conformer of Minimum Heat of Formation (PM7) 
sed -i "1s/^/$atoms\n\n/" conf_minHeatForm.xyz
cp conf_minHeatForm.xyz orca_conformer-$c_total

# Conformer of Minimum Total Energy (PM7)
sed -i "1s/^/$atoms\n\n/" conf_minETotal.xyz
cp conf_minETotal.xyz orca_conformer-$c_total

echo "# Orca calculation" > orca_conformer-$c_total/minE_c-$c_total.inp
#
# Orca 4.2
#echo "! B3LYP 6-31++G** Grid5 FinalGrid6 TightSCF TightOpt D3ZERO Opt Freq" >> orca/minenergyConformer.inp
#echo "! B3LYP 6-31++G** Grid4 FinalGrid5 TightSCF TightOpt Opt Freq" >> orca/minenergyConformer.inp
#
# Orca 5.0
echo "! B3LYP 6-31++G** defgrid2 TightSCF TightOpt D3BJ Opt Freq" >> orca_conformer-$c_total/minE_c-$c_total.inp
echo " "                                                          >> orca_conformer-$c_total/minE_c-$c_total.inp
echo "# Number of procs and memory per core"                      >> orca_conformer-$c_total/minE_c-$c_total.inp
echo "%maxcore 2000"                                              >> orca_conformer-$c_total/minE_c-$c_total.inp
echo "%pal"                                                       >> orca_conformer-$c_total/minE_c-$c_total.inp
echo "   nprocs 6"                                                >> orca_conformer-$c_total/minE_c-$c_total.inp
echo "end"                                                        >> orca_conformer-$c_total/minE_c-$c_total.inp
echo "  "                                                         >> orca_conformer-$c_total/minE_c-$c_total.inp
echo "# Polarizability"                                           >> orca_conformer-$c_total/minE_c-$c_total.inp
echo "%elprop"                                                    >> orca_conformer-$c_total/minE_c-$c_total.inp
echo "   Polar 1 "                                                >> orca_conformer-$c_total/minE_c-$c_total.inp
echo "end"                                                        >> orca_conformer-$c_total/minE_c-$c_total.inp
echo "  "                                                         >> orca_conformer-$c_total/minE_c-$c_total.inp
echo "# Cartesian Coordinates in Angstroms"                       >> orca_conformer-$c_total/minE_c-$c_total.inp
echo "* xyzfile 0 1 conf_minHeatForm.xyz"                         >> orca_conformer-$c_total/minE_c-$c_total.inp
echo "* xyzfile 0 1 conf_minETotal.xyz"                           >> orca_conformer-$c_total/minE_c-$c_total.inp

# Orca 4.2
#$HOME/Orca4.2/orca_4_2_1_linux_x86-64_openmpi314/orca orca/minenergyConformer_$c.inp > orca/minenergyConformer_$c.out &

# Orca 5.0
cd orca_conformer-$c_total
#$HOME/orca5.0/orca minE_c-$c_total.inp > minE_c-$c_total.out &

#------------------------------------#
# Validation of geometry consistency #
#------------------------------------#
cd ..
obabel input.xyz -oinchi             > valGeomConsistency.txt
obabel conf_minHeatForm.xyz -oinchi >> valGeomConsistency.txt


#-----------------------#
echo " "
echo "Finish! Shoo shoo"
echo "Orca calculating..."
#-----------------------#
