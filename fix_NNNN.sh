#!/bin/bash
#SBATCH --job-name=fix_folder_structure_NNNN
#SBATCH --account=spgbwrig
#SBATCH --output=%x_%j.out
#SBATCH --error=%x_%j.err
#SBATCH --time=24:00:00
#SBATCH --mem=32G
#SBATCH --cpus-per-task=16
#SBATCH --mail-type=ALL
#SBATCH --mail-user=matthew.wright@env-res.ox.ac.uk

SCRATCH_DIR="$SCRATCH/cera_files"
HALF_OUTPUT_DIR="$SCRATCH/half_output_files"
DOUB_OUTPUT_DIR="$SCRATCH/doub_output_files"

# For year 1925 with NNNN=2368
year=1925
OldNNNN=2369
NewNNNN=2368

#Move perturbed files
for folder in enda01 enda02 enda03 enda04 control; do
  ecp $HALF_OUTPUT_DIR/${year}_${folder}_halfPert.nc.gz ec:/xgb/public/frmw/half/${NNNN}/an/restart/${folder}/$year/${NNNN}_${year}1101_180000_restart_2.nc.gz
  ecp $DOUB_OUTPUT_DIR/${year}_${folder}_doubPert.nc.gz ec:/xgb/public/frmw/doub/${NNNN}/an/restart/${folder}/$year/${NNNN}_${year}1101_180000_restart_2.nc.gz
done  

# Move additional files required for restart
for folder in enda01 enda02 enda03 enda04 control; do
  ecp ec:/ERAS/cera20c/${NewNNNN}/an/restart/${folder}/$year/${NewNNNN}_${year}1101_${year}1102_increments_02.nc.gz $SCRATCH_DIR/${NewNNNN}_${year}1101_${year}1102_increments_02.nc.gz
  ecp ec:/ERAS/cera20c/${NewNNNN}/an/restart/${folder}/$year/${NewNNNN}_${year}1101_${year}1102_increments_01.nc.gz $SCRATCH_DIR/${NewNNNN}_${year}1101_${year}1102_increments_01.nc.gz
  ecp ec:/ERAS/cera20c/${NewNNNN}/an/restart/${folder}/$year/${NewNNNN}_${year}1101_${year}1101_180000_restart_ice_2.nc.gz $SCRATCH_DIR/${NewNNNN}_${year}1101_180000_restart_ice_2.nc.gz

  ecp $SCRATCH_DIR/${NewNNNN}_${year}1101_${year}1102_increments_02.nc.gz ec:/xgb/public/frmw/half/${NewNNNN}/an/restart/${folder}/$year/${NewNNNN}_${year}1101_${year}1102_increments_02.nc.gz
  ecp $SCRATCH_DIR/${NewNNNN}_${year}1101_${year}1102_increments_01.nc.gz ec:/xgb/public/frmw/half/${NewNNNN}/an/restart/${folder}/$year/${NewNNNN}_${year}1101_${year}1102_increments_01.nc.gz
  ecp $SCRATCH_DIR/${NewNNNN}_${year}1101_180000_restart_ice_2.nc.gz ec:/xgb/public/frmw/half/${NewNNNN}/an/restart/${folder}/$year/${NewNNNN}_${year}1101_180000_restart_ice_2.nc.gz

  ecp $SCRATCH_DIR/${NewNNNN}_${year}1101_${year}1102_increments_02.nc.gz ec:/xgb/public/frmw/doub/${NewNNNN}/an/restart/${folder}/$year/${NewNNNN}_${year}1101_${year}1102_increments_02.nc.gz
  ecp $SCRATCH_DIR/${NewNNNN}_${year}1101_${year}1102_increments_01.nc.gz ec:/xgb/public/frmw/doub/${NewNNNN}/an/restart/${folder}/$year/${NewNNNN}_${year}1101_${year}1102_increments_01.nc.gz
  ecp $SCRATCH_DIR/${NewNNNN}_${year}1101_180000_restart_ice_2.nc.gz ec:/xgb/public/frmw/doub/${NewNNNN}/an/restart/${folder}/$year/${NewNNNN}_${year}1101_180000_restart_ice_2.nc.gz
done

#Clean up old ecfs directories
for folder in enda01 enda02 enda03 enda04 control; do
  erm -r ec:/xgb/public/frmw/half/${OldNNNN}/an/restart/${folder}/$year
done
