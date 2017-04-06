function gravity_tuning(hgs)
% GRAVITY_TUNING Gui to help perform the phasing procedure on the Hgs Robot.
%
% Syntax:
%   GRAVITY_TUNING(hgs)
%       Starts the phasing GUI for performing gravity tuning on the hgs robot defined by
%       the argument hgs.
%
% Notes:
%   This script is performed after FindGravityConstants scripts.  If the
%   gravity compensation is not ideal after the data points fitting of the
%   FindGravityConstants script, or if changes in friction due to normal
%   wear of a robot negatively affect the gravity compensation behavior,
%   this script is used to tune one or more joints.  
%
%
% See also:
%   find_gravity_constants
%



try
 
    scriptName = 'Gravity Tuning';
    guiHandles = generateMakoGui(scriptName,[],hgs,0);
    
    %figure/GUI fullscreen figures, use simple java to maximize the window
    set(get(guiHandles.figure,'JavaFrame'),'Maximized',true);
    
    % Setup the main function
    set(guiHandles.mainButtonInfo,'CallBack', ...
        @prepGravity)
    
    gravMin = 0.8;
    gravMax = 1.2;
    
    tmpStr=['Adjust the gravity values for each joint as needed.', ...
        'Values greater than 1 produce stronger gravity forces.',...
        'Values less than 1 produce weaker gravity forces.', ...
        'The allowable range is ' num2str(gravMin) ' to ' num2str(gravMax)];
    
    %define the common properties for all uicontrol
    commonBoxProperties = struct(...
        'Units','Normalized',...
        'FontWeight','bold',...
        'FontUnits','normalized',...
        'SelectionHighlight','off',...
        'Enable','Inactive');
    
    %add the text for Instruction
    tbInstruction = uicontrol(guiHandles.uiPanel,...
        'Style','text',...
        commonBoxProperties,...
        'HorizontalAlignment','left',...
        'FontSize',0.15,...
        'String',tmpStr,...
        'Position',[0.25,0.6,0.5,0.3]);
    
    
    %override the default close callback for clean exit.
    set(guiHandles.figure,'closeRequestFcn',@gravity_hgs_close);
    
    %initialize the gravity error to false
    isGavityCanceled=false;
    
    % Setup boundaries for input boxes
    xMin = 0.1;
    xRange = 0.8;
    yMin = 0.25;
    yRange = 0.15;
    spacing = 0.02;
    
    %define the common properties for all uicontrol
    commonBoxProperties = struct(...
        'Units','Normalized',...
        'FontWeight','bold',...
        'FontUnits','normalized',...
        'SelectionHighlight','off',...
        'Enable','Inactive');
    
    %set degree of freemdom parameters
    meDof = hgs.ME_DOF;
    jeDof = hgs.JE_DOF;
    dof = max([meDof,jeDof]);
    
    % obtain the current gravity comp weights
    GRAV_WEIGHTS_DEFAULT = hgs.GRAV_COMP_WEIGHTS;
    
    %add pushbuttons to show gravity weights
    %disable until the maininfobutton is pressed
    for indx=1:meDof
        boxPosition = [xMin+(xRange+spacing)*(indx-1)/dof,...
            yMin+spacing,...
            xRange/dof-spacing,...
            yRange];
        meBox(indx) = uicontrol(guiHandles.uiPanel,...
            commonBoxProperties,...
            'Style','pushbutton',...
            'Position',boxPosition,...
            'FontSize',0.3,'String',num2str(GRAV_WEIGHTS_DEFAULT(indx)),...
            'Enable','off','BackgroundColor','white',...
            'Callback',@rangeCheckBox); %#ok<AGROW>
    end
    
    %add text to show joint number
    yMin = yMin + .15;
    for indx=1:meDof
        boxPosition = [xMin+(xRange+spacing)*(indx-1)/dof,...
            yMin+spacing,...
            xRange/dof-spacing,...
            yRange];
        meTx1(indx) = uicontrol(guiHandles.uiPanel,...
            commonBoxProperties,...
            'Style','text',...
            'Position',boxPosition,...
            'FontSize',0.3,'String',['J' num2str(indx)]); %#ok<AGROW>
    end
    
