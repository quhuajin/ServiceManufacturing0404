function [hgs] = LoadNGo(hgs,varargin)
% script to update the CRISIS version for RIO 2.2, or 3.0 to be compatible with Svc Mfg

try
    % Checks for arguments if any.  If none connect to the default robot
    defaultRobotConnection = false;
    
    if nargin<1
        hgs = connectRobotGui;
        if isempty(hgs)
            guiHandles='';
            return;
        end
        
        % maintain a flag to establish that this connection was done by this
        % script
        defaultRobotConnection = true;
    end
    
    % Get CRISIS image and default config file based on selected hardware version
    version = double(hgs.ARM_HARDWARE_VERSION);

    % Set default KP, KD, KI
    hgs.KP = [ 6000.0000000000  8000.0000000000  2000.0000000000  1500.0000000000  200.0000000000  100.0000000000 ];
    hgs.KD = [ 10 30 20 5 0.2 0.2 ];
    hgs.KI = [ 0.5 1.5 1.25 0.5 0.3 0.3 ];
            
    %Crisis LoadNGo CRISIS iso need to be updated per requirements 461321
    switch int32(version * 10 + 0.05)
        case 22 % 2.2
            % load Svc-RIO2_2-xxxx.img
            svc_img = 'Svc-RIO2_2.img';       
            
        case 30 % 3.0
            % load Svc-RIO3_0-xxxx.img
            svc_img = 'Svc-RIO3_0.img';     
        case 31 % 3.1
            % load Svc-RIO3_1-xxxx.img
            svc_img = 'Svc-RIO3_1.img';    
        otherwise 
            tex = sprintf(...
                'Invalid hardware version %.1f, cannot load CRISIS',version);
            h = msgbox(tex);  
            close(hgs);
            return
    end
    
    h = msgbox({sprintf('Loading RIO %.1f Service CRISIS Software.',version) ;
        sprintf('Version: %s .',cell2mat(comm(hgs,'version_info')))});
    load_arm_software(hgs,svc_img);   
    
catch
    errordlg(sprintf('CRISIS loadngo FAILED\n%s',lasterr));
    close(hgs);
    return
end
 
try 
    close(hgs)
catch
end

try
    hgs = connectRobotGui;
    if isempty(hgs)
        guiHandles='';
        return;
    end
    tex = sprintf('Success loading: %s',cell2mat(comm(hgs,'version_info')));
catch
    tex = sprintf('ERROR: could not detect CRISIS version');
end
h = msgbox(tex);
pause(2)

try
    close(h);
catch
end

end
