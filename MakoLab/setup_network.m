function setup_network(staticOrDynamic,staticIpAddress)
%SETUP_NETWORK changes a computers network settings to either DHCP or static
%
% Syntax:
%   setup_network(staticOrDynamic)
%       This function can be used to change the settings of the host
%       computer to static or dynamic.  The argument staticOrDynamic must
%       be either
%           'Static'  => for static IP addresses
%           'Dynamic' or 'DHCP' => for using DHCP
%   setup_network('Static',staticIpAddress)
%       When used with the 'Static' the user can specify an ipAddress to
%       set the host computer to.  if not specified
%
%       By default the 'Static' will set the computer to
%          172.16.16.150
% Notes:
%       This function will work only for the first wired ethernet as
%       described below
%           For windows => "Local Area Connection"
%           For *NIX    => eth0
%
%       For windows this uses the external  utility netsh and for *NIX
%       it uses ifconfig and ifup.  On unix systems please make sure these
%       files are in the path and that the user has permissions to execute
%       these commands
%

%
% $Author: jforsyth $
% $Revision: 3572 $
% $Date: 2014-09-10 15:33:23 -0400 (Wed, 10 Sep 2014) $
% Copyright: MAKO Surgical corp (2008)
%

defaultStaticIP = '172.16.16.150';
defaultVoyagerIP = '10.1.1.150';

% check the arguments
switch upper(staticOrDynamic)
    case 'STATIC'
        if nargin~=2
            staticIpAddress = defaultStaticIP;
        end
    case 'STATIC_VOYAGER'
        if nargin~=2
            staticIpAddress = defaultVoyagerIP;
        end
    case {'DYNAMIC','DHCP'}
        % do nothing
    otherwise
        error('Invalid argument, must be string Static or Dynamic');
end

% now do the setup
if (strcmp(upper(staticOrDynamic),'STATIC'))
    display(sprintf('Now updating IP address to %s...Please wait',...
        staticIpAddress));
    if ispc
        
        for i = 1:9
            if(i==1)
                [result,resultText] = dos(['netsh interface ip set address ',...
                    'name="Local Area Connection" static ',staticIpAddress,...
                    ' 255.255.255.0 ']);
            else
                % try other connection names
                str = ['netsh interface ip set address ',...
                    'name="Local Area Connection ',num2str(i),'" static ',staticIpAddress,...
                    ' 255.255.255.0 '];
                [result,resultText] = dos(str);
            end
            if(result==0)
                display('Network setup successfully');
                return;
            end
        end
        
    else
        [result,resultText] = unix(['/sbin/ifconfig eth0 ',staticIpAddress,...
            ' netmask 255.255.255.0']);
    end
elseif (strcmp(upper(staticOrDynamic),'STATIC_VOYAGER'))
    display(sprintf('Now updating IP address to %s...Please wait',...
        staticIpAddress));
    if ispc
        
        for i = 1:9
            if(i==1)
                [result,resultText] = dos(['netsh interface ip set address ',...
                    'name="Local Area Connection" static ',staticIpAddress,...
                    ' 255.255.255.0 ']);
            else
                % try other connection names
                str = ['netsh interface ip set address ',...
                    'name="Local Area Connection ',num2str(i),'" static ',staticIpAddress,...
                    ' 255.255.255.0 '];
                [result,resultText] = dos(str);
            end
            if(result==0)
                display('Network setup successfully');
                return;
            end
        end
        
    else
        [result,resultText] = unix(['/sbin/ifconfig eth0 ',staticIpAddress,...
            ' netmask 255.255.255.0']);
    end
    
else
    display('Now changing network to DHCP...Please wait');
    if ispc
        [result,resultText] = dos(['netsh interface ip set address ',...
            'name="Local Area Connection" dhcp']);
    else
        % This is not clean.  but this seems to be the way to get the dhcp
        % client to renew after the network setting was changed to static
        [result,resultText] = unix('pkill dhclient'); %#ok<NASGU>
        [result,resultText] = unix('/sbin/dhclient');
    end
end

if (result)
    error('Unable to change network settings (%s)',resultText);
else
    display('Network setup successfully');
end


% --------- END OF FILE ----------