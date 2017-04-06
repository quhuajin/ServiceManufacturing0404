function ballBarData = read_ballbar_data(filename)
%READ_BALLBAR_DATA Read an Mako ballbar data
%
% $Author: dmoses $
% $Revision: 1706 $
% $Date: 2009-04-24 11:18:21 -0400 (Fri, 24 Apr 2009) $
% Copyright: MAKO Surgical corp (2008)
%


ballBarData = [];
if nargin == 0,
    error('ballbar filename missing');
end

% Open the file for read
fid=fopen(filename, 'r','l');
if fid == -1
    error('File could not be opened, check name or path.')
end

while feof(fid) == 0
   curr_line = fgetl(fid);
   if (~isempty(regexp(curr_line,'WAM_DOF','once')))
     ballBarData.dof = sscanf(fgetl(fid), '%f');
   end

   if (~isempty(regexp(curr_line,'NOMINAL_FLANGE_TRANSFORM','once')))
     tempData = sscanf(fgetl(fid), '%f %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f');
     ballBarData.nominalFlangeTransform = reshape( tempData, 4, 4)';
   end

   if (~isempty(regexp(curr_line,'NOMINAL_DH_MATRIX','once')))
      if (ballBarData.dof == 5 )
         tempData = sscanf(fgetl(fid), '%f %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f');
         ballBarData.nominalDH_Matrix = reshape( tempData, 4, 5)';
      end
      if (ballBarData.dof == 6 )
          tempData = sscanf(fgetl(fid), '%f %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f %f');
          ballBarData.nominalDH_Matrix = reshape( tempData, 4, 6)';
      end
   end
   if (~isempty(regexp(curr_line,'lbb','once')))
     ballBarData.lbb = sscanf(fgetl(fid), '%f');
   end
   if (~isempty(regexp(curr_line,'baseball','once')))
     ballBarData.baseBall = sscanf(fgetl(fid), '%s');
   end
   if (~isempty(regexp(curr_line,'basepos','once')))
     ballBarData.basePos = sscanf(fgetl(fid), '%f %f %f')';
   end
   if (~isempty(regexp(curr_line,'\.\.\.','once')))
     break;
   end
end


i  = 1;
%we are no at the start of data
while feof(fid) == 0
  curr_line = fgetl(fid);
   if (~isempty(regexp(curr_line,'[A-D]','once')))
     %this is newData;
       numData = sscanf(curr_line, '%d');
       ballBarData.data(i).location = sscanf(curr_line, '%*s %*s %f %f %f')';
       ballBarData.data(i).je_angles = zeros(numData,  ballBarData.dof);
   end
   for (j=1:numData)
     curr_line = fgetl(fid);
     if curr_line ~= -1,
         ballBarData.data(i).je_angles(j,:) = sscanf(curr_line, ...
                                            '%f %f %f %f %f %f', ...
                                            [1, ballBarData.dof]);
     else
         continue;
     end
     
   end
   i = i+1;
end
fclose(fid);
end

% --------- END OF FILE ----------