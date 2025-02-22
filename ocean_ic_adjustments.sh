#!/bin/bash
#SBATCH --job-name=ocean_ic_adjustments_for_aerosol_runs
#SBATCH --account=spgbwrig
#SBATCH --output=%x_%j.out
#SBATCH --error=%x_%j.err
#SBATCH --time=24:00:00
#SBATCH --mem=64G
#SBATCH --cpus-per-task=16
#SBATCH --mail-type=ALL
#SBATCH --mail-user=matthew.wright@env-res.ox.ac.uk

# Load required modules
module load cdo
module load python3

# Define directories
SCRATCH_DIR="$SCRATCH/cera_files"
HINDCAST_DIR="$SCRATCH/hindcast_files"
HALF_OUTPUT_DIR="$SCRATCH/half_output_files"
DOUB_OUTPUT_DIR="$SCRATCH/doub_output_files"
PERM_DIR="$PERM"
PERM_OUTPUT_DIR="$HPCPERM/perturbed_sst"

# Ensure required directories exist
mkdir -p $SCRATCH_DIR $HINDCAST_DIR $HALF_OUTPUT_DIR $DOUB_OUTPUT_DIR

# Years of interest
# YEARS_OLD=(1925 1926 1927 1928 1929 1930 1931 1932 1933 1934 1935 1936 1937 1938 1939 1940 1941 1942 1943 1944 1945 1946 1947 1948 1949 1950)
# YEARS_NEW=(1985 1986 1987 1988 1989 1990 1991 1992 1993 1994 1995 1996 1997 1998 1999 2000 2001 2002 2003 2004 2005 2006 2007 2008 2009 2010)
YEARS_OLD=(1927)
YEARS_NEW=(1990)

# Function to get NNNN based on year
get_NNNN() {
  local year=$1
  if [ $year -ge 1925 -a $year -le 1925 ]; then echo 2368
  elif [ $year -ge 1926 -a $year -le 1931 ]; then echo 2369
  elif [ $year -ge 1932 -a $year -le 1939 ]; then echo 2370
  elif [ $year -ge 1940 -a $year -le 1947 ]; then echo 2371
  elif [ $year -ge 1948 -a $year -le 1950 ]; then echo 2372
  elif [ $year -ge 1985 -a $year -le 1987 ]; then echo 2376
  elif [ $year -ge 1988 -a $year -le 1995 ]; then echo 2377
  elif [ $year -ge 1996 -a $year -le 2003 ]; then echo 2378
  elif [ $year -ge 2004 -a $year -le 2010 ]; then echo 2379
  fi
}

# Function to get expno based on year and type (BEST/HALF/DOUB)
get_expno() {
  local year=$1
  local type=$2
  if [ $year -ge 1925 -a $year -le 1935 ]; then
    if [ "$type" == "BEST" ]; then echo b2qj
    elif [ "$type" == "HALF" ]; then echo b2r5
    elif [ "$type" == "DOUB" ]; then echo b2r6
    fi
  elif [ $year -ge 1936 -a $year -le 1950 ]; then
    if [ "$type" == "BEST" ]; then echo b2rg
    elif [ "$type" == "HALF" ]; then echo b2rh
    elif [ "$type" == "DOUB" ]; then echo b2ri
    fi
  elif [ $year -ge 1985 -a $year -le 2010 ]; then
    if [ "$type" == "BEST" ]; then echo b2qd
    elif [ "$type" == "HALF" ]; then echo b2qh
    elif [ "$type" == "DOUB" ]; then echo b2qg
    fi
  fi
}

