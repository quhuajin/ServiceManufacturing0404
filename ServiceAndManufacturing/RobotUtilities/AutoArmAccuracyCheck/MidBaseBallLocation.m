function basepos = MidBaseBallLocation(ArmAccuracyData)
% choose which params are constant (0=optimize, 1=constant)
        % a, alpha, d, theta_offset
        dhp = ArmAccuracyData.DH_Matrix;
        dhp_ci= ones(size(dhp));
        dhp_ci(1,:) = ones(size(dhp_ci(1,:)));
        for i=1:ArmAccuracyData.dof,
            dhp_desc(i,:) = {['a',num2str(i)],  ...
                ['alpha',num2str(i)],...
                ['d',num2str(i)],...
                ['theta_offset',num2str(i)]}; %#ok<AGROW>
        end
        dhp_scaling = ones(size(dhp));
        
        lbb = ArmAccuracyData.lbb;
        lbb_scaling = 1;
        lbb_ci = 1;
        lbb_desc = {'lbb'};
        
        basepos = ArmAccuracyData.basePos(:);
        basepos_ci = [0 0 0]';
        basepos_scaling = [1 1 1]';
        basepos_desc = {'base_x'; 'base_y'; 'base_z'};
        
        flange = [ArmAccuracyData.FlangeTransform(1:3,4); ...
            Tx_2_YPR(ArmAccuracyData.FlangeTransform)];
        flange_ci = [1 1 1 1 1 1]';
        flange_scaling = [1 1 1 1 1 1]';
        flange_desc = {'fl_x'; 'fl_y';'fl_z'; 'fl_yaw';'fl_pitch';'fl_roll'};
        
        [pinit,cinit,var_ci,var_desc,var_scaling] = packparams(dhp,dhp_ci, ...
            dhp_desc,dhp_scaling, ...
            flange,flange_ci, ...
            flange_desc,flange_scaling, ...
            lbb,lbb_ci,lbb_desc, ...
            lbb_scaling, basepos, ...
            basepos_ci, ...
            basepos_desc, ...
            basepos_scaling);
        allDataEEpos=[];
        allData=[];
        
        for i=1:size(ArmAccuracyData.data, 2),
            allData = [allData; ArmAccuracyData.data(i).je_angles]; %#ok<AGROW>
            allDataEEpos = [allDataEEpos; ...
                ones(size(ArmAccuracyData.data(i).je_angles,1),1) * ...
                ArmAccuracyData.data(i).location(:)']; %#ok<AGROW>
        end
        numData = size(allData,1);
        
        % select 0% of Data for verification
        % use a fixed seed, so that we can reproduce the results
        % if needed
        rand('seed',10);
        indx = randperm(numData);
        %indx=1:numData;
        numFitData = round(numData*1);
        indxFitData = indx(1:numFitData);
        %         indxTestData = indx(numFitData+1:end);
        indxTestData = indxFitData;
        fitData = allData(indxFitData,:);
        fitDataEEpos = allDataEEpos(indxFitData,:);
        testData = allData(indxTestData,:);
        testDataEEpos = allDataEEpos(indxTestData,:);
        %tic
        %this part is commented out but can be used with nonlin_lsq optimization
        %           [pfit, Resnorm, resid, exitFlag, outp, lambda, jacobian] = ...
        %              nonlin_lsq('ballbar_objfun',  pinit, [], [], [], ...
        %              fitData, fitDataEEpos, ...
        %              cinit, var_ci, var_scaling);
        
        %dp=ones(size(pinit))*1.0e-6; % numerical jacobian dparameter values
        %dpmin=1.0e-10; % minimum change in parameter value
        %dfmin=1.0e-4; % minimum change in function value
        %nc=10;       % max # of iterations
        
        %this part is commented out but can be used with nonlin_lsq optimization
        %[pfit ]=lmopt('ballbar_objfun',pinit,dp,dpmin,dfmin,...
        %                1,fitDataTCL,...
        %                fitDataEEposTCL,cinit,var_ci,var_scaling);
        pinit = pinit(:); var_scaling = var_scaling(:);
        [pfitArray, info, perf, jacobian] = sec_LM( 'ballbar_objfun',  pinit, [], [], ...
            fitData, fitDataEEpos, ...
            cinit, var_ci, var_scaling);
        pfit = pfitArray(:,end);
        %toc
        resid = ballbar_objfun(pfit, fitData, ...
            fitDataEEpos, cinit, ...
            var_ci, var_scaling);
        % convert residue to millimeter
        resid=resid*1000;
        
        %verify the result using another set of data points
        resid_valid = ballbar_objfun(pfit, testData, ...
            testDataEEpos, cinit, ...
            var_ci, var_scaling);
        resid_valid=resid_valid*1000;
        
        if(true)
            [newAllData, newAllDataEEpos] = removeOutlier([resid;resid_valid], ...
                [fitData;testData], [fitDataEEpos;testDataEEpos]);
            numData = size(newAllData,1);
            numFitData = round(numData*.75);
            fitData = newAllData(1:numFitData,:);
            fitDataEEpos = newAllDataEEpos(1:numFitData,:);
            testData = newAllData(numFitData+1:end,:);
            testDataEEpos = newAllDataEEpos(numFitData+1:end,:);
%             updateMainButtonInfo(guiHandles,'text',...
%                 'Second run ... please wait');
            [pfitArray, info, perf, jacobian] = sec_LM( 'ballbar_objfun',  pinit, [], [], ...
                fitData, fitDataEEpos, ...
                cinit, var_ci, var_scaling);
            pfit = pfitArray(:,end);
            resid = ballbar_objfun(pfit, fitData, ...
                fitDataEEpos, cinit, ...
                var_ci, var_scaling)*1000;
            
            % this part is commented out but can be used with nonlin_lsq optimization
            %            [pfit, Resnorm, resid, exitFlag, outp] = ...
            %               nonlin_lsq('ballbar_objfun',  pinit, [], [], [], ...
            %               fitData, fitDataEEpos, ...
            %               cinit, var_ci, var_scaling);
            %           convert residue to millimeter
            %         resid=resid*1000;
            %          if (exitFlag == 0 )
            %          warndlg('Kincal optimization reached maximum number of evaluations',...
            %                  'Warning');
            %          end
            
            %          if (exitFlag < 0 )
            %              warndlg('Kincal optimization did not converge to a solution',...
            %                  'Warning');
            %          end
            %verify the result using another set of data points
            resid_valid = ballbar_objfun(pfit, testData, ...
                testDataEEpos, cinit, ...
                var_ci, var_scaling);
            resid_valid=resid_valid*1000;
        end
        %calculate statistical information
        mean_err_fitData = mean(resid);
        std_err_fitData =std(resid);
        rms_err_fitData = sqrt(sum(resid.^2)/length(resid));
        min_err_fitData =min(resid);
        max_err_fitData =max(resid);
  
        
        mean_err_testData = mean(resid_valid);
        std_err_testData = std(resid_valid);
        rms_err_testData = sqrt(sum(resid_valid.^2)/length(resid_valid));
        min_err_testData = min(resid_valid);
        max_err_testData = max(resid_valid);
  
        
        [dhp,flange,lbb,basepos]=unpackparams(pfit,cinit,var_ci,var_scaling);
        
        flange_tf = YPR_2_Tx(flange(4:6));      
        flange_tf(1:3,4) = flange(1:3);
        condNumJ = cond(jacobian);
        
        % return the calibration data
        calibData = [];
        calibData.dhp = dhp;
        calibData.flange_tf = flange_tf;
        calibData.base_pos = basepos(:)';
        calibData.baseBall = ArmAccuracyData.baseBall;
        calibData.rms_err_fitData = rms_err_fitData;
        calibData.rms_err_testData = rms_err_testData;
        calibData.condNumJ = condNumJ;
        calibData.residual_err_fitData = resid;
        calibData.residual_err_testData = resid_valid;        

end

%-----------------------------------------------------------------------
% Internal function
% pack various parameters into a two vectors, one with vectors to
% be identified and the other with fixed parameters
% also see sister function unpackparams*
% ci* specifies indices of constants for each variable (1=hold constant)
% parameters should come in pairs, first the variable arry, then
% the _ci array that indicates which are to be held constant
%----------------------------------------------------------------------
    function [vars,consts,var_ci,var_desc,var_scaling]=packparams(varargin)
        if  nargin == 0 || mod(nargin,4) ~= 0
            error ('Wrong number of arguments. It must a multiple of four.');
        end;
        vars=[];
        consts=[];
        var_desc=[];
        var_scaling=[];
        var_ci=cell(1,nargin/4);
        for nv=1:4:nargin,
            dat=varargin{nv};
            dat_ci=varargin{nv+1};
            dat_desc=varargin{nv+2};
            dat_scale=varargin{nv+3};
            var_ci{(nv+3)/4}=dat_ci;
            % note: works for column or row vectors, but will
            % output a row vector
            [m n]=size(dat);
            for i=1:m,
                for j=1:n,
                    if dat_ci(i,j)==1.0,
                        consts=[consts dat(i,j)]; %#ok<AGROW>
                    else
                        vars=[vars dat(i,j)*dat_scale(i,j)]; %#ok<AGROW>
                        var_scaling=[var_scaling dat_scale(i,j)]; %#ok<AGROW>
                        var_desc=[var_desc dat_desc(i,j)]; %#ok<AGROW>
                    end
                end
            end
        end
    end

%-------------------------------------------------------------------
% pack various parameters into a two vectors, one with vectors to
% be identified and the other with fixed parameters
% also see sister function unpackparams*
% var_ci specifies indices of constants for each variable, and
% should have been a return value of packparams.m
%------------------------------------------------------------------
    function [varargout]=unpackparams(vars,consts,var_ci,var_scaling)
        nvars = length(var_ci);
        
        vi=1;
        ci=1;
        vars=vars./var_scaling;
        for nv=1:nvars,
            dat_ci=var_ci{nv};
            dat=zeros(size(dat_ci));
            [m n]=size(dat);
            for i=1:m,
                for j=1:n,
                    if dat_ci(i,j)==1.0,
                        dat(i,j)=consts(ci);
                        ci=ci+1;
                    else
                        dat(i,j)=vars(vi);
                        vi=vi+1;
                    end
                end
            end
            varargout{nv} = dat;
        end
        
    end

%--------------------------------------------------------------------------
% Internal function that converts given Transformation matrix to a set of
% yaw, pitch ,and roll angles (in radians)
%--------------------------------------------------------------------------
    function angles = Tx_2_YPR( Tx )
        if (Tx(2,1) == 0) && (Tx(1,1) == 0)
            theta = pi/2; % or -pi/2
            %infinte solutions possible one of them would be:
            phi = 0;
            psi = atan2( Tx(1,2), Tx(2,2) );
        else
            theta = atan2( -Tx(3,1), sqrt(1-Tx(3,1)^2) );
            if (cos(theta) > 0)
                psi = atan2(Tx(3,2), Tx(3,3));
                phi = atan2(Tx(2,1), Tx(1,1));
            else
                psi = atan2(-Tx(3,2), -Tx(3,3));
                phi = atan2(-Tx(2,1), -Tx(1,1));
            end
        end
        
        angles = [ psi,  theta, phi ]';
        
        
    end

%------------------------------------------------------------------------------
% Internal function that calculates Transformation matrix give a set of
% yaw, pitch ,and roll angles (in radians)
%------------------------------------------------------------------------------
    function Tx = YPR_2_Tx ( angles )
        c_ph = cos(angles(3));
        s_ph = sin(angles(3));
        c_th = cos(angles(2));
        s_th = sin(angles(2));
        c_ps = cos(angles(1));
        s_ps = sin(angles(1));
        
        Tx =[c_ph*c_th, -s_ph*c_ps+c_ph*s_th*s_ps, s_ph*s_ps+c_ph*s_th*c_ps,  0; ...
            s_ph*c_th, c_ph*c_ps+s_ph*s_th*s_ps,  -c_ph*s_ps+s_ph*s_th*c_ps, 0; ...
            -s_th,      c_th*s_ps,                 c_th*c_ps,                 0; ...
            0,           0,                        0,                         1 ];
        
    end

%------------------------------------------------------------------------------
% Internal function to remove outliers in the collected data
%------------------------------------------------------------------------------
    function [allData, allDataEEpos] = removeOutlier(resid, allData, allDataEEpos)
        % remove 2 sigma outlier
        thresh = 3*std(resid);
        indx = find(abs(resid) > thresh);
        %if more that 10% of data is outside the confidence interval the
        %generate warning
        if length(indx) > 0.1*length(allData)
            %             msgbox( ['WARNING: More than 10% outliers have been detected.', ...
            %                 'Removing 10% of outliers'],'warn' );
            [tmp, indx]=sort(abs(resid),'descend');
            lg = round(0.1*length(allData));
            allData(indx(1:lg),:) = [];
            allDataEEpos(indx(1:lg),:) = [];
        else
            allData(indx,:) = [];
            allDataEEpos(indx,:) = [];
        end
    end