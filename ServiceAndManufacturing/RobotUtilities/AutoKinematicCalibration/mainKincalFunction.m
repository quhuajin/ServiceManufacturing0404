function mainKincalFunction(dummy,varargin)
% KIN_CAL Perform kinematic calibration from the previously collected
% ballbar
%
% Syntax:
%   kin_cal(hgs)
%       This will start the user interface for performing the kinematic
%       calibration.  The kinematic calibration is performed on data
%       previously collected using the bbar_collect_data script
%
%   kin_cal
%       Kincal called with no argument will  allow the user to run the
%       kinematic calibration to view the results, the user however will
%       not be able to save the results to the robot.  This is useful for
%       offline data analysis
%
% See also:
%   hgs_robot, bbar_collect_data
%

%
% $Author: dmoses $
% $Revision: 3294 $
% $Date: 2013-10-24 12:27:40 -0400 (Thu, 24 Oct 2013) $
% Copyright: MAKO Surgical corp (2008)
%

guiHandles = varargin{2};

% Generate all the other GUI elements
commonGuiProperties = struct(...
    'Units','Normalized',...
    'FontUnits','Normalized',...
    'HorizontalAlignment','left',...
    'visible', 'off');

commonAxisProperties = struct(...
    'Units','Normalized',...
    'FontUnits','Normalized',...
    'parent', guiHandles.extraPanel,...
    'XGrid','on',...
    'YGrid','on',...
    'box','on');

guiHandles.axis1 = axes(...
    commonAxisProperties,...
    'Position', [0.1 0.58, 0.85, 0.36] );
guiHandles.axis2 = axes(...
    commonAxisProperties,...
    'Position', [0.1 0.08, 0.85, 0.36] );

uicontrol(guiHandles.uiPanel,...
    commonGuiProperties,...
    'Style','text',...
    'FontWeight','bold',...
    'FontSize',0.3,...
    'Position',[0.05, 0.90, 0.45, 0.1],...
    'String', {'Final DH Parameters',...
    '   a       alpha       d       theta'});

guiHandles.dH_final = uicontrol(guiHandles.uiPanel,...
    commonGuiProperties,...
    'Style','text',...
    'FontSize',0.06,...
    'Position',[0.05 0.5 0.45 0.4],...
    'String', '');

uicontrol(guiHandles.uiPanel,...
    commonGuiProperties,...
    'Style','text',...
    'FontWeight','bold',...
    'FontSize',0.3,...
    'Position',[0.55, 0.90, 0.40 0.1],...
    'String', 'Final Flange Transform');

guiHandles.flange_final = uicontrol(guiHandles.uiPanel,...
    commonGuiProperties,...
    'Style','text',...
    'FontSize',0.06,...
    'Position',[0.55, 0.5, 0.40 0.4],...
    'String', '');

uicontrol(guiHandles.uiPanel,...
    commonGuiProperties,...
    'Style','text',...
    'FontWeight','bold',...
    'FontSize',0.3,...
    'Position',[0.05 0.4, 0.40 0.1],...
    'String', 'Final Base Position');

guiHandles.base_pos_final = uicontrol(guiHandles.uiPanel,...
    commonGuiProperties,...
    'Style','text',...
    'FontSize',.24,...
    'Position',[0.05 0.3, 0.40 0.1],...
    'String', '');
uicontrol(guiHandles.uiPanel,...
    commonGuiProperties,...
    'Style','text',...
    'FontWeight','bold',...
    'FontSize',0.3,...
    'Position',[0.55 0.4, 0.40 0.1],...
    'String', 'Condition Number');

guiHandles.condition_num = uicontrol(guiHandles.uiPanel,...
    commonGuiProperties,...
    'Style','text',...
    'FontSize',0.24,...
    'Position',[0.55 0.3, 0.40 0.1],...
    'String', '');

uicontrol(guiHandles.uiPanel,...
    commonGuiProperties,...
    'Style','text',...
    'FontSize',0.3,...
    'FontWeight','bold',...
    'Position',[0.05 0.15, 0.25 0.1],...
    'String', 'Ball-bar data file:');
guiHandles.file_name = uicontrol(guiHandles.uiPanel,...
    commonGuiProperties,...
    'Style','text',...
    'FontSize',0.3,...
    'Position',[0.3 0.15, 0.7 0.1],...
    'String', '');


updateMainButtonInfo(guiHandles,'text',...
    'Processing...please wait');
guiHandles.calibData = kinCalFcn(guiHandles);
LogResults = guiHandles.calibData.LogResults;
tgs = guiHandles.calibData.tgs;