# Function to process a single year
process_year() {
  local year=$1
  local NNNN=$(get_NNNN $year)

    # Get SST dataset from MARS
  #CERA-20C - not required for now as we are giving the files a delta T value to add to this during the model run, rather than the full field
  cat > mars_req <<EOF
    retrieve,
    class=ep,
    date=$year-11-01,
    expver=1,
    levtype=sfc,
    number=0,
    grid=AV,
    param=139.128/141.128/170.128/183.128/198.128/236.128/235.128/148.128/206.128/31.128/238.128/32.128/33.128/34.128/35.128/36.128/37.128/38.128/39.128/40.128/41.128/42.128/8.228/9.228/10.228/11.228/12.228/13.228/14.228,
    stream=enda,
    time=00:00:00,
    type=an,
    target="$SCRATCH_DIR/sst_$year.grib"
EOF
  mars mars_req
  # all hindcast exps
  for type in "BEST" "HALF" "DOUB"; do
    expno=$(get_expno $year $type)
    cat > mars_req <<EOF
      retrieve,
      class=uk,
      date=$year-11-01,
      expver=$expno,
      fcmonth=4,
      levtype=sfc,
      method=1,
      number=0/1/2/3/4/5/6/7/8/9/10/11/12/13/14/15/16/17/18/19/20,
      grid=AV,
      param=34.128,
      stream=msmm,
      time=00:00:00,
      type=fcmean,
      target="$HINDCAST_DIR/sst_${type}_${year}.grib"
EOF
    mars mars_req
  done
  python3 sst_processing.py $year $HINDCAST_DIR $HALF_OUTPUT_DIR $DOUB_OUTPUT_DIR $SCRATCH_DIR $PERM_OUTPUT_DIR

# 3D ocean temp and salinity
  # Step 2: Copy and unzip CERA-20C dataset
  cera_file="${NNNN}_${year}1101_180000_restart_2.nc.gz"
  for folder in enda01 enda02 enda03 enda04 control; do
    ecp ec:/ERAS/cera20c/${NNNN}/an/restart/${folder}/$year/$cera_file $SCRATCH_DIR/
    gunzip $SCRATCH_DIR/$cera_file
    mv $SCRATCH_DIR/${NNNN}_${year}1101_180000_restart_2.nc $SCRATCH_DIR/cera_${folder}_${year}.nc
  done

  # Process Hindcast types (BEST, HALF, DOUB)
  for type in "BEST" "HALF" "DOUB"; do
    expno=$(get_expno $year $type)
    for N in $(seq 0 20); do
      if [ $(( (year+1) % 4 ))  -eq 0 ]; then
        hindcast_file="votemper_${expno}_1m_${year}1101_$((year+1))0303_r1x1.nc.gz"
        ecp ec:/xgb/public/$expno/longrange${N}/archive_r1x1/${year}110100/$hindcast_file $HINDCAST_DIR/
        gunzip $HINDCAST_DIR/$hindcast_file
        mv $HINDCAST_DIR/votemper_${expno}_1m_${year}1101_$((year+1))0303_r1x1.nc $HINDCAST_DIR/${type}_${year}_${N}.nc
      else
        hindcast_file="votemper_${expno}_1m_${year}1101_$((year+1))0304_r1x1.nc.gz"
        ecp ec:/xgb/public/$expno/longrange${N}/archive_r1x1/${year}110100/$hindcast_file $HINDCAST_DIR/
        gunzip $HINDCAST_DIR/$hindcast_file
        mv $HINDCAST_DIR/votemper_${expno}_1m_${year}1101_$((year+1))0304_r1x1.nc $HINDCAST_DIR/${type}_${year}_${N}.nc
      fi
    done
    # Calculate ensemble mean
    cdo -O ensmean $HINDCAST_DIR/${type}_${year}_*.nc $HINDCAST_DIR/${type}_${year}_ensmean.nc
  done

  # Step 13: Run Python script for regridding and further processing
  for folder in enda01 enda02 enda03 enda04 control; do
    python3 ocean_ic_processing.py $year $SCRATCH_DIR $HINDCAST_DIR $HALF_OUTPUT_DIR $DOUB_OUTPUT_DIR $PERM_DIR $folder
    gzip $HALF_OUTPUT_DIR/${year}_${folder}_halfPert.nc
    gzip $DOUB_OUTPUT_DIR/${year}_${folder}_doubPert.nc
    ecp $HALF_OUTPUT_DIR/${year}_${folder}_halfPert.nc.gz ec:/xgb/public/frmw/half/${NNNN}/an/restart/${folder}/$year/${NNNN}_${year}1101_180000_restart_2.nc.gz
    ecp $DOUB_OUTPUT_DIR/${year}_${folder}_doubPert.nc.gz ec:/xgb/public/frmw/doub/${NNNN}/an/restart/${folder}/$year/${NNNN}_${year}1101_180000_restart_2.nc.gz
  done  

  # Move additional CERA-20C files for the restart
  for folder in enda01 enda02 enda03 enda04 control; do
    ecp ec:/ERAS/cera20c/${NNNN}/an/restart/${folder}/$year/${NNNN}_${year}1101_${year}1102_increments_02.nc.gz $SCRATCH_DIR/${NNNN}_${year}1101_${year}1102_increments_02.nc.gz
    ecp ec:/ERAS/cera20c/${NNNN}/an/restart/${folder}/$year/${NNNN}_${year}1101_${year}1102_increments_01.nc.gz $SCRATCH_DIR/${NNNN}_${year}1101_${year}1102_increments_01.nc.gz
    ecp ec:/ERAS/cera20c/${NNNN}/an/restart/${folder}/$year/${NNNN}_${year}1101_180000_restart_ice_2.nc.gz $SCRATCH_DIR/${NNNN}_${year}1101_180000_restart_ice_2.nc.gz

    ecp $SCRATCH_DIR/${NNNN}_${year}1101_${year}1102_increments_02.nc.gz ec:/xgb/public/frmw/half/${NNNN}/an/restart/${folder}/$year/${NNNN}_${year}1101_${year}1102_increments_02.nc.gz
    ecp $SCRATCH_DIR/${NNNN}_${year}1101_${year}1102_increments_01.nc.gz ec:/xgb/public/frmw/half/${NNNN}/an/restart/${folder}/$year/${NNNN}_${year}1101_${year}1102_increments_01.nc.gz
    ecp $SCRATCH_DIR/${NNNN}_${year}1101_180000_restart_ice_2.nc.gz ec:/xgb/public/frmw/half/${NNNN}/an/restart/${folder}/$year/${NNNN}_${year}1101_180000_restart_ice_2.nc.gz

    ecp $SCRATCH_DIR/${NNNN}_${year}1101_${year}1102_increments_02.nc.gz ec:/xgb/public/frmw/doub/${NNNN}/an/restart/${folder}/$year/${NNNN}_${year}1101_${year}1102_increments_02.nc.gz
    ecp $SCRATCH_DIR/${NNNN}_${year}1101_${year}1102_increments_01.nc.gz ec:/xgb/public/frmw/doub/${NNNN}/an/restart/${folder}/$year/${NNNN}_${year}1101_${year}1102_increments_01.nc.gz
    ecp $SCRATCH_DIR/${NNNN}_${year}1101_180000_restart_ice_2.nc.gz ec:/xgb/public/frmw/doub/${NNNN}/an/restart/${folder}/$year/${NNNN}_${year}1101_180000_restart_ice_2.nc.gz
  done
  
  # Cleanup $SCRATCH directories for CERA and Hindcast files
  rm -f $SCRATCH_DIR/*$year*.nc
  rm -f $HINDCAST_DIR/*$year*.nc
  rm -f $DOUB_OUTPUT_DIR/*$year*.nc
  rm -f $HALF_OUTPUT_DIR/*$year*.nc

}

# Main loop for all years
for year in "${YEARS_OLD[@]}" "${YEARS_NEW[@]}"; do
  process_year $year
done

