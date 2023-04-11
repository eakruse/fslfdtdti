#!/usr/bin/tcsh -f
#!/bin/tcsh -f


#export PATH=/nfs/agency/code/DTI/dtitools/DTIPrepTools-1.2.11/bin:$PATH
#echo $PATH
if ( $#argv != 1 )  then 
	 echo "Usage: script.sh subject_name";
	 exit;
endif
set sub = ${1}; echo "DTIPrep QA started for $sub"
set slicedir = /nfs/agency/code/DTI/dtitools/Slicer-4.11.20210226-linux-amd64;
set dtiprepdir = /nfs/agency/code/DTI/dtitools/DTIPrepTools-1.2.11/bin;
set niicnvdir = /nfs/agency/code/DTI/dtitools/conversion/conversion;
set rawdir = /nfs/agency/raw_data/scans;
set dtioutdir = /nfs/agency/diffusion/dtiprep;

set startdir = `pwd`
echo argv = $argv
##indicate what protocol xml file you would like to use here
set protocol = /nfs/agency/code/DTI/dtiprep_xml/ncap_dtiprep_protocol.xml 

echo "Processing DTI QA using DTIPrep protocol ${protocol}"
cd ${rawdir}
if ( -d ${rawdir}/${sub} ) then 
	 #if raw data exists then proceed
	 echo "Raw dicoms for ${sub} exist"
	 if ( -d ${dtioutdir}/${sub} ) then
		  echo "${sub} directory already created"
	 else
		  mkdir ${dtioutdir}/${sub}
	 endif
	 if ( -f ${dtioutdir}/${sub}/${sub}_AP_DWI.nrrd ) then
		  echo "${sub} nrrd already created"
	 else
		  echo "Converting ${sub} Dicom to NRRD"
		 ${slicedir}/Slicer --launch DWIConvert -i ${rawdir}/${sub}/*_cmrr_2iso_mb4_A__P -o ${dtioutdir}/${sub}/${sub}_AP_DWI.nrrd --conversionMode DicomToNrrd
	 endif
	 if ( -f ${dtioutdir}/${sub}/${sub}_AP_DWI_XMLQCResult.xml ) then
		  echo "${sub} QC already completed"
	 else
		  echo "Performing DTIPrep QA for ${sub}"
		  DTIPrep -w ${dtioutdir}/${sub}/${sub}_AP_DWI.nrrd -c -p ${protocol} --numberOfThreads 4
	 endif
	 if ( -f ${dtioutdir}/${sub}/${sub}_AP_DWI_QCed.nii.gz ) then
	 	  echo "${sub} QCed files already converted to niftis"
         else 
		  echo "Converting ${sub} QCed files back to niftis"
		  /nfs/agency/code/DTI/dtitools/DWIConvert_5.3.0 --inputVolume ${dtioutdir}/${sub}/${sub}_AP_DWI_QCed.nrrd -o ${dtioutdir}/${sub}/${sub}_AP_DWI_QCed.nii.gz --outputBVectors ${dtioutdir}/${sub}/${sub}_AP_DWI_QCed.bvec --outputBValues ${dtioutdir}/${sub}/${sub}_AP_DWI_QCed.bval  --allowLossyConversion --conversionMode NrrdToFSL
		# ${niicnvdir}/nifti_write.py -i ${dtioutdir}/${sub}/${sub}_AP_DWI.nrrd -p ${dtioutdir}/${sub}/${sub}_AP_DWI_QCed 
	 endif	
else
	 echo "Subject ${sub} scan raw data directory does not exist"
endif


cd ${startdir}
