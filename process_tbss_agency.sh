#!/bin/tcsh -f

setenv cr /nfs/agency/code

setenv ulb  ${cr}/proc2;

setenv vrb 1
unsetenv vrb
source $ulb/tci.alias.sh;
## setenv cr /nfs/ep-index/TC.Nflm
###################
set SRoot = /nfs/agency;
##you need to change the grp setting to the new group analysis folder you've created and are using
set grp = ${SRoot}/diffusion/group_analysis_042022/tbss;
set fsldir = /nfs/pkg64/fsl_6.0.5/bin;


## Setting environment for new FSL
source /nfs/agency/code/set_FS711mabo_agency.sh;


####Beginning of tbss
pushd ${grp} > /dev/null;

echo "Running tbss step 1"
#erosion of masks to get rid of any FA artifacts
tbss_1_preproc *nii.gz
#check slicesdir output to make sure everything looks ok before doing next step 
echo "Check slicesdir output - script pausing for 5 minutes"
sleep 5m

echo "Running tbss step 2"
#estimate warping parameters to standardized space
#using recommended standard-space image as the target 
tbss_2_reg -T 

echo "Running tbss step 3"
#applying above estimations and creating mean FA images
tbss_3_postreg -S;
#compare mean FA to standard MNI T1 to make sure white matter pathways look ok
#compare merged imaged ("all_FA") and mean FA skeleton to see if it is suitable for all subjects
echo "compare mean FA to standard MNI T1 & all_FA to mean FA skeleton - script pausing for 7 minutes"
sleep 7m

#now, check whether 0.2 (typical value used) is a suitable threshold for the mean FA skeleton in next step

echo "Running tbss step 4"
#projecting pre-aligned FA data onto tracted skeleton
#change 0.2 with another value if more appropriate for the data set
tbss_4_prestats 0.2;

####Beginning of voxelwise statistics on the skeletonised FA data
###WARNING: having it embedded here ONLY runs stats on group comparisons on overall FA. if you want to run other analyses (ie. against symptom score or task metrics, you need to create new .mat's & .con's and run it in the command line) 4/6/22 BK
pushd ${grp}/tbss/stats > /dev/null;
echo "Generating contrasts"
design_ttest2 design 17 20 # # need to fill in with the number of controls in patients in our data set
randomise -i all_FA_skeletonised -o tbss -m mean_FA_skeleton_mask -d design.mat -t design.con -n 500 --T2
#this would need to be run on bob to open fslview
fslview ${fsldir}/data/standard/MNI152_T1_1mm mean_FA_skeleton -1 Green -b 0.2,0.8 tbss_tstat1 -1 Red-Yellow -b 3,6 tbss_tstat2 -1 Blue-Lightblue -b 3,6

