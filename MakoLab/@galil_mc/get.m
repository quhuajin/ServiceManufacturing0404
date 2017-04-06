function [response] = get(galilObj, prop)

% GET is used to retrieve a property or value(s) from a GALIL 
% controller from MATLAB The return variable is a string or double depending on property.
% 
% Syntax:
%     get(galil_mc, prop)
%     galil_mc is a GALIL controller object
%     prop is any string corresponding to the GALIL commands
%     Example: 
%       positionA = get(Motor1, 'TPA')
%       Returns the position of axis A
%     

% $Author: dberman $
% $Revision: 2272 $
% $Date: 2014-11-21 12:20:14 -0400 (Wed, 12 Nov 2014) $
% Copyright: Stryker Mako (2014)
%
%%    
GetList1 = {'DONE', 'OFFSET', 'N', 'AGX', ... %GALIL properties called with " = ?"
    'SPEED', 'ALLDONE', 'TRQPOS', 'TRQNEG', 'delpos', 'TLA', 'JG', 'JGA', ...
     'TL', 'KP', 'KD', 'KI', 'SP', 'AC', 'DC', 'ER', ...
     'TLA', 'KPA', 'KDA', 'KIA', 'SPA', 'ACA', 'DCA', 'ERA'};

GetList2 = {'RLA', 'RLB', 'TVA', 'TP', 'TPA', ... %GALIL properties called with just property desired
    'TPB', 'QHA', 'J_pos1', 'J_pos2', 'M_pos1', 'M_pos2', 'MG_BGS', 'MG_BN'}; 

GetList3 = {'LA'}; %GALIL properties to be returned as char array (ie list of arrays)

GetList4 = {'QU HALL[]', 'QU ANGLE[]', 'QU DRAG[]'}; %GALIL properties to be returned as numerical array



% Check if property is 'arrays' to retrieve all arrays
if strcmpi(prop,'arrays')
    %Get the names and sizes of the stored arrays
    % List the arrays into a variable arr1
    arr1 = comm(galilObj,'LA');
    % Clean up arr1 making it easier to parse (arr2)
    arr2=strrep(strrep(strrep(strrep(arr1,'[',' '),']',''),char(10),''),':','');
    % Parse arr2 into a cell array (arr3)
    arr3 = textscan(arr2,'%s %d ');
    % Convert arr3 into structure so it is easier to read (arr4) 
    arr4 = cell2struct(arr3,{'var' 'size'},2);
    % Get the number of Arrays (n) and their size (s) 
    n=length(arr4.var); %s=arr4.size(1);
    % Set up a storage array for the number of Arrays and their size 
    arraydata=cell(n,1);


    % Loop to get all Arrays
    for x=1:n% the number of Arrays 
        arrayname=char(arr4.var(x));
        s=arr4.size(x)-1; % the size of each Array
        data = cell2mat(galilObj.galctrl.arrayUpload(arrayname));

          if ismember(arrayname,{'T', 'TIME'});
              data=data-data(1);
          end

         arraydata{x}=data;
    end
    Arrays.var=arr4.var;
    Arrays.data=arraydata;
    
    response = Arrays;

elseif ismember(prop, GetList1)
     response = comm(galilObj,[prop ' = ?']);
     response = str2double(response);
     
elseif ismember(prop, GetList2)
     response = comm(galilObj,prop);
     response = str2double(response);
     
elseif ismember(prop, GetList3)
    response = comm(galilObj,prop);
    
elseif ismember(prop, GetList4)
    response = comm(galilObj,prop);
    response = textscan(response,'%f');
    response = response{:};
    
    
else
%     disp('Invalid Controller Object Or Property')
    response =0;
end


