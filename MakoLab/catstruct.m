function A = catstruct(varargin)
% CATSTRUCT - concatenate structures
%
%   X = CATSTRUCT(S1,S2,S3,...) concates the structures S1, S2, ... into one
%   structure X.
%
%   A.name = 'Me' ; 
%   B.income = 99999 ; 
%   X = CATSTRUCT(A,B) ->
%     X.name = 'Me' ;
%     X.income = 99999 ;
%
%   CATSTRUCT(S1,S2,'sorted') will sort the fieldnames alphabetically.
%
%   If a fieldname occurs more than once in the argument list, only the last
%   occurence is used, and the fields are alphabetically sorted.
%
%   To sort the fieldnames of a structure A use:
%   A = CATSTRUCT(A,'sorted') ;
%
%   See also CAT, STRUCT, FIELDNAMES, STRUCT2CELL

% 
% $Author: dmoses $
% $Revision: 1707 $
% $Date: 2009-04-24 11:35:08 -0400 (Fri, 24 Apr 2009) $ 
% Copyright: 2005 Jos van der Geest
% 

N = nargin ;

error(nargchk(1,Inf,N)) ;

if ~isstruct(varargin{end}),
    if isequal(varargin{end},'sorted'),
        sorted = 1 ;
        N = N-1 ;
        if N < 1,
            A = [] ;
            return
        end
    else
        error('Last argument should be a structure, or the string "sorted".') ;
    end
else
    sorted = 0 ;
end

for ii=1:N,
    X = varargin{ii} ;
    if ~isstruct(X),
        error(['Argument #' num2str(ii) ' is not a structure.']) ;
    end
    FN{ii} = fieldnames(X) ;
    VAL{ii} = struct2cell(X) ;
end

FN = cat(1,FN{:}) ;
VAL = cat(1,VAL{:}) ;
[UFN,ind] = unique(FN) ;

if length(UFN) ~= length(FN),
    warning('Duplicate fieldnames found. Last value is used.') ;
    sorted = 1 ;
end

if sorted,
    VAL = VAL(ind) ;
    FN = FN(ind) ;
end

VF = reshape([FN VAL].',1,[]) ;
A = struct(VF{:}) ;


% --------- END OF FILE ----------
