#!/bin/tcsh -f

setenv cr /nfs/agency/code

setenv ulb  ${cr}/proc2;

setenv vrb 1
unsetenv vrb
source $ulb/tci.alias.sh;
## setenv cr /nfs/ep-index/TC.Nflm
###################
set SRoot = /nfs/agency;
set rez = ${SRoot}/diffusion/subjects;
set fsldir = /nfs/pkg64/fsl_6.0.5/bin;

echo argv = $argv
if ( $#argv != 1 )  then 
	 echo "Usage: script.sh subject_name";
	 exit;
endif
set snam = ${1}; "echo BEDPOSTX processing started for $snam"

##need to see if these directories are still accurate after most recent changes to pipeline BK 1/4/21

### folders 
set srez = ${rez}/${snam}; 
set dtiREC = ${srez}/dti.REC.b1000_woBadVols; 

## Setting environment for new FSL
source /nfs/agency/code/set_FS711mabo_agency.sh;

##creating bedpostx directory structure
if ( ! -f ${srez}/bedpostX ) then
	echo "Making bedpostx directory structure"

	mkdir -p ${srez}/bedpostX;
	mkdir -p ${srez}/bedpostX/input/;
	mkdir -p ${srez}/bedpostX/diff_slices;
	mkdir -p ${srez}/bedpostX/logs;
	mkdir -p ${srez}/bedpostX/logs/monitor;
	mkdir -p ${srez}/bedpostX/xfms;
endif

cp ${dtiREC}/eddy_prep/eddy_unwarped_images.nii.gz ${srez}/bedpostX/input/data.nii.gz
cp ${dtiREC}/eddy_prep/eddy_unwarped_images.eddy_rotated_bvecs ${srez}/bedpostX/input/bvecs
cp ${dtiREC}/bH/FDT/bvals ${srez}/bedpostX/input/bvals
cp ${dtiREC}/eddy_prep/hifi_nodif_brain_mask.nii.gz ${srez}/bedpostX/input/nodif_brain_mask.nii.gz

##Beginning of bedpostX
echo "Processing ${snam}" 
bedpostx  ${srez}/bedpostX/input --nf=3 --bi=1000
echo "${snam} BedpostX processing finished"
exit
##Beginning of flirt
echo "Running registration for ${snam}"
##i thiiiink bedpost appends ".bedpostX" on the end of input after running, reflected that in the paths below BK 9/22/21

cp ${dtiREC}/eddy_prep/hifi_nodif_brain_mask.nii.gz ${srez}/bedpostX/input.bedpostX/hifi_nodif_brain_mask.nii.gz
flirt -in ${srez}/bedpostX/input.bedpostX/hifi_nodif_brain_mask.nii.gz -ref  
