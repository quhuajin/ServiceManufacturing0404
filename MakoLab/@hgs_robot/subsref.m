function out = subsref(hgs, field)
%SUBSREF overloading method for accessing hgs_robot elements
%
% Syntax:
%   hgs.variable_name
%       returns the value of the variable from the hgs_robot.  this could
%       be a configuration parameter or a read write variable
%   hgs(:) or hgs()
%       returns a structure with all the read write variables from the
%       hgs_robot
%   hgs{:} or hgs{}
%       returns a structure with all the configuration variables
%   hgs.variable_name(n) or hgs.variable_name{n}
%       returns the nth element in the vector specified by variable name
%   hgs.modeName()
%       returns all the local variables available for a mode.  this will
%       'modeNotInitialized' if the mode is not initialized
%   hgs.modeName.variable_name
%       returns the specific value for the local variable identified by the
%       variable_name.  this will return empty if the mode has not been
%       initialized.
%   hgs.modeName.variable_name(n)
%       This will return the nth element of the local variable of the specified
%       mode.
%   hgs.modeName.inputs
%       This will return a structure with the inputs used to create the mode.
%       If the mode has no inputs this will return an empty struct
%   hgs.modeName.mode_error
%       This will acknowledge and return the error to a mode.  If the mode
%       had an error this will return the error string, else it will return
%       'E_NONE'
%
% Notes:
%   As per crisis convension, variables in all caps
%   (e.g. ARM_SERIAL_NUMBER) are configuration parameters
%
% Examples
%   hgs.joint_angles
%   hgs.ARM_SERIAL_NUMBER
%   hgs.joint_angles(2)
%   hgs{:}
%   hgs(:)
%   hgs.zerogravity()
%   hgs.zerogravity.grav_comp
%   hgs.zerogravity.grav_comp(2)
%   hgs.go_to_position.inputs
%   hgs.go_to_position.inputs.target_position
%   hgs.go_to_position.inputs.target_position(2)
%
% See also:
%    hgs_robot, hgs_robot/get, hgs_robot/set

% $Author: dmoses $
% $Revision: 1707 $
% $Date: 2009-04-24 11:35:08 -0400 (Fri, 24 Apr 2009) $
% Copyright: MAKO Surgical corp (2007)
%

% Check how many sub references are made
switch (length(field))
    case 1
        switch field.type
            case '()'
                % if () is specified return all the rw data accessible to
                % the user
                % update the output
                if (isempty(field.subs) || strcmp(field.subs{1},':'))
                    out = commDataPair(hgs,'get_state');
                else
                    error('Unsupported use of method');
                end
            case '{}'
                % if {} is specified return all the config data accessible to
                % the user
                if (isempty(field.subs) || strcmp(field.subs{1},':'))
                    out = commDataPair(hgs,'get_cfg_params');
                else
                    error('Unsupported use of method');
                end
            case '.'
                % This is an attempt to get specific data
                if (isfield(hgs.data,field.subs))
                    % check if the accessed data is part of the user accessible
                    % data query for the value
                    data = commDataPair(hgs,'get_state');
                    out = data.(field.subs);
                elseif (isfield(hgs.cfg,field.subs))
                    % check if the data is part of the configuration data
                    data = commDataPair(hgs,'get_cfg_params');
                    out = data.(field.subs);
                elseif (isfield(hgs.modes,field(1).subs))
                    % check to make sure this
                    % is not a mode
                    % if this is a mode get the local variables as the
                    % data
                    modName = char(field(1).subs);
                    modId = feval(hgs.ctrlModStatusFcn,modName);
                    if (modId == -1)
                        warning('Mode Not Initialized'); %#ok<WNTAG>
                        data = '';
                    else
                        data = commDataPair(hgs,...
                            'get_local_state',modId);
                    end
                    out = data;
                else
                    % Check if this is an attempt to get to an internal variable
                    % if so provide access to only the allowed variables.
                    switch field.subs
                        case 'sock'
                            out = feval(hgs.sockFcn);
                        case 'host'
                            out = hgs.host;
                        case 'port'
                            [sock,port] = feval(hgs.sockFcn);
                            out = port;
                        case 'name'
                            out = hgs.name;
                        otherwise
                            % if i got here the user has attempted to access
                            % data which is not accessible
                            error(['Field (%s) does not exist or cannot be ',...
                                'accessed by user'],...
                                field.subs);
                    end
                end
            otherwise
                error('Unsupported sub ref type %s',field.type);
        end
    case 2
        if (field(1).type~='.')
            error('Unsupported sub ref');
        else
            switch field(2).type
                case '()'
                    % call subref recursively to get the data first
                    data = subsref(hgs,field(1));
                    if (~isempty(field(2).subs))
                        out = data(field(2).subs{1});
                    else
                        out = data;
                    end
                case '.'
                    % this is a mode handle it like getting full value
                    modName = char(field(1).subs);
                    modId = feval(hgs.ctrlModStatusFcn,modName);
                    if (modId == -1)
                        warning('Mode Not Initialized'); %#ok<WNTAG>
                        out = '';
                    else
                        % check if this is a request for inputs 
                        if (strcmp(field(2).subs,'inputs'))
                            %check if the module has any inputs if it does
                            % query for the input pairs
                            if ~strcmp(comm(hgs,'get_input_state',modId),...
                                    'no_input_parameters')
                                out = commDataPair(hgs,'get_input_state',modId);
                            else
                                warning('No Input paramters for mode %s',...
                                    modName); %#ok<WNTAG>
                                out = '';
                            end
                        elseif (strcmp(field(2).subs,'mode_error'))
                            out = comm(hgs,'ack_module_error',modId);
                        else
                            data = commDataPair(hgs,'get_local_state',modId);
                            data = data.(field(2).subs);
                            out = data;
                        end
                    end
                otherwise
                    error('Unsupported sub ref');
            end
        end
    case 3
        if (field(1).type=='.')...
                && (field(2).type=='.')...
                && (strcmp(field(3).type,'()'))
            % This must be a mode call subs ref to get mode values
            data = subsref(hgs,field(1:2));
            if isempty(data)
                out = data;
            elseif (~isempty(field(3).subs))
                out = data(field(3).subs{1});
            else
                out = data;
            end
        elseif (field(1).type=='.')...
                && (field(2).type=='.')...
                && (field(3).type=='.')...
                && (strcmp(field(2).subs,'inputs'))
            data = subsref(hgs,field(1:2));
            out = data.(field(3).subs);
        else
            error('Unsupported sub ref');
        end
    case 4
        if (field(1).type=='.')...
                && (field(2).type=='.')...
                && (field(3).type=='.')...
                && (strcmp(field(4).type,'()'))...
                && (strcmp(field(2).subs,'inputs'))
            data = subsref(hgs,field(1:3));
            out = data(field(4).subs{1});
        else
            error('Unsupported sub ref');
        end
    otherwise
        error('Too many sub refs attempted');
end
end


% --------- END OF FILE ----------