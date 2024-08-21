import sys
import xarray as xr
import numpy as np
from cdo import *

# FUNCTIONS
def eos_insitu(t, s, z):
    '''
    NAME:
        eos_insitu

    DESCRIPTION:
        Python version of in situ density calculation done by NEMO
        routine eos_insitu.f90. Computes the density referenced to
        a specified depth from potential temperature and salinity
        using the Jackett and McDougall (1994) equation of state.
       
    USAGE:
        density = eos_insitu(T,S,p)

    INPUTS:
        T - potential temperature (celsius)
        S - salinity              (psu)
        p - pressure              (dbar)
       
    OUTPUTS
        density - in situ density (kg/m3) - 1000.

    NOTES:
        Original routine returned (rho(t,s,p) - rho0)/rho0.
        This version returns rho(t,s,p). Header for eos_insitu.f90
        included below for reference.

        ***  ROUTINE eos_insitu  ***
       
        ** Purpose :   Compute the in situ density from
        potential temperature and salinity using an equation of state
        defined through the namelist parameter nn_eos. nn_eos = 0
        the in situ density is computed directly as a function of
        potential temperature relative to the surface (the opa t
        variable), salt and pressure (assuming no pressure variation
        along geopotential surfaces, i.e. the pressure p in decibars
        is approximated by the depth in meters.
       
        ** Method  :  
        nn_eos = 0 : Jackett and McDougall (1994) equation of state.
        the in situ density is computed directly as a function of
        potential temperature relative to the surface (the opa t
        variable), salt and pressure (assuming no pressure variation
        along geopotential surfaces, i.e. the pressure p in decibars
        is approximated by the depth in meters.
        rho = eos_insitu(t,s,p)
        with pressure                 p        decibars
        potential temperature         t        deg celsius
        salinity                      s        psu
        reference volumic mass        rau0     kg/m**3
        in situ volumic mass          rho      kg/m**3
       
        Check value: rho = 1060.93298 kg/m**3 for p=10000 dbar,
        t = 40 deg celcius, s=40 psu
       
        References :   Jackett and McDougall, J. Atmos. Ocean. Tech., 1994
       
    AUTHOR:
        Chris Roberts (hadrr)

    LAST MODIFIED:
        2013-08-15 - created (hadrr)
    '''
    # Convert to double precision
    ptem   = np.double(t)    # potential temperature (celcius)
    psal   = np.double(s)    # salintiy (psu)
    depth  = np.double(z)    # depth (m)
    rau0   = np.double(1035) # volumic mass of reference (kg/m3)
    # Read into eos_insitu.f90 varnames  
    zrau0r = 1 / rau0
    zt     = ptem
    zs     = psal
    zh     = depth
    zsr    = np.sqrt(np.abs(psal))   # square root salinity
    # compute volumic mass pure water at atm pressure
    zr1 = ( ( ( ( 6.536332e-9*zt-1.120083e-6 )*zt+1.001685e-4)*zt-9.095290e-3 )*zt+6.793952e-2 )*zt+999.842594
    # seawater volumic mass atm pressure
    zr2    = ( ( ( 5.3875e-9*zt-8.2467e-7 ) *zt+7.6438e-5 ) *zt-4.0899e-3 ) *zt+0.824493
    zr3    = ( -1.6546e-6*zt+1.0227e-4 ) *zt-5.72466e-3
    zr4    = 4.8314e-4
    #  potential volumic mass (reference to the surface)
    zrhop  = ( zr4*zs + zr3*zsr + zr2 ) *zs + zr1
    # add the compression terms
    ze     = ( -3.508914e-8*zt-1.248266e-8 ) *zt-2.595994e-6
    zbw    = (  1.296821e-6*zt-5.782165e-9 ) *zt+1.045941e-4
    zb     = zbw + ze * zs
    zd     = -2.042967e-2
    zc     =   (-7.267926e-5*zt+2.598241e-3 ) *zt+0.1571896
    zaw    = ( ( 5.939910e-6*zt+2.512549e-3 ) *zt-0.1028859 ) *zt - 4.721788
    za     = ( zd*zsr + zc ) *zs + zaw
    zb1    =   (-0.1909078*zt+7.390729 ) *zt-55.87545
    za1    = ( ( 2.326469e-3*zt+1.553190)*zt-65.00517 ) *zt+1044.077
    zkw    = ( ( (-1.361629e-4*zt-1.852732e-2 ) *zt-30.41638 ) *zt + 2098.925 ) *zt+190925.6
    zk0    = ( zb1*zsr + za1 )*zs + zkw
    # Caculate density
    prd    = (  zrhop / (  1 - zh / ( zk0 - zh * ( za - zh * zb ) )  ) - rau0  ) * zrau0r
    rho    = (prd*rau0) + rau0
    return rho - 1000

