% simple script to save STL files in mat format to be used by the
% plot3 and other functions

% List files in High Resolution
file_list = {...
    'robot_base_HR.stl',...
    'J1_Joint_HR.stl',...
    'J2_Joint_HR.stl',...
    'J3_Joint_HR.stl',...
    'J4_Joint_HR.stl',...
    'J5_Joint_HR.stl',...
    'end_effector.stl'};

for i=1:length(file_list)
    disp(file_list{i});
    [m_high_res(i).faces, m_high_res(i).verts,m_high_res(i).color] = read_stl(file_list{i});
   
    % Convert everthing to meters
    m_high_res(i).verts = m_high_res(i).verts.*0.001;
end

% List of low resolution files.  Also can be done using the 
% reducepatch function in matlab
file_list = {...
    'robot_base_LR.stl',...
    'J1_Joint_LR.stl',...
    'J2_Joint_LR.stl',...
    'J3_Joint_LR.stl',...
    'J4_Joint_LR.stl',...
    'J5_Joint_LR.stl',...
    'end_effector.stl'};

for i=1:length(file_list)
    disp(file_list{i});
    [m_low_res(i).faces, m_low_res(i).verts,m_low_res(i).color] = read_stl(file_list{i});
    
    % Convert to meters
    m_low_res(i).verts = m_low_res(i).verts.*0.001;
end

save('robot_models.mat','m_high_res','m_low_res')