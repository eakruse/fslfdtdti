#!/bin/tcsh -f
###make sure you are running this script on mabo!! eddy_cuda needs a GPU BK 10/27/21
setenv cr /nfs/agency/code

setenv ulb  ${cr}/proc2;

setenv vrb 1
unsetenv vrb
source $ulb/tci.alias.sh;
## setenv cr /nfs/ep-index/TC.Nflm
###################
set SRoot = /nfs/agency;
set dcm = ${SRoot}/raw_data/scans;
set nii = ${SRoot}/diffusion/nifti;
set rez = ${SRoot}/diffusion/subjects;
set fsldir = /nfs/pkg64/fsl_6.0.5/bin;
set dcm2niidir = /home/lesh/dtitools/mricrogl_lx;

echo argv = $argv
if ( $#argv != 1 )  then 
	 echo "Usage: script.sh subject_name";
	 exit;
endif
set snam = ${1}; echo "DTI processing started for $snam"

## Setting environment for new FSL
source /nfs/agency/code/set_FS711mabo_agency.sh;

### folders 
set sdcm = ${dcm}/${snam}; tca_chkd ${sdcm}
set snii = ${nii}/${snam}; mkdir -p ${snii}; tca_chkd ${snii};
set srez = ${rez}/${snam}; mkdir -p ${srez}; tca_chkd ${srez};


# ------------------------------------------------------------------
###  this is the cvrtr: Convert sorted-dcm to nii
# ------------------------------------------------------------------
set mpr_id   = ( _mprageFS 0001.dcm );
set multd_id = ( _cmrr_2iso_mb4_A__P 0001.dcm );
set pa_id = (_cmrr_2iso_mb4_P__A 0001.dcm );
set dcm2niidir = /home/lesh/dtitools/mricrogl_lx
if (-f $snii/pa) then
	echo "Skipping Dicom Conversion"
	else
foreach i ( multd )
	 echo Converting $i dicom to nifti
	 [ -f $snii/$i/orig.nii.gz ] && continue
	 set var = `echo \${${i}_id}`
	 set val = `eval echo $var`
	 set tmp_dcm = `ls ${sdcm}/*${val[1]}/${val[2]}`;
	 set dir_dcm = `ls -d ${sdcm}/*${val[1]} | head -n 1`;
	 echo $tmp_dcm
	 mkdir -p ${snii}/${i}
	 ${dcm2niidir}/dcm2niix -d n -e n -f orig -i n -z y -o ${snii}/${i} ${dir_dcm}
	 echo ${tmp_dcm[1]} > ${snii}/${i}/orig.dcm.txt
end

foreach i ( pa )
	 echo Converting $i dicom to nifti
	 [ -f $snii/$i/orig.nii.gz ] && continue
	 set var = `echo \${${i}_id}`
	 set val = `eval echo $var`
	 #set tmp_dcm = `ls ${sdcm}/*${val[1]}/${val[2]}`;
	 set dir_dcm = ${sdcm}/*P__A ;
	 #echo $tmp_dcm
	 mkdir -p ${snii}/${i}
	 ${dcm2niidir}/dcm2niix -d n -e n -f orig -i n -z y -o ${snii}/${i} ${dir_dcm}
	 #echo ${tmp_dcm[1]} > ${snii}/${i}/orig.dcm.txt
end
foreach i ( mpr )
	 echo Converting $i dicom to nifti
	 [ -f $snii/$i/orig.nii.gz ] && continue
	 set var = `echo \${${i}_id}`
	 set val = `eval echo $var`
	 set tmp_dcm = `ls ${sdcm}/*${val[1]}/${val[2]}`;
	 set dir_dcm = `ls -d ${sdcm}/*${val[1]} | head -n 1`;
	 echo $tmp_dcm
	 mkdir -p ${snii}/${i}
#	 $ulb/d2n.sh $snii/$i ${tmp_dcm[1]}
	 ${dcm2niidir}/dcm2niix -d n -e n -f orig -i n -z y -o ${snii}/${i} ${dir_dcm}
	 echo ${tmp_dcm[1]} > ${snii}/${i}/orig.dcm.txt
end
endif
# ------------------------------------------------------------------
### DTI.TC basic preprocessing
# ------------------------------------------------------------------
set dtiTC = ${srez}/dti.TC; mkdir -p ${dtiTC}; pushd ${dtiTC} > /dev/null
## get the dcm's
set dcmf = `cat ${snii}/multd/orig.dcm.txt`;
set dcmd = `dirname $dcmf`;
echo $dcmd

[ -f b.bvec ] || ${cr}/cvrtr/lines2cols.R ${snii}/multd/orig.bval ${snii}/multd/orig.bvec b.bvec;
[ -f b.bval ] || cat ${snii}/multd/orig.bval | tr " " "\n" > b.bval;
### ------------------------------------------------------------------
### split by acquisition
### ------------------------------------------------------------------
mkdir -p osplit; pushd osplit > /dev/null;
[ -f 0000.nii.gz ] || fslsplit ${snii}/multd/orig '' -t;
popd > /dev/null;
## automatically forming shels
set shlb = `awk '{ print 50*int( $1 / 50 + .2) }' b.bvec | sort -nu `;
## ------------------------------------------------------------------
# b.tc and shell.tc files
## ------------------------------------------------------------------
#tyler changed this to add the actual bvector to the last column of the b.tc file, then it can be grabbed later for eddy and FDT
if ( ! -f b.tc ) then 
	 awk '{printf "%3d,%4d, %+9.6f, %+9.6f, %+9.6f, %4d\n",\
		  (NR-1),50*int($1/50+.2),$2,$3,$4,$1}' b.bvec | sed 's/+/ /g' > b.tc
endif
###!!! assume b.tc is correct !!!
## variable defined tjhrough their names!!!
foreach i ( $shlb )
	 set nam = shlng${i};
	 eval set $nam = 0
end
## scan and increase acording to the name
foreach i ( `awk -F, '{print $2}' b.tc` )
	 eval set nam = shlng${i};
	 eval @ $nam = \${$nam} + 1 
end
## split by shell
foreach i ( `seq 1 $#shlb` )
	 set fnam = "shell$shlb[$i].tc";
	 [ -f $fnam ] && continue
	 set gval = `printf ",%4d," $shlb[$i] | sed 's/\ /\\ /g' `;
	 grep "$gval" b.tc > $fnam
end
## do the data moving
foreach i ( `seq 1 $#shlb` )
	 set fnam = "shell$shlb[$i].tc"
	 [ ! -f $fnam ] && continue
	 set dnam = "shell$shlb[$i]";
	 [ -d $dnam ] && continue;
	 mkdir -p $dnam;
	 # awk -v dnam="$dnam" -F, \
	 # 	  '{printf "cp -u ./osplit/%04d.nii.gz "dnam"\n", $1}' $fnam | tcsh -s;  
	 awk -v dnam="$dnam" -F, \
		  '{printf "ln -s ../osplit/%04d.nii.gz "dnam"\n", $1}' $fnam | tcsh -s;  
end

## 4d files, and their averages, limit to shell of interest, only
set shlb = ( 0 1000 );
foreach i ( `seq 1 $#shlb` )
	 set dnam = "shell$shlb[$i]"; 
    ##??##[ ! -d $dnam ] && continue;
	 ## the 4d shells 
	 [ -f $dnam.nii.gz ] ||	 fslmerge -t $dnam $dnam/*;
	 set bnam = b$shlb[$i];
	 if ( ! -f $bnam.nii.gz ) then 
		  fslmaths `ls -1 ${dnam}/*.nii.gz | head -1` -mul 0. $bnam -odt float;
		  set tmpn = 0;
		  foreach n ( ${dnam}/*.nii.gz )
				##-- flirt -in b0/$b0list[$n] -ref b0 -out tmpB -nosearch -dof 6;
				fslmaths $n tmpB -odt float;
				fslmaths $bnam -add tmpB $bnam;
				@ tmpn = 1 + $tmpn
				#echo $tmpn
		  end
		  fslmaths $bnam -div $tmpn $bnam && rm tmpB.nii.gz;
		  bet $bnam ${bnam}b -m -f .3;
	 endif
end
popd > /dev/null; ## pushd ${dtiTC} > /dev/null

# ------------------------------------------------------------------
### DTI.REC
# ------------------------------------------------------------------
## where the magic happens

set dtiREC = ${srez}/dti.REC.b1000_woBadVols; 
##what is this directory below?? NCAP never uses it, is it needed for other projects? BK 4/6/2022
#set mprDTI = ${srez}/mpr.DTI.b1000_woBadVols; 
###################
mkdir -p ${dtiREC}; 
## create the auto plan
set b_0 = 0; 
set b_H = 1000; 

end_setdtirec:

begin_dtiREC:
pushd $dtiREC > /dev/null
if ( ! -f plan.tcX ) then 
	 echo "Need a plan.tcX in "`pwd`;
	 exit;
endif

set allb_0 = `awk -F, -v bv=$b_0 \
	 '{ if (bv == $2) print $1; }' plan.tcX`;
set allb_H = `awk -F, -v bv1=$b_H \
	 '{ if ( bv1 == $2 )  print $1;}' plan.tcX `;

### gather by b
set loc0 = b${b_0}; mkdir -p $loc0; 
pushd $loc0 > /dev/null;
mkdir -p raw; 
foreach i ( ${allb_0} )
	 set inf = `printf "${dtiTC}/osplit/%04d.nii.gz" ${i}`;
	 cp -u ${inf} raw;
end
popd > /dev/null ## pushd $loc0 > /dev/null;

set locH = $dtiREC/bH; mkdir -p $locH; 
pushd $locH > /dev/null;
mkdir -p raw; 
foreach i ( ${allb_H} )
	 set inf = `printf "${dtiTC}/osplit/%04d.nii.gz" ${i}`;
	 cp -u ${inf} raw;
end
popd > /dev/null ## pushd $locH > /dev/null;

###################Beginning of TopUp
#############topup now runs on all servers 8/13/21 BK
##since we are no longer using the below topup directories to run the topup command, i don't think we need all of these. really we only need one for the topup output. check w/tyler 4/5/2022 BK
mkdir -p ${dtiREC}; 
mkdir -p ${dtiREC}/topup
echo "Finding ${snam} AP and PA raw data"

#acq param file based on echo spacing of 0.72 divided by 2 for grappa multipled by .001 multiplied by 105
#changed acqparams to count the raw files in b0 directory and single pa b0 BK 11/9/21
        if ( -f ${dtiREC}/acq_param.txt ) then
			echo "Aquisition parameters already generated"
		  else
			set b0vols = `ls ${loc0}/raw | wc -l`
			touch acq_param.txt
			repeat ${b0vols} echo 0 1 0 0.0378 > ${dtiREC}/acq_param.txt
			echo 0 -1 0 0.0378 >> ${dtiREC}/acq_param.txt
	endif

#merge and topup
echo "Performing topup on ${snam}"
echo ${dtiREC}
echo ${fsldir}
echo $FSLDIR
##changing below bc we need to merge the b0s in the loc0 raw folder and the single PA to have all b0s BK 11/9/21
     if ( -f ${loc0}/raw/*.nii.gz ) $$ ( -f ${snii}/pa/orig.nii.gz) then 
	 [ -f ${loc0}/$snam\_allb0s.nii.gz ] ||\
				${fsldir}/fslmerge -t ${loc0}/$snam\_allb0s.nii.gz ${loc0}/raw/*.nii.gz ${snii}/pa/orig.nii.gz;
         [ -f ${dtiREC}/topup/iout_b0_$snam.nii.gz ] ||\
				${fsldir}/topup --imain=${loc0}/$snam\_allb0s.nii.gz --datain=${dtiREC}/acq_param.txt \
				--config=/nfs/pkg64/fsl_6.0.5/etc/flirtsch/b02b0_2.cnf --out=${dtiREC}/topup/topup_b0_$snam \
				--fout=${dtiREC}/topup/fout_b0_$snam --iout=${dtiREC}/topup/iout_b0_$snam;

############End of Topup
############Beginning of BET

### group/proc by b
## process b = 0, select/construct the b0 brain, here just take the mean
set loc0 = $dtiREC/b0; mkdir -p $loc0; 
pushd $loc0 > /dev/null; 
echo "Merge and average distortion corrected b0"
[ -f hifi_nodif.nii.gz ] || fslmaths ${dtiREC}/topup/iout_b0_$snam.nii.gz -Tmean $loc0/hifi_nodif.nii.gz;
[ -f hifi_nodif_brain.nii.gz ] || bet $loc0/hifi_nodif.nii.gz $loc0/hifi_nodif_brain.nii.gz -f .2 -m;

popd > /dev/null ## pushd $loc0 > /dev/null;

### process HIGH, construct the tensor
set locH = $dtiREC/bH; mkdir -p $locH; 
pushd $locH > /dev/null;
## combine the b0, bL, and bH to prepare for eddy script
echo "Preparing b0 bL and bH for eddy"
[ -d ${dtiREC}/eddy_prep ] || mkdir -p ${dtiREC}/eddy_prep; 
[ -f ${dtiREC}/eddy_prep/hifi_nodif_brain_mask.nii.gz ] || cp -u $loc0/hifi_nodif_brain_mask.nii.gz ${dtiREC}/eddy_prep/;
[ -f ${dtiREC}/eddy_prep/hifi_nodif.nii.gz ] || cp -u $loc0/hifi_nodif.nii.gz ${dtiREC}/eddy_prep/;
###changed pipeline to eddy correct the raw 4d file in order 
##added raw b0s below because they should be included in our eddy data, which they weren't prior BK 11/9/21 can't use the topup/A__P because it still has the bad volumes
##copying b0s and bHs into same directory to merge correctly
[ -d ${locH}/raw0H ] || mkdir -p ${locH}/raw0H;
echo "Copying raw b0s and bHs"
[ -f  ${dtiREC}/eddy_prep/all4d.nii.gz ] || cp -u ${locH}/raw/*nii.gz ${locH}/raw0H;
[ -f  ${dtiREC}/eddy_prep/all4d.nii.gz ] || cp -u ${loc0}/raw/*nii.gz ${locH}/raw0H;
#combine b0s and bHs for eddy raw 4d
echo "Generating raw4d image for eddy"
[ -f  ${dtiREC}/eddy_prep/all4d.nii.gz ] || fslmerge -t ${dtiREC}/eddy_prep/all4d ${locH}/raw0H/*nii.gz; 

if (! -d FDT) then
	mkdir FDT
endif

pushd FDT > /dev/null

##changed to grab all bvals, before it was leaving out b0s BK 11/10/21
if ( ! -f bvecs ) then
	echo "Generating bvals file"
#get bval string
        set bv0H = `awk -F, '{ if ($2 < 1005) print $6;}' ../../plan.tcX `;
	echo $bv0H > bvaltmp;
	cat bvaltmp | tr "\n" " " > bvals
#output bx vecs
	echo "Generating bvecs file"
	set bx0H = `awk -F, '{ if ($2 < 1005) print $3;}' ../../plan.tcX `;
	echo $bx0H > bvec_x_tmp;
	cat bvec_x_tmp | tr "\n" " " > bvec_x
#output by vecs
	set by0H = `awk -F, '{ if ($2 < 1005) print $4;}' ../../plan.tcX `;
	echo $by0H > bvec_y_tmp;
	cat bvec_y_tmp | tr "\n" " " > bvec_y
#output bz vecs
	set bz0H = `awk -F, '{ if ($2 < 1005) print $5;}' ../../plan.tcX `;
	echo $bz0H > bvec_z_tmp;
	cat bvec_z_tmp | tr "\n" " " > bvec_z
	touch bvecs
	foreach vec (bvec_x bvec_y bvec_z)
	 	cat ${vec} >> bvecs
	 	echo >> bvecs
	end
endif

#count the number of volumes 
##changed below to generate index list that points to the nearest b0 volume for each gradient BK 11/10/21
if ( ! -f $locH/FDT/index.txt ) then
	echo "Generating index list"
		set index = index_list.txt
		set thre = 100
		if (! -e $index ) then
		endif
		@ i = 1
		set All_bval = `cat bvals`
		foreach item ($All_bval)
			echo $item
			set item = `/usr/bin/printf '%.0f\n' $item`
			echo $item
			if ( $item < 100 ) then
				echo $i >> $index
				@ i+=1
			else 
				@ i-=1
				echo $i >> $index
				@ i+=1
			endif
		#finding and replacing any 0s in index list (occurs if first b0 volume is removed during QC)
		sed -i 's/0/1/g' index_list.txt
		cat index_list.txt | tr "\n" " " > index.txt
		end
	else 
		echo "index files already exists"
endif

#####Beginning of eddy
###warning do not use wildcards code will crash BK 4/7/22
if ( ! -f ${dtiREC}/eddy_prep/eddy_unwarped_images.nii.gz ) then
echo "Running eddy"
eddy_cuda9.1 --imain=${dtiREC}/eddy_prep/all4d.nii.gz --mask=${dtiREC}/eddy_prep/hifi_nodif_brain_mask.nii.gz --acqp=${dtiREC}/acq_param.txt --index=${dtiREC}/bH/FDT/index.txt --bvecs=${dtiREC}/bH/FDT/bvecs --bvals=${dtiREC}/bH/FDT/bvals --topup=${dtiREC}/topup/topup_b0_${snam} --repol --cnr_maps --out=${dtiREC}/eddy_prep/eddy_unwarped_images --mporder=6 --slspec=/nfs/agency/diffusion/slspec.txt --s2v_niter=5 --s2v_lambda=1 --s2v_interp=trilinear
endif

if ( ! -f ${dtiREC}/eddy_prep/eddy_brain_mask.nii.gz ) then
	 echo "Masking eddy corrected data"
	 fslmaths ${dtiREC}/eddy_prep/eddy_unwarped_images.nii.gz -mas ${dtiREC}/eddy_prep/hifi_nodif_brain_mask.nii.gz ${dtiREC}/eddy_prep/eddy_brain_mask.nii.gz
endif
echo Making eddy ${snam} output directory
mkdir -p ${rez}/eddy/${snam}
if ( ! -f ${rez}/eddy/${snam}/eddy_brain_mask.nii.gz ) then
	 echo "Copying eddy data to eddy directory for ${snam}"
	 cp ${dtiREC}/eddy_prep/eddy_brain_mask.nii.gz ${rez}/eddy/${snam}/eddy_brain_mask.nii.gz
endif

if ( ! -f ${rez}/eddy/${snam}/rotatedbvecs ) then
	 cp ${dtiREC}/eddy_prep/eddy_unwarped_images.eddy_rotated_bvecs ${rez}/eddy/${snam}/rotatedbvecs
endif

if ( ! -f ${rez}/eddy/${snam}/bvals ) then
	 cp ${dtiREC}/bH/FDT/bvals ${rez}/eddy/${snam}/bvals
endif

#####end of Eddy