def balance_salinity(perturbed, original, lsm):

    ## set initial values for EoS
    t0 = original.tn.values
    s0 = original.sn.values
    z = original.nav_lev.values[None,:,None,None]

    ## find initial density, set delta salinity & tolerance
    rho0 = np.where(lsm,eos_insitu(t0,s0,z),0)
    rho_tol = 1e-12
    s_incr = 0.01

    ## set initial salinity, temperature values
    t = perturbed.tn.values
    s = s0.copy()

    ## initial EoS compute
    rho = np.where(lsm,eos_insitu(t,s,z),0)
    drho = rho - rho0

    niter=0
    while np.any(np.abs(drho) > rho_tol):
        niter+=1
        print(f'interation {niter} max diff:',np.max(np.abs(drho)),flush=True)
        drho_ds = (rho - eos_insitu(t,s+s_incr,z)) / s_incr
        ds = drho / drho_ds
        s += ds
        rho = np.where(lsm,eos_insitu(t,s,z),0)
        drho = rho - rho0

    ## set the final salinity field to be all POSITIVE values computed
    s = xr.zeros_like(original.sn)+np.where(s>=0,s,0)

    perturbed['sn'] = s

    return perturbed

def regrid_to_orca1(path_to_regrid,output_path,horz_griddes='/perm/frmw/orca1_griddes.txt'):
    cdo = Cdo()
    horz_grid = horz_griddes
   
    ### generate weights file for regridding
    horz_wts = cdo.genbil(horz_grid,input=path_to_regrid)
    cdo.remap(horz_grid+','+horz_wts,input=path_to_regrid,output=output_path)

def regrid_and_process(year, scratch_dir, hindcast_dir, half_output_dir, doub_output_dir, perm_dir, horz_griddes='/perm/frmw/orca1_griddes.txt'):

    regrid_to_orca1(f"{hindcast_dir}/best_{year}_ensmean.nc",f"{hindcast_dir}/best_{year}_ensmean_regridded.nc",horz_griddes)
    regrid_to_orca1(f"{hindcast_dir}/half_{year}_ensmean.nc",f"{hindcast_dir}/half_{year}_ensmean_regridded.nc",horz_griddes)
    regrid_to_orca1(f"{hindcast_dir}/doub_{year}_ensmean.nc",f"{hindcast_dir}/doub_{year}_ensmean_regridded.nc",horz_griddes)
    
    # Load datasets
    ds_cera = xr.open_dataset(f"{scratch_dir}/cera_{year}.nc")
    ds_best = xr.open_dataset(f"{hindcast_dir}/best_{year}_ensmean_regridded.nc")
    ds_half = xr.open_dataset(f"{hindcast_dir}/half_{year}_ensmean_regridded.nc")
    ds_doub = xr.open_dataset(f"{hindcast_dir}/doub_{year}_ensmean_regridded.nc")

    # Load land-sea mask
    ds_lsm = xr.open_dataset(f"{perm_dir}/lsm_orca1.nc")

    # Adjust datasets
    ds_best = ds_best.rename({'deptht':'z','time_counter':'t'}).drop_vars(('t','nav_lat','nav_lon','z'))
    ds_half = ds_half.rename({'deptht':'z','time_counter':'t'}).drop_vars(('t','nav_lat','nav_lon','z'))
    ds_doub = ds_doub.rename({'deptht':'z','time_counter':'t'}).drop_vars(('t','nav_lat','nav_lon','z'))

    # Calculate differences
    ds_halfMinusBest = ds_half - ds_best
    ds_doubMinusBest = ds_doub - ds_best

    # Create perturbed datasets
    ds_cera_halfPert = ds_cera.copy()
    ds_cera_halfPert['tn'] = ds_cera_halfPert['tn'] + ds_halfMinusBest.votemper[3, :, :, :]

    ds_cera_doubPert = ds_cera.copy()
    ds_cera_doubPert['tn'] = ds_cera_doubPert['tn'] + ds_doubMinusBest.votemper[3, :, :, :]

    # Balance salinity
    balance_salinity(ds_cera_halfPert, ds_cera, ds_lsm.lsm)
    balance_salinity(ds_cera_doubPert, ds_cera, ds_lsm.lsm)

    # Save outputs
    ds_cera_halfPert.to_netcdf(f"{half_output_dir}/{year}_halfPert.nc")
    ds_cera_doubPert.to_netcdf(f"{doub_output_dir}/{year}_doubPert.nc")

#Run script
if __name__ == "__main__":
    # Parse command-line arguments
    year = int(sys.argv[1])
    scratch_dir = sys.argv[2]
    hindcast_dir = sys.argv[3]
    half_output_dir = sys.argv[4]
    doub_output_dir = sys.argv[5]
    perm_dir = sys.argv[6]

    # Run the processing function
    regrid_and_process(year, scratch_dir, hindcast_dir, half_output_dir, doub_output_dir, perm_dir)
