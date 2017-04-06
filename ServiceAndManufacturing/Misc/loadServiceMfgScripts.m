function loadServiceMfgScripts(sourceDir)

% loadServiceMfgScripts Load all binaries from the specified directory
%
% Syntax:
%   loadServiceMfgScripts(sourceDir)
%       This script shows a progressbar with a "splash screen" during the
%       file copy and kick off of the main executable (ServiceAndManufacturingMain) 
%       for the service scripts.  
%
% Notes:
%
% See Also:
%   ServiceAndManufacturingMain
%

%
% $Author: dmoses $
% $Revision: 1706 $
% $Date: 2009-04-24 11:18:21 -0400 (Fri, 24 Apr 2009) $
% Copyright: MAKO Surgical corp (2008)
%
 
%-------------------------------------------------------------------------
% Internal function to update progressbar
%-------------------------------------------------------------------------
    function updateLoadProgressBar(varargin)
        progressValue = progressValue + 1.0/150;
        waitbar(progressValue,progressBar);
    end
%----------------- Internal function end --------------

% Setup a progress bar to show startup update 
progressValue = 0;
progressBar = waitbar(progressValue,...
    {'Loading Service and Manufacturing Scripts',...
    'Please Wait....'});

% Tweak the progressbar to make it look prettier
try
    set(0,'Units','points');
    screenSize = get(0,'MonitorPositions');
    screenSize = screenSize(1,:);
    set(progressBar,...
        'color','white',...
        'Position',[screenSize(3)/2-135 screenSize(4)/2-150 270 250]);
    patchHandle = findobj(progressBar,'FaceColor',[1 0 0]);
    set(patchHandle,...
        'FaceColor',[0.5 0.6 1],...
        'EdgeColor',[0 0 0]);
    axisHandle = axes('parent',progressBar);
    axis(axisHandle,'equal');
    makoLogoData = imread('MakoLogo.jpg');
    image(makoLogoData,'parent',axisHandle);
    axis(axisHandle, 'off')
    axis(axisHandle,'image')
    drawnow;

    loadTimer = timer(...
        'ExecutionMode','fixedRate',...
        'period',1.0,'TimerFcn',@updateLoadProgressBar);
    start(loadTimer)

    % copy using xcopy (shell) to allow progressbar to update
    tic
    system(['xcopy /Y /Q /E /I /C "', fullfile(sourceDir,'WindowsBinaries'), ...
        '" "',fullfile(tempdir,'MakoScripts'),'"']);
    toc
    stop(loadTimer);
    delete(loadTimer);
    % setup is done finish the progressbar and close
    waitbar(1,progressBar);
    pause(0.5);
    close(progressBar);
catch
    % There was some error
    % stop the timers and display message
    try
        stop(loadTimer)
        delete(loadTimer);
        close(progressBar);
    catch
    end
    errMsg = lasterror;
    uiwait(errordlg(errMsg.message));
end

end

% --------- END OF FILE ----------