switch guiHandles.calibData.baseBall
    case 'BASEBALL_LEFT_CALIB'
        robotPose = 'Lefty';
    case 'BASEBALL_RIGHT_CALIB'
        robotPose = 'Righty';
end
log_results(tgs,guiHandles.scriptName,guiHandles.calibData.info,...
    sprintf('Auto  Kinematic Calibration %s on %s Configuration',guiHandles.calibData.info, upper(robotPose)),...
    LogResults);

guiHandles.calibData.resultString{end+1} = ...
    ['Configuration: ' upper(robotPose)];

if ~strcmp(guiHandles.calibData.info,'FAILURE')
    saveToCrisis(guiHandles);
    guiHandles.calibData.resultString{end+1} = ...
        ['Calibration Data Updated on ' tgs.name];
    presentMakoResults(guiHandles, guiHandles.calibData.info,...
        guiHandles.calibData.resultString);
    
    set(guiHandles.mainButtonInfo,'FontSize',0.1);
else
    presentMakoResults(guiHandles, guiHandles.calibData.info,...
         guiHandles.calibData.resultString);
    set(guiHandles.mainButtonInfo,'FontSize',0.1);
end



%------------------------------------------------------------------------------
% Internal function for kin cal
%------------------------------------------------------------------------------
    function calibData = kinCalFcn(guiHandles)
        colorMap = lines(6);
        colorIndx = 1;
        
        fileName = guiHandles.filename;
        if fileName == 0
            warndlg( ['No Ball-bar data Selected. Please open a ball-bar data file ', ...
                'from the menu'],'Warning');
        else
            [tmp1,nam,ext] = fileparts(fileName);
            switch lower(ext)
                case '.bbar' %old 1.x data: parse the file
                    bbarData=read_ballbar_data (fileName);
                case '.mat'
                    load(fileName); %2.0 data is saved as Matlab mat file just
                    %load it.
                otherwise
                    errordlg(['Unknown file extention:',ext],'Error')
                    return;
            end
        end
        
        % choose which params are constant (0=optimize, 1=constant)
        % a, alpha, d, theta_offset
        dhp = bbarData.nominalDH_Matrix;
        dhp_ci= zeros(size(dhp));
        dhp_ci(1,:) = ones(size(dhp_ci(1,:)));
        for i=1:bbarData.dof,
            dhp_desc(i,:) = {['a',num2str(i)],  ...
                ['alpha',num2str(i)],...
                ['d',num2str(i)],...
                ['theta_offset',num2str(i)]}; %#ok<AGROW>
        end
        dhp_scaling = ones(size(dhp));
        
        lbb = bbarData.lbb;
        lbb_scaling = 1;
        lbb_ci = 1;
        lbb_desc = {'lbb'};
        
        basepos = bbarData.basePos(:);
        basepos_ci = [0 0 0]';
        basepos_scaling = [1 1 1]';
        basepos_desc = {'base_x'; 'base_y'; 'base_z'};
        
        flange = [bbarData.nominalFlangeTransform(1:3,4); ...
            Tx_2_YPR(bbarData.nominalFlangeTransform)];
        flange_ci = [0 0 1 0 0 1]';
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
        
        for i=1:size(bbarData.data, 2),
            allData = [allData; bbarData.data(i).je_angles]; %#ok<AGROW>
            allDataEEpos = [allDataEEpos; ...
                ones(size(bbarData.data(i).je_angles,1),1) * ...
                bbarData.data(i).location(:)']; %#ok<AGROW>
        end
        numData = size(allData,1);
        
        % select 25% of Data for verification
        % use a fixed seed, so that we can reproduce the results
        % if needed
        rand('seed',10);
        indx = randperm(numData);
        %indx=1:numData;
        numFitData = round(numData*.75);
        indxFitData = indx(1:numFitData);
        indxTestData = indx(numFitData+1:end);
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
            updateMainButtonInfo(guiHandles,'text',...
                'Second run ... please wait');
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
        str = sprintf([' \n RMS = %6.5f   '...
            '\\mu_{{\\ite}} = %6.5f    '...
            '\\sigma_{{\\ite}}  = %6.5f    '...
            'min_{{\\ite}}  = %6.5f     '...
            'max_{{\\ite}}  = %6.5f'], ...
            rms_err_fitData, ...
            mean_err_fitData, std_err_fitData, ...
            min_err_fitData, max_err_fitData);
        line(1:length(resid), resid,'color', colorMap(colorIndx, :),...
            'parent', guiHandles.axis1);
        
        set(get(guiHandles.axis1,'XLabel'), 'String', 'Measurement index');
        set(get(guiHandles.axis1,'YLabel'), 'String', 'Residual error (mm)');
        str1=sprintf('Ball-bar Calibration Result - %d Parameters', length(pinit));
        set(get(guiHandles.axis1,'title'),'String', [str1, str]);
        
        mean_err_testData = mean(resid_valid);
        std_err_testData = std(resid_valid);
        rms_err_testData = sqrt(sum(resid_valid.^2)/length(resid_valid));
        min_err_testData = min(resid_valid);
        max_err_testData = max(resid_valid);
        str = sprintf([' \n RMS = %6.5f    '...
            '\\mu_{{\\ite}} = %6.5f    '...
            '\\sigma_{{\\ite}}  = %6.5f    '...
            'min_{{\\ite}}  = %6.5f     '...
            'max_{{\\ite}}  = %6.5f'], ...
            rms_err_testData, ...
            mean_err_testData, std_err_testData, ...
            min_err_testData, max_err_testData);
        
        
        
        % hndl(2) = subplot(224);
        line(1:length(resid_valid), resid_valid,'color',colorMap(colorIndx, :),...
            'parent', guiHandles.axis2);
        
        set(get(guiHandles.axis2,'XLabel'), 'String', 'Measurement index');
        set(get(guiHandles.axis2,'YLabel'), 'String', 'Residual error (mm)');
        str1=sprintf('Cross Validation Results');
        set(get(guiHandles.axis2,'title'),'String', [str1, str]);
        %text(ax(1)*1.1, ax(4)*.8, str, 'FontSize',7);
        
        [dhp,flange,lbb,basepos]=unpackparams(pfit,cinit,var_ci,var_scaling);
        
        %make text visible
        hndls = get(guiHandles.uiPanel,'children');
        set(hndls, 'visible', 'on');
        
        str = [];
        for i = 1:size(dhp,1),
            str{i}  = sprintf('% 7.5f  ', dhp(i,:)); %#ok<AGROW>
        end
        set(guiHandles.dH_final,'String', str);
        flange_tf = YPR_2_Tx(flange(4:6));
        
        flange_tf(1:3,4) = flange(1:3);
        str = [];
        for i = 1:size(flange_tf,1),
            str{i}  = sprintf('% 7.5f  ', flange_tf(i,:)); %#ok<AGROW>
        end
        set(guiHandles.flange_final, 'String', str);
        
        str=sprintf('% 7.5f   % 7.5f   %7.5f',...
            basepos(1),basepos(2),basepos(3));
        set(guiHandles.base_pos_final,'String', str);
        condNumJ = cond(jacobian);
        set(guiHandles.condition_num,'String', sprintf('%6.2f', condNumJ));
        
        % return the calibration data
        calibData = [];
        calibData.tgs = guiHandles.tgs;
        calibData.dhp = dhp;
        calibData.flange_tf = flange_tf;
        calibData.base_pos = basepos(:)';
        calibData.baseBall = bbarData.baseBall;
        
        % Acceptance Criteria
        rmsMaxFitData = 0.09;
        rmsMaxTestData = 0.14;
        condNumMax = 600;
        
        warnLevel = 0.75;
        lineNum =1;
        calibData.info = ' ';
        calibData.resultString{1} = ' ';
        calibData.LogResults.RmsErrorFitData = rms_err_fitData;
        calibData.LogResults.RmsMaxFitData = rmsMaxFitData;
        calibData.LogResults.RmsErrorTestData = rms_err_testData;
        calibData.LogResults.RmsMaxTestData = rmsMaxTestData;
        calibData.LogResults.CondNumber = abs(condNumJ);
        calibData.LogResults.CondNumberMax = condNumMax;
        
        %check for acceptance criteria
        if  rms_err_fitData > rmsMaxFitData
            calibData.info = 'FAILURE';
            calibData.resultString{lineNum} = sprintf(['Calib RMS = %4.3fmm ', ...
                '(max acceptable  %4.2fmm)'],  rms_err_fitData, ...
                rmsMaxFitData);
            lineNum = lineNum+1;
        end
        
        if  rms_err_testData > rmsMaxTestData
            calibData.info = 'FAILURE';
            calibData.resultString{lineNum} = sprintf(['Test RMS = %4.3fmm ', ...
                '(max acceptable  %4.2fmm)'],  rms_err_testData, ...
                rmsMaxTestData);
            lineNum = lineNum+1;
        end
        
        if  abs(condNumJ) > condNumMax
            calibData.info = 'FAILURE';
            calibData.resultString{lineNum} = sprintf(['Condition Number = %7.2f ', ...
                '(max acceptable  %4.0f)'],  condNumJ, ...
                condNumMax);
            lineNum = lineNum+1; %#ok<NASGU>
        end
        
        %if any failure occured return immediately
        if strcmp(calibData.info,'FAILURE')
            return;
        end
        
        %if we reach here no Error has occured
        lineNum = 1; %#ok<NASGU>
        
        %check if we need to issue any warning
        if  rms_err_fitData > ( warnLevel*rmsMaxFitData )
            calibData.info = 'WARNING';
            calibData.resultString{lineNum} = sprintf(['Calib RMS = %4.3fmm ', ...
                '(max acceptable  %4.2fmm)'],  rms_err_fitData, ...
                rmsMaxFitData);
            lineNum = lineNum+1;
        end
        
        if  rms_err_testData > ( warnLevel*rmsMaxTestData )
            calibData.info = 'WARNING';
            calibData.resultString{lineNum} = sprintf(['Test RMS = %4.3fmm ', ...
                '(max acceptable  %4.2fmm)'],  rms_err_testData, ...
                rmsMaxTestData);
            lineNum = lineNum+1;
        end
        
        if abs(condNumJ) > ( warnLevel*condNumMax )
            calibData.info = 'WARNING';
            calibData.resultString{lineNum} = sprintf(['Condition Number = %7.2f', ...
                '(max acceptable  %4.0f)'],  condNumJ, ...
                condNumMax);
        end
        if strcmp(calibData.info,'WARNING')
            return;
        end
        
        
        %if we reach here then there was neither warning nor failure
        calibData.info = 'SUCCESS';
        
        
        
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
            msgbox( ['WARNING: More than 10% outliers have been detected.', ...
                'Removing 10% of outliers'],'warn' );
            [tmp, indx]=sort(abs(resid),'descend');
            lg = round(0.1*length(allData));
            allData(indx(1:lg),:) = [];
            allDataEEpos(indx(1:lg),:) = [];
        else
            allData(indx,:) = [];
            allDataEEpos(indx,:) = [];
        end
    end

%--------------------------------------------------------------------------
% Internal function to save the computed parameters to CRISIS
%--------------------------------------------------------------------------
    function saveToCrisis(guiHandles)
        tgs = guiHandles.calibData.tgs;
        %save calibrated flange transform, dh parameter to robot
        %calibration base position to configuration file
        switch guiHandles.calibData.baseBall
            case {'BASEBALL_LEFT_CALIB'}
                tgs.BASEBALL_LEFT_CALIB = guiHandles.calibData.base_pos;
                tgs.CALIBRATED_FLANGE_LEFTY = guiHandles.calibData.flange_tf;
                tgs.CALIBRATED_DH_LEFTY = guiHandles.calibData.dhp;
            case {'BASEBALL_RIGHT_CALIB'}
                tgs.BASEBALL_RIGHT_CALIB = guiHandles.calibData.base_pos;
                tgs.CALIBRATED_FLANGE_RIGHTY = guiHandles.calibData.flange_tf;
                tgs.CALIBRATED_DH_RIGHTY = guiHandles.calibData.dhp;
            otherwise
                errordlg('Invalid Calibration Base Ball')
        end
    end

%--------------------------------------------------------------------------
% Internal function to open a ball bar data collection file
%--------------------------------------------------------------------------
    function successFailure = openFile
        tgs = guiHandles.tgs;
        if (~isa(tgs,'hgs_robot'))
            unitName = tgs;
        else
            unitName = tgs.name;
        end
        if isempty(getenv('ROBOT_BBAR_ORIG'))
            if ispc
                baseDir = fullfile(getenv('USERPROFILE'),'Desktop');
            else
                baseDir = tempdir;
            end
            dirName  = fullfile(baseDir,...
                [unitName,'-bbar-Data']);
        else
            dirName = getenv('ROBOT_BBAR_ORIG');
        end
        
        if (isdir(dirName))
            [filename, pathname] = ...
                uigetfile({'*.mat', '2.0 Data Files';'*.bbar','1.x Data Files'},['Select ' ...
                'Ball-bar Calibration Data'], dirName);
        else
            [filename, pathname] = ...
                uigetfile({'*.mat', '2.0 Data Files';'*.bbar','1.x Data Files'},['Select ' ...
                'Ball-bar Calibration Data']);
        end
        if filename ~= 0
            fullFileName = fullfile(pathname, filename);
            guiHandles.filename = fullFileName;
            successFailure = true;
        else
            successFailure = false;
        end
    end
end

% --------- END OF FILE ----------
