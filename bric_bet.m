function status = bric_bet(GREfilename,seq2filename,ICVfilename)
% This function extracts the intracranial volume from gradient echo MRI or
% from a combination between GRE and another T2_based sequence(T2-weighted or FLAIR)
% 
% Uses the following libraries: 
% NIFTI (http://uk.mathworks.com/matlabcentral/fileexchange/8797-tools-for-nifti-and-analyze-image)
% BRIClib
% fsl (http://fsl.fmrib.ox.ac.uk/fsl/fslwiki/)
% Inputs:
%       GREfilename --> path and filename of the GRE or SWI sequence
%       seq2filename --> path and filename of the T2-based sequence. If no sequence is available, enter an empty string '' or parentheses
%       ICVfilename --> path and filename of the ICV
% Examples:
%        bric_bet('C:/GREimage','C:/T2Wimage','C:/output_folder/ICV');
%        bric_bet('C:/GREimage','','C:/output_folder/ICV');
% 		 bric_bet('C:/GREimage',[],'C:/output_folder/ICV');
% Output:
%        The ICV binary mask in nifti or nifti gzip formats
%
% Authors: 
%        Maria C. Vald�s Hern�ndez (M.Valdes-Hernan@ed.ac.uk)
%        David A. Dickie (david.dickie@ed.ac.uk) 
%

% Check OS is linux
if ~isunix
    error('bric_bet only can run in unix-based OS');
end

if isempty(seq2filename) % use only the gradient echo as input
    try
        % Correct h1 bias field inhomogeneities
        eval(['!fast -b -B ',GREfilename]);
        
        % Checking that the bias field corrected GRE image is valid
        [GRE,~] = load_series([GREfilename,'_restore'],[]);
        V = var(double(GRE(:)));
        if isnan(V)
		    warning('The h1 bias field correction of the GRE image was unsuccessful');
			display('... Extracting the ICV in the original GRE image ...');
            % Extract the brain in the original GRE image
            eval(['!bet2 ',GREfilename,' ',ICVfilename,' -m']); % calls fsl bet to do an initial skull stripping
			delete([GREfilename,'_bias*']);
            delete([GREfilename,'_restore*']);
            [GRE,~] = load_series(GREfilename,[]);
        else
            % Extract the brain in the bias field corrected (restored) image
            eval(['!bet2 ',[GREfilename,'_restore'],' ',ICVfilename,' -m']); % calls fsl bet to do an initial skull stripping
            [GRE,~] = load_series([GREfilename,'_restore'],[]);
        end
        % Save the brain mask in 8 bits format
        eval(['!fslmaths ',[ICVfilename,'_mask'],' ',[ICVfilename,'_mask'],' -odt char']);
        
        delete([GREfilename,'_pve*']);
        delete([GREfilename,'_seg*']);
        delete([GREfilename,'_mixeltype*']);
    catch
        error(status_str(2));
        status = 2;
        return;    
    end
else
    try
        % Adjust the image range, setting the max and minimum to the full data range
        eval(['!fslmaths ',GREfilename,' -range ',[GREfilename,'_adjusted']]);
        eval(['!fslmaths ',seq2filename,' -range ',[seq2filename,'_adjusted']]);
		
        % Correct h1 bias field inhomogeneities in GRE
        eval(['!fast -b -B ',[GREfilename,'_adjusted']]);
        % Checking that the bias field corrected GRE image is valid
        [GRE,~] = load_series([GREfilename,'_adjusted_restore'],[]);
        V = var(double(GRE(:)));
        if isnan(V)
		    warning('The h1 bias field correction of the GRE image was unsuccessful');
			display('... Extracting the ICV in the original GRE image ...');
            % Extract the brain in the original GRE image
            eval(['!bet2 ',GREfilename,' ',ICVfilename,' -m']); % calls fsl bet to do an initial skull stripping
 			delete([GREfilename,'_bias*']);
            delete([GREfilename,'_restore*']);
            [GRE,~] = load_series(GREfilename,[]);
            % Save the brain mask in 8 bits format
            eval(['!fslmaths ',[ICVfilename,'_mask'],' ',[ICVfilename,'_mask'],' -odt char']);    
            delete([GREfilename,'_pve*']);
            delete([GREfilename,'_seg*']);
            delete([GREfilename,'_mixeltype*']);
        else
            % Correct h1 bias field inhomogeneities in seq2
            eval(['!fast -b -B ',[seq2filename,'_adjusted']]);
            [S2,~] = load_series([seq2filename,'_adjusted_restore'],[]);
            V2 = var(double(S2(:)));
            if isnan(V2)
			    warning('The h1 bias field correction of the T2-based image was unsuccessful');
				display('... Extracting the ICV in the GRE bias field corrected image ...');
                % Extract the brain in the bias field corrected (restored) image
                eval(['!bet2 ',[GREfilename,'_restore'],' ',ICVfilename,' -m']); % calls fsl bet to do an initial skull stripping
                [GRE,~] = load_series([GREfilename,'_restore'],[]);
                % Save the brain mask in 8 bits format
                eval(['!fslmaths ',[ICVfilename,'_mask'],' ',[ICVfilename,'_mask'],' -odt char']);    
                delete([GREfilename,'_pve*']);
                delete([GREfilename,'_seg*']);
                delete([GREfilename,'_mixeltype*']);
            else
                % Rigidly register GRE to seq2
                eval(['!flirt -in ',GREfilename,' -ref ',seq2filename,' -out ',GREfilename,'_reg2seq2 -omat ',GREfilename,'_txmatrix']);
                % Invert the transformation
                eval(['!convert_xfm -omat ',GREfilename,'_invtxmatrix -inverse ',GREfilename,'_txmatrix']);
                % Apply the inverse transformation to register seq2 to GRE
                eval(['!flirt -in ',[seq2filename,'_adjusted'],'_restore -ref ',GREfilename,' -out ',seq2filename,'_reg -init ',GREfilename,'_invtxmatrix -applyxfm']);
               
                % Average both sequences to reduce susceptibility effect of haemorrhages and calcifications in the subdural space
                eval(['!fslmaths ',[GREfilename,'_adjusted'],'_restore -mul 2 -add ',seq2filename,'_reg -div 2 ',GREfilename,'_average']);
                % Extract the brain in the averaged image
                eval(['!bet2 ',GREfilename,'_average ',ICVfilename,' -m']); % calls fsl bet to do an initial skull stripping
                % Save the brain mask in 8 bits format
                eval(['!fslmaths ',ICVfilename,'_mask ',ICVfilename,'_mask -odt char']);        
                delete([GREfilename,'_adjusted_pve*']);
                delete([GREfilename,'_adjusted_seg*']);
                delete([GREfilename,'_adjusted_mixeltype*']);
                delete([seq2filename,'_adjusted_pve*']);
                delete([seq2filename,'_adjusted_seg*']);
                delete([seq2filename,'_adjusted_mixeltype*']);
                
                [GRE,~] = load_series([GREfilename,'_average'],[]);
            end
        end
    catch
        error(status_str(2));
        status = 2;
        return;    
    end
end

[ICV,~] = load_series([ICVfilename,'_mask'],[]);

ICV = double(ICV);
GRE = double(GRE);

GRE(ICV==0) = NaN;
GREstd = (GRE-nanmean(GRE(:)))./nanstd(GRE(:));
rim = double(zeros(size(GRE)));
rim(GREstd < -1.2) = 1; % Below -1, the boundary is tighter 
ICV(rim==1) = 0;

for z = 1:size(ICV,3)
    ICV(:,:,z) = imfill(ICV(:,:,z),'holes');
end
ICV = smooth3(ICV,'gaussian');

ICV1 = false(size(ICV));
% spurious_bits = zeros(size(ICV1(:,:,1)));

for z = 1:size(ICV,3)
	ICV1(:,:,z) = im2bw(ICV(:,:,z),0.3);
	spurious_bits = bwareafilt(ICV1(:,:,z),[1 20]); % This is for MATLAB R2014b and newer versions
	ICV1(:,:,z) = ICV1(:,:,z) - spurious_bits;
end


se = strel('diamond',1);
for z = 1:size(ICV1,3)
    ICV1(:,:,z) = imclose(imdilate(ICV1(:,:,z),se),se);
	ICV1(:,:,z) = imerode(imfill(ICV1(:,:,z),'holes'),se);	
end

save_series([ICVfilename,'_mask'],ICVfilename,ICV1,[]);

delete([ICVfilename,'_mask*']);
status = 0;

end

