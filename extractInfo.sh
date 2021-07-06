#!/bin/bash

cd nwchem_simulations
echo "Name,TotalDFTenergy,Polarizability,homoEnergy,lumoEnergy,deltaE,IonizationPotential,ElectronAffinity,Electronegativity,Hardness,Softness,ChemicalPotential,Electrophilicity" > ../info.txt


for typeMonomer in *
do
	if [ -d $typeMonomer ]; then     	    
     		echo "#$typeMonomer" >> ../info.txt

		cd $typeMonomer
	    	for monomer in *
		do
			echo "#$monomer" >> ../../../info.txt
			if [ -d $monomer ]; then
				cd $monomer
				output=$(ls *.out)
			      # Monomer Name
				name=$(cat $output | grep 'title' | head -n1 | awk '{print $2}')
				echo -n "$name," >> ../../../info.txt
			      # Total DFT energy
				energy=$(cat $output | grep 'Total DFT energy' | tail -1 | awk '{print $5}')
				echo -n "$energy," >> ../../../info.txt
			      # Polarizability in cubic Angstroms 
			      # 1 au = 0.52917 A^3
				pol=$(cat $output | grep 'Isotropic' | awk '{print $3}')
				polarizability=$(echo "scale=5; $pol * 0.52917 * 0.52917 * 0.52917" | bc -l)
				echo -n "$polarizability," >> ../../../info.txt
			      # HOMO-LUMO energy
				line=$(cat -n $output | grep 'DFT Final' | tail -1 | awk '{print $1}')
				sed -n "$line,$ p" $output > temp
				homo=$(cat temp | grep 'Vector' | grep 'Occ=2' | tail -1 | awk '{print $4}' | cut -c3-11)
				homo_eV=$(echo "scale=5; $homo * 0.1 * 27.2114" | bc -l)
				echo -n "$homo_eV," >> ../../../info.txt
				lumo=$(cat temp | grep 'Vector' | grep 'Occ=0' | head -n1 | awk '{print $4}' | cut -c3-11)
				lumo_eV=$(echo "scale=5; $lumo * 0.01 * 27.2114" | bc -l)
				echo -n "$lumo_eV," >> ../../../info.txt
				rm temp
			      # DeltaE = E_LUMO - E_HOMO
			        deltaE=$(echo "scale=5; $lumo_eV - $homo_eV" | bc -l)
				echo -n "$deltaE," >> ../../../info.txt
			      # Dipole Moment in Debye
				dipoleMoment=$(cat $output | grep 'Debye' | head -n1 | awk '{print $3}')
				echo "$dipoleMoment" >> ../../../info.txt
			fi
			cd ..
		done
    	fi
	cd ..
done
