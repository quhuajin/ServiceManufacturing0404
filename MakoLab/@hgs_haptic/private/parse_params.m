function paramsStruct = parse_params( paramStr,category)
%PARSE_PARAMS parse a parameter field of a Hgs Haptic object
%
% Syntax:
%
%   PARSE_PARAMS( paramStr,category)
%    Parse and assign default values to parameter list specified in 
%    <paramStr>, which is a char array.
%
% Notes:
%
% See also:
%

%
% $Author: dmoses $
% $Revision: 1707 $
% $Date: 2009-04-24 11:35:08 -0400 (Fri, 24 Apr 2009) $
% Copyright: MAKO Surgical corp (2007)
%

%

[myMatch,mySplit]=regexp(cell2mat(paramStr),...
    '{*\[*,*\]*}*','match','split');
if(length(mySplit)>3)
    paramsStruct.name=char(mySplit(1));
    paramsStruct.type=char(mySplit(2));
    paramsStruct.size=str2double(char(mySplit(3)));
    paramsStruct.category=category;
    mySize=paramsStruct.size;
    %Any preregistered variable will assume an initial length of 1
    %but the 'size' field is '0'
    if mySize==0
        mySize=1;
    end

    switch char(paramsStruct.type)
        case 'f'
            paramsStruct.value=zeros(1,mySize);
        case 's'
            for k=1:mySize
                myStrArray=strcat('','');
            end
            paramsStruct.value=myStrArray;
        case 'd'
            paramsStruct.value=zeros(1,mySize,'int32');
        case 'c'
            for k=1:mySize
                myStrArray=strcat('','');
            end
            paramsStruct.value=myStrArray;
        otherwise            
            error('Unsupported %s variable type found.',category);
    end
else    
    error('Missing %s parameter fields.',category);    
end

end



% --------- END OF FILE ----------