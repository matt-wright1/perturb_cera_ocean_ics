import sys
import xarray as xr
import numpy as np
from cdo import *

def regrid_to_cera(path_to_regrid,output_path,horz_griddes='/perm/frmw/cera_sst_griddes.txt'):
    cdo = Cdo()
    horz_grid = horz_griddes
   
    ### generate weights file for regridding
    horz_wts = cdo.gennn(horz_grid,input=path_to_regrid)
    cdo.remap(horz_grid+','+horz_wts,input=path_to_regrid,output=output_path)

def process_sst(year, hindcast_dir, half_output_dir, doub_output_dir, scratch_dir, perm_output_dir):
    cdo = Cdo()
    
    cdo.selvar("var34", input=f"{scratch_dir}/sst_{year}.grib", output=f"{scratch_dir}/sst_{year}_var34.grib")
    cdo.selvar("var31,var172", input=f"{scratch_dir}/sst_{year}.grib", output=f"{scratch_dir}/sst_{year}_ice_lsm.grib")

    cdo.timmean(input=f"{hindcast_dir}/sst_BEST_{year}.grib", output=f"{hindcast_dir}/sst_BEST_{year}_ensmean.grib")
    cdo.timmean(input=f"{hindcast_dir}/sst_HALF_{year}.grib", output=f"{hindcast_dir}/sst_HALF_{year}_ensmean.grib")
    cdo.timmean(input=f"{hindcast_dir}/sst_DOUB_{year}.grib", output=f"{hindcast_dir}/sst_DOUB_{year}_ensmean.grib")
    
    regrid_to_cera(f"{hindcast_dir}/sst_BEST_{year}_ensmean.grib",f"{hindcast_dir}/sst_BEST_{year}_ensmean_regridded.grib")
    regrid_to_cera(f"{hindcast_dir}/sst_HALF_{year}_ensmean.grib",f"{hindcast_dir}/sst_HALF_{year}_ensmean_regridded.grib")
    regrid_to_cera(f"{hindcast_dir}/sst_DOUB_{year}_ensmean.grib",f"{hindcast_dir}/sst_DOUB_{year}_ensmean_regridded.grib")
    
    cdo.sub(input=f"{hindcast_dir}/sst_DOUB_{year}_ensmean_regridded.grib {hindcast_dir}/sst_BEST_{year}_ensmean_regridded.grib", output=f"{hindcast_dir}/sst_DOUBMINUSBEST_{year}_ensmean_regridded.grib")
    cdo.sub(input=f"{hindcast_dir}/sst_HALF_{year}_ensmean_regridded.grib {hindcast_dir}/sst_BEST_{year}_ensmean_regridded.grib", output=f"{hindcast_dir}/sst_HALFMINUSBEST_{year}_ensmean_regridded.grib")

    cdo.expr("var34=var34*-1'", input=f"{hindcast_dir}/sst_DOUBMINUSBEST_{year}_ensmean_regridded.grib", output=f"{hindcast_dir}/sst_DOUBMINUSBEST_{year}_ensmean_regridded_neg.grib")
    cdo.expr("var34=var34*-1'", input=f"{hindcast_dir}/sst_HALFMINUSBEST_{year}_ensmean_regridded.grib", output=f"{hindcast_dir}/sst_HALFMINUSBEST_{year}_ensmean_regridded_neg.grib")

    cdo.sub(input=f"{scratch_dir}/sst_{year}_var34.grib {hindcast_dir}/sst_HALFMINUSBEST_{year}_ensmean_regridded_neg.grib", output=f"{half_output_dir}/halfPert_{year}_sst.grib")
    cdo.sub(input=f"{scratch_dir}/sst_{year}_var34.grib {hindcast_dir}/sst_DOUBMINUSBEST_{year}_ensmean_regridded_neg.grib", output=f"{doub_output_dir}/doubPert_{year}_sst.grib")

    cdo.merge(input=f"{half_output_dir}/halfPert_sst.grib {scratch_dir}/sst_{year}_ice_lsm.grib", output=f"{perm_output_dir}/half/sst_halfPert_{year}.grib")
    cdo.merge(input=f"{doub_output_dir}/doubPert_sst.grib {scratch_dir}/sst_{year}_ice_lsm.grib", output=f"{perm_output_dir}/doub/sst_doubPert_{year}.grib")

#Run script
if __name__ == "__main__":
    # Parse command-line arguments
    year = int(sys.argv[1])
    hindcast_dir = sys.argv[2]
    half_output_dir = sys.argv[3]
    doub_output_dir = sys.argv[4]
    scratch_dir = sys.argv[5]
    perm_output_dir = sys.argv[6]

    process_sst(year, hindcast_dir, half_output_dir, doub_output_dir, scratch_dir, perm_output_dir)