catch
    %gravity error handling
    gravity_tune_hgs_error();
end

%--------------------------------------------------------------------------
% internal function: Main function for gravity tuning
%--------------------------------------------------------------------------
    function gravityProcedure(varargin)
        
        try
            
            GRAV_WEIGHTS_TEMP = [];
            
            % obtain all gravity weights from the input boxes
            for i = 1:dof
                GRAV_WEIGHTS_TEMP = [GRAV_WEIGHTS_TEMP str2num(get(meBox(i),'String'))];
            end
            
            % set configuration parameter GRAV_COMP_WEIGHTS
            hgs.GRAV_COMP_WEIGHTS = GRAV_WEIGHTS_TEMP;
            presentMakoResults(guiHandles,'SUCCESS');
            % restart CRISIS to store the weights into the config file
            restartCRISIS(hgs);
        catch
            %gravity error handling
            gravity_tune_hgs_error();
            
            return;
        end
    end
%--------------------------------------------------------------------------
% internal function: close GUI, overide the default cancel button callback
%--------------------------------------------------------------------------
    function gravity_hgs_close(varargin)
        %set gravity cancel flag
        isGavityCanceled=true;
        %close figures
        closereq;
    end
%--------------------------------------------------------------------------
% internal function: handling error
%--------------------------------------------------------------------------
    function gravity_tune_hgs_error()
        %Process error and stop hgs
        gravity_error=lasterror;
        try
            gravityErrorMessage=...
                regexp(gravity_error.message,'\n','split');
            presentMakoResults(guiHandles,'FAILURE',...
                gravityErrorMessage{2});
            stop(hgs);
        catch
            %can not do anything
        end
    end


%--------------------------------------------------------------------------
% internal function: handling error
%--------------------------------------------------------------------------
    function rangeCheckBox(varargin)
        % callback for each input text box
        % check that all input boxes have values within an acceptable range
        % for gravity compensation.  Otherwise turn box red and display
        % error message on maininfo button
        inRange = 1;
        
        for i = 1:dof
            if( str2num(get(meBox(i),'String')) > gravMax || str2num(get(meBox(i),'String')) < gravMin)
                set(meBox(i),'BackgroundColor','red');
                inRange = 0;
            else
                set(meBox(i),'BackgroundColor','white');
            end
            
        end
        if(inRange)
            tmpStr = sprintf('Adjust gravity parameters using input boxes, click to accept changes');
            updateMainButtonInfo(guiHandles,'pushbutton', tmpStr);
            
            % Setup the main function
            set(guiHandles.mainButtonInfo,'CallBack', ...
                @gravityProcedure)
            
        else
            tmpStr = sprintf(['Gravity Weights must be ' num2str(gravMin) ' to ' num2str(gravMax)]);
            updateMainButtonInfo(guiHandles,'text', tmpStr);
            
        end
    end



%--------------------------------------------------------------------------
% internal function: prepare new message
%--------------------------------------------------------------------------
    function prepGravity(varargin)
        
        % after first mainbutton press, enable all input text boxes
        % set callback to gravityProcedure
        
        tmpStr = sprintf('Adjust gravity parameters using input boxes, click to accept changes');
        updateMainButtonInfo(guiHandles,'pushbutton', tmpStr);
        
        %add pushbuttons to show gravity weights
        for indx=1:meDof
            set(meBox(indx),'Enable','on'); %#ok<AGROW>
        end
        
        % Setup the main function
        set(guiHandles.mainButtonInfo,'CallBack', ...
            @gravityProcedure)
    end
end


% --------- END OF FILE ----------
