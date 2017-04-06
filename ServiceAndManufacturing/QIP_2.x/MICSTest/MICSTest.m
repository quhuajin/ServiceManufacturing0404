function MICSTest(testType,varargin)

% MICSTest Gui to test out the MICS
% Syntax:
%   MICSTest(testType)
%       This function test the MICS subsystem level and system level test
%
% Notes:
%   The test type is one of the following:
%   'Trigger Board'
%   'Motor Seal'
%   'Hand Piece'
%   'Commutation Board'
%   'MICS'
%   'Config MICS'
%
%
% See also:
%   jSocket class
%

%
% $Author: dmoses $
% $Revision: 4149 $
% $Date: 2015-09-28 14:30:33 -0400 (Mon, 28 Sep 2015) $
% Copyright: MAKO Surgical corp (2012)
%


%first check the input test type
if ~ischar(testType)
    error('Argument must contain a string- ''Trigger Board'',''Hand Piece'', ''Config MICS'', ''Commutation Board'', or ''MICS''');
end

%test data initilizations
testData = [];
testData.results = [];
testData.limits = [];

%now check the test type
switch testType
    case 'Trigger Board'
        if nargin ~= 2
            error('Argument must contain a com port number, i.e. MICSTest(''Trigger Board'',''COM6'')');
        end
        fcnHandle = {@testTriggerBoard,varargin{1}};
        %call init function
        initTriggerBoardData;
    case 'Hand Piece'
        fcnHandle = {@testHandpiece, varargin{:}}; %#ok<CCAT>
        %call init function
        initHandPieceData();
    case 'Motor Seal'
        fcnHandle = {@testHandpiece, varargin{:}}; %#ok<CCAT>
        %call init function
        initHandPieceData();        
        initMotorSealData();
    case 'Commutation Board'
        fcnHandle = @testCommutationBoard;
    case 'MICS'
        fcnHandle = @testMICS;
    case 'Config MICS'
        fcnHandle = {@configMICS,varargin{:}}; %#ok<CCAT>
        %call the init function
    otherwise
        error('Unsupported test type ''%s''',testType);
end
%define a global variable to let user to stop testing
userStopTest = 0;
sensorGui = [];

%some globle handle variables, so we can exit cleanly
sHdl = []; %serial handle
tcpHdl = [];
axPlot = []; %global handle for plot axis

% Query the user for the serial number/workid
jobId = getMakoJobId;

% handle the cancel button
if isempty(jobId)
    return;
end

% Generate the gui
guiHandles = generateMakoGui(sprintf('%s Test',testType),[],jobId);

% Now setup the callback to allow user to press and start the test
updateMainButtonInfo(guiHandles,fcnHandle);

%override the default close callback for clean exit.
set(guiHandles.figure,'closeRequestFcn',@MICSTestClose);

% create a pushbutton for user to stop test
pbUserStop = uicontrol('parent',guiHandles.uiPanel,...
    'unit','normalized',...
    'style','pushbutton',...
    'position',[0.85,0.05,0.1,0.1],...
    'string','stop/complete',...
    'fontunit','normalized',...
    'fontsize',0.3,...,
    'visible','off',...
    'callback',@stopTest);

%--------------------------------------------------------------------------
% Internal function for trigger board test
% This test is done sequentially per predefined steps,
% in every step,
%--------------------------------------------------------------------------
    function testTriggerBoard(varargin)
        
        %set the main button to text
        set(guiHandles.mainButtonInfo,'Style','Text',...
            'string',sprintf('%s Test',testType));
        pName = varargin{3};
        
        %create a command list fields, command, mode, expected reply, and callback
        cmdListFields = {'testDescription','command','mode','expectedReply','replySize','callBack'};
        
        %define test protocol
        cmdList ={...
            'Reset',uint8(hex2dec({'ff','05','80','00','a7'})'),1,[],[], [];...
            
            'Write Serial Number',...
            uint8(hex2dec({'ff','0a','83','00','aa','55','aa','55','b1','5d'})'),...
            1,'Success',17,[];...
            
            'Read Serial Number',uint8(hex2dec({'ff','05','81','00','b2'})'),2, ...
            uint8(hex2dec({'FE' '43' '6F' '6D' '6D' '52' '70' '6C' '0F'...
            'AA' '55' 'AA' '55' 'B1' '14' })'),15,[];...
            
            'Clear Serial Number',...
            uint8(hex2dec({'ff','0a','83','00','00','00','00','00','00','5d'})'),...
            1,'Success',17,[];...
            
            'Read Serial Number',uint8(hex2dec({'ff','05','81','00','b2'})'),2, ...
            uint8(hex2dec({'FE' '43' '6F' '6D' '6D' '52' '70' '6C' '0F' ...
            '00','00' '00' '00' '00' '14' })'),15,[];...
            
            'Write EE Origin',...
            uint8(hex2dec({'ff','12','83','01',...
            '55','aa','55','aa','55','aa','55','aa','55','aa','55','aa','bb', ...
            'f9'})'),1,'Success',17,[];...
            
            'Read EE Origin',uint8(hex2dec({'ff','05','81','01','b5'})'),2, ...
            uint8(hex2dec({'FE' '43' '6F' '6D' '6D' '52' '70' '6C' ...
            '17' '55' 'AA' '55' 'AA' '55' 'AA' '55' 'AA' '55' 'AA' ...
            '55' 'AA' 'BB' '3C'})'),23,[];...
            
            'Clear EE Origin',...
            uint8(hex2dec({'ff','12','83','01',...
            '00','00','00','00','00','00','00','00','00','00','00','00','00', ...
            'f9'})'),1,'Success',17,[];...
            
            'Read EE Origin',uint8(hex2dec({'ff','05','81','01','b5'})'),2, ...
            uint8(hex2dec({'FE' '43' '6F' '6D' '6D' '52' '70' '6C' ...
            '17' '00' '00' '00' '00' '00' '00' '00' '00' '00' '00' ...
            '00' '00' '00' '3C' })'),23,[];...
            
            'Write EE Axis',...
            uint8(hex2dec({'ff','12','83','02',...
            '55','aa','55','aa','55','aa','55','aa','55','aa','55','aa','bb', ...
            'd1'})'),1,'Success',17,[];...
            
            'Read EE Axis',uint8(hex2dec({'ff','05','81','02','bc'})'),2, ...
            uint8(hex2dec({'FE' '43' '6F' '6D' '6D' '52' '70' '6C' ...
            '17' '55' 'AA' '55' 'AA' '55' 'AA' '55' 'AA' '55' 'AA' ...
            '55' 'AA' 'BB' '3C'})'),23,[];...
            
            'Clear EE Axis',...
            uint8(hex2dec({'ff','12','83','02',...
            '00','00','00','00','00','00','00','00','00','00','00','00','00', ...
            'd1'})'),1,'Success',17,[];...
            
            'Read EE Axis',uint8(hex2dec({'ff','05','81','02','bc'})'),2, ...
            uint8(hex2dec({'FE' '43' '6F' '6D' '6D' '52' '70' '6C' ...
            '17' '00' '00' '00' '00' '00' '00' '00' '00' '00' '00' ...
            '00' '00' '00' '3C' })'),23,[];...
            
            'Write EE Normal',...
            uint8(hex2dec({'ff','12','83','15',...
            '55','aa','55','aa','55','aa','55','aa','55','aa','55','aa','bb', ...
            '1e'})'),1,'Success',17,[];...
            
            'Read EE Normal',uint8(hex2dec({'ff','05','81','15','d9'})'),2, ...
            uint8(hex2dec({'FE' '43' '6F' '6D' '6D' '52' '70' '6C' ...
            '17' '55' 'AA' '55' 'AA' '55' 'AA' '55' 'AA' '55' 'AA' ...
            '55' 'AA' 'BB' '3C'})'),23,[];...
            
            'Clear EE Normal',...
            uint8(hex2dec({'ff','12','83','15',...
            '00','00','00','00','00','00','00','00','00','00','00','00','00', ...
            '1e'})'),1,'Success',17,[];...
            
            'Read EE Normal',uint8(hex2dec({'ff','05','81','15','d9'})'),2, ...
            uint8(hex2dec({'FE' '43' '6F' '6D' '6D' '52' '70' '6C' ...
            '17' '00' '00' '00' '00' '00' '00' '00' '00' '00' '00' ...
            '00' '00' '00' '3C'})'),23,[];...
            
            'Write Operation Time',uint8(hex2dec({'ff','0a','83','03',...
            'b3','3b','b3','3b','7e','26'})'),1,'Success',17,[];...
            
            'Read Operation Time',uint8(hex2dec({'ff','05','81','03','bb'})'),2, ...
            uint8(hex2dec({'FE' '43' '6F' '6D' '6D' '52' '70' '6C' ...
            '0F' 'B3' '3B' 'B3' '3B' '7E' '14'})'),15,[];...
            
            'Clear Operation Time',uint8(hex2dec({'ff','0a','83','03',...
            '00','00','00','00','00','26'})'),1,'Success',17,[];...
            
            'Write Error Code',uint8(hex2dec({'ff','0a','83','04','96',...
            '69','96','69','5a','f9'})'),1,'Success',17,[];...
            
            'Read Error Code',uint8(hex2dec({'ff','05','81','04','ae'})'),2, ...
            uint8(hex2dec({'FE' '43' '6F' '6D' '6D' '52' '70' '6C' ...
            '0F' '96' '69' '96' '69' '5A' '14'})'),15,[];...
            
            'Clear Error Code',uint8(hex2dec({'ff','0a','83','04','00',...
            '00','00','00','00','f9'})'),1,'Success',17,[];...
            
            'Clear Log',...
            uint8(hex2dec({'ff','06','83','05','01' 'bd'})'),...
            1,'Success',17,[];...
            
            'Write Log',...
            uint8(hex2dec({'ff','0b','83','06','05' '55' 'aa' '55' 'aa' '82' '21'})'), ....
            1,'Success',17,[];...
            
            'Read Log',uint8(hex2dec({'ff','05','81','06','a0'})'),3, ...
            uint8(hex2dec({'FE' '43' '6F' '6D' '6D' '52' '70' '6C' '2A' '05'...
            '55' 'AA' '55' 'AA' '82'})'),42,[];...
            
            'Write Log Position',...
            uint8(hex2dec({'ff','06','83','05','02' 'b4'})'),...
            1,'Success',17,[];...
            
            'Read Log Position',uint8(hex2dec({'ff','05','81','05','a9'})'),2, ...
            uint8(hex2dec({'FE' '43' '6F' '6D' '6D' '52' '70' '6C' '0B' '02' '06'})'),11,[];...
            
            'Clear Log',...
            uint8(hex2dec({'ff','06','83','05','01' 'bd'})'),...
            1,'Success',17,[];...
            
            'Read Log Position',uint8(hex2dec({'ff','05','81','05','a9'})'),2, ...
            uint8(hex2dec({'FE' '43' '6F' '6D' '6D' '52' '70' '6C' '0B' '01' '0F'})'),11,[];...
            
            'Start Streaming',uint8(hex2dec({'ff','05','00','00','11'})'),1,'Success',18, @checkA2D;...
            };
        
        testCmdStruct = cell2struct(cmdList,cmdListFields,2);
        
        %get number of commands
        numOfCommands = length(testCmdStruct);
        testData.results.commandPass = zeros(1,numOfCommands);
        
        %create an invisible axes to hold gui
        axTB = axes('Parent', guiHandles.uiPanel,...
            'Position',[0.01,0.02,0.5,0.96],...
            'XLim', [0 1], ...
            'YLim', [0 1], ...
            'Visible','off');
        
        %pre allocate for gui items
        txTB =zeros(1,length(testCmdStruct));
        ptTB =zeros(1,length(testCmdStruct));
        %create gui to displace test item and patch for results
        for i= 1: numOfCommands
            x = 0.1;
            y = 0.94 - 0.03 * i;
            h = 0.02;
            w = 0.04;
            txTB(i) = text('Parent',axTB,...
                'String',testCmdStruct(i).testDescription,...
                'Units','Normalized',...
                'position',[x, y],...
                'FontUnits','Normalized',...
                'VerticalAlignment','bottom',...
                'FontSize', h...
                );
            x = 0.05;
            ptTB(i) = patch( 'Parent',axTB,...
                'XData', [x    x+w  x+w  x ],...
                'YData', [y    y    y+h  y+h],...
                'FaceColor',[0.5,0.5,0.5]);
        end
        
        %setup additonal uicontrol
        nA2D = length(testData.limits.names);
        
        %get the number of return has to compared
        nRplChecks =0;
        for i=1:length(testCmdStruct)
            if testCmdStruct(i).mode < 1
                nRplChecks = nRplChecks + 1;
            end
        end
        
        % create a figure to hold some gui in uipanel
        w = 0.1;
        h = 0.05;
        for i = 1 : nA2D
            switch( i )
                case 1
                    x = 0.7;
                    y = 0.7;
                case { 2 ,3, 4, 5 }
                    x = 0.55 + 0.11 *( i - 2 );
                    y = 0.5;
                case { 6, 7 }
                    x = 0.65 + 0.11 *(i - 6);
                    y = 0.3;
            end
            % Create axes, patch, and text
            sensorGui.axes(i) = axes('parent', guiHandles.uiPanel,...
                'Position', [ x, y, w, h ], ...
                'XLim', [0 1], ...
                'YLim', [0 1], ...
                'ytick', [], ...
                'xtick', []); %#ok<LAXES>
            
            sensorGui.patch(i) = patch( 'parent',sensorGui.axes(i),...
                'XData', [0  0 1 1 ], ...
                'YData', [0  1 1 0 ] );
            
            sensorGui.text(i) = text( 'parent',sensorGui.axes(i),...
                'VerticalAlignment','middle',...
                'HorizontalAlignment','center',...
                'String','***',...
                'Units','Normalized',...
                'Position',[0.5,0.5],...
                'FontSize',0.2,...
                'FontUnits','normalized');
            
            sensorGui.label(i) = uicontrol('parent', guiHandles.uiPanel,...
                'style','text',...
                'Units','normalized',...
                'position',[x, y-0.07, 0.09 ,0.05],...
                'string',testData.limits.names(i),...
                'HorizontalAlignment', 'Center', ...
                'FontUnits', 'Normalized', ...
                'ForegroundColor', 'black',...
                'FontSize', 0.5 );
            % The start clolor is grey
            set(sensorGui.patch(i), 'FaceColor',[1,1,1]);
        end
        
        %make user cancel button visible
        set(pbUserStop,'visible','on');
        
        %force a redraw
        drawnow;
        
        %%%%%communication protocol%%%%
        %%% usb-RS422 converter
        %The communication is through a usb RS422 serial converter to
        %connect trigger board, the serial port setup is 115K baud,
        %8 bits, 1 stop bit, and no hardware control.
        
        %%%command example
        %ex1. read parameter
        %ff 05 81 00 b2
        %ff -- start byte
        %05 -- number of bytes
        %81 -- command
        %00 -- parameter id
        %b2 -- crc8 of command
        
        %ex2. write parameter
        %ff 0a 83 00 aa 55 aa 55 b1 5d
        %ff -- start byte
        %0a -- number if bytes
        %83 -- command
        %00 -- parameter id
        %aa 55 aa 55 -- data
        %b1 -- crc8 of data
        %5d -- crc8 of command
        
        %update display
        set(guiHandles.mainButtonInfo,...
            'String',{sprintf('%s Test',testType),'Open serial port, may take up to 15 seconds'});
        drawnow;
        
        %open serial port
        try
            sHdl = serial(pName,'BaudRate',115200,'InputBufferSize',240);
            fopen(sHdl);
        catch ME
            testData.results.testSummary = ME.message;
            presentMakoResults(guiHandles, 'FAILURE', ...
                testData.results.testSummary);
            return;
        end
        
        %add firmware version
        fwVersion = getTriggerBoardFirmwareVersion('TRIGGERBOARD',sHdl);
        if isempty(fwVersion)
            testData.results.testSummary = 'Trigger board firmware version is empty';
            presentMakoResults(guiHandles, 'FAILURE', ...
                testData.results.testSummary);
            return;
        end
        %save firmware version to results
        testData.results.fwTriggerBoard = fwVersion;
        
        % also display firmware version
        text('Parent',axTB,...
            'String',sprintf('Trigger Board Firmware Rev: %s',fwVersion),...
            'Units','Normalized',...
            'position',[0.2, 0.95],...
            'FontUnits','Normalized',...
            'VerticalAlignment','bottom',...
            'FontSize', 0.03,...
            'interpreter','none'...
            );
        % send and check command
        for i=1:length(testCmdStruct)
            try
                %update main button
                set(guiHandles.mainButtonInfo,...
                    'String',{sprintf('%s Test',testType),testCmdStruct(i).testDescription});
                drawnow;
                
                %write serial number command
                fwrite(sHdl,testCmdStruct(i).command);
                
                %read serial number
                if(strcmp('Reset', testCmdStruct(i).testDescription))
                    %clear buffer, this will cause a timeout warning,
                    %so supress it
                    warning off all;
                    rpl = fread(sHdl);
                    warning on all;
                    if(~isempty(rpl))
                        set(ptTB(i),'FaceColor',[0,1,0]);
                        testData.results.commandPass(i) = 1;
                    else
                        set(ptTB(i),'FaceColor',[1,0,0]);
                        testData.results.commandPass(i) = 0;
                    end
                else
                    while(sHdl.BytesAvailable < testCmdStruct(i).replySize)
                        pause(0.01);
                    end
                    rpl = fread(sHdl,testCmdStruct(i).replySize)';
                end
                %based on command mode, check reply accordingly
                if ~isempty(testCmdStruct(i).expectedReply)
                    switch (testCmdStruct(i).mode)
                        case 1
                            if(strfind(char(rpl),testCmdStruct(i).expectedReply))
                                set(ptTB(i),'FaceColor',[0,1,0]);
                                testData.results.commandPass(i) = 1;
                            else
                                set(ptTB(i),'FaceColor',[1,0,0]);
                                testData.results.commandPass(i) = 0;
                            end
                        case 2
                            if (rpl == testCmdStruct(i).expectedReply)
                                set(ptTB(i),'FaceColor',[0,1,0]);
                                testData.results.commandPass(i) = 1;
                            else
                                set(ptTB(i),'FaceColor',[1,0,0]);
                                testData.results.commandPass(i) = 0;
                            end
                        case 3
                            ll= length(testCmdStruct(i).expectedReply);
                            if (rpl(1:ll) == testCmdStruct(i).expectedReply)
                                set(ptTB(i),'FaceColor',[0,1,0]);
                                testData.results.commandPass(i) = 1;
                            else
                                set(ptTB(i),'FaceColor',[1,0,0]);
                                testData.results.commandPass(i) = 0;
                            end
                        otherwise
                            MICSTestClose();
                            error('Unsupported command type');
                    end
                end
                
                %if there is a call back for the test, call it
                if ~isempty(testCmdStruct(i).callBack)
                    feval(testCmdStruct(i).callBack);
                end
                %refresh
                drawnow;
            catch
                return;
            end
        end
        
        fclose(sHdl);
    end

%--------------------------------------------------------------------------
% Internal function for handpiece test
%--------------------------------------------------------------------------
    function testHandpiece(varargin)
        %set the main button to text
        set(guiHandles.mainButtonInfo,'Style','Text',...
            'string',sprintf('%s Test',testType));
        
        %create an invisible axes to hold gui
        axTB = axes('Parent', guiHandles.uiPanel,...
            'Position',[0.01,0.02,0.2,0.96],...
            'XLim', [0 1], ...
            'YLim', [0 1], ...
            'Visible','off');
        axPlot = axes('Parent', guiHandles.uiPanel,...
            'Position',[0.52,0.2,0.46,0.78],...
            'Visible','off');
        
        %create a command list fields, command, mode, expected reply, and callback
        cmdListFields = {'testDescription','command','mode','expectedReply','replySize','callBack'};
        
        %%%%%MICS tcpip socket communication protocol%%%%
        %%% tcpip socket, port 23, ip 10.1.1.177
        %%% The send/receive string is a binary stream of unsigned 8 bit integers,
        %%% which is in the following general format:
        %%% header(1 byte) + number of bytes(1 byte) + command id(1 byte) +
        %%% parameter id (1 byte) + data and data CRC-8(user defined,
        %%% optional)+ modulo 256 checksum (1 byte),
        %%% modulo 256 checksum is a unsigned 8 bit integer,
        %%% which is the sum of every byte in the stream.
        %%% you may also calculate the check sum using this formula:
        %%% 256 - mod(sum(all bytes in the message), 256)
        
        %%%example
        %%ex1. read parameter id 0x50
        %FF 05 12 50 9a
        %FF -- start byte
        %05 -- number of bytes
        %12 -- command
        %50 -- parameter id
        %9a -- modulo 256 check sum,
        
        %reply
        %FE 11 12 AA 55 AA 55 AA 55 AA 55 AA 55 AA 55 CA 1B
        %FE - header byte
        %11 - reply length
        %12 - command id (read parameter)
        %AA 55 AA 55 AA 55 AA 55 AA 55 AA 55 - parameter data
        %CA - CRC-8 of parameter data
        %1B - modulo 256 check sum
        
        
        %%ex2. write parameter id 0x50
        %command
        %FF 12 13 50 AA 55 AA 55 AA 55 AA 55 AA 55 AA 55 CA C8
        %FF - start byte
        %12 - number of bytes
        %13 - command id
        %50 - parameter id
        %AA 55 AA 55 AA 55 AA 55 AA 55 AA 55 -- data
        %b1 - crc8 of data
        %5d - modulo 256 checksum
        
        %reply
        %FE - header
        %04 - length
        %13 - command id
        %EB - modulo 256 checksum
        
        
        %define test protocol
        cmdList ={...
            'Reset',uint8(hex2dec({'ff','04','24','d9'})'),1, [], 4, [];...            
            'Add motor current',uint8(hex2dec({'ff','05','21','03','d8'})'),...
            2,uint8(hex2dec({'fe','04','21','dd'})'),4, [];...
            'Add bus voltage',uint8(hex2dec({'ff','05','21','04','d7'})'),2,...
            uint8(hex2dec({'fe','04','21','dd'})'),4, [];...
            'Add motor speed',uint8(hex2dec({'ff','05','21','07','d4'})'),2,...
            uint8(hex2dec({'fe','04','21','dd'})'),4, [];...
            'Add fault',uint8(hex2dec({'ff','05','21','0b','d0'})'),2,...
            uint8(hex2dec({'fe','04','21','dd'})'),4, [];...
            'Add temperature',uint8(hex2dec({'ff','05','21','0c','cf'})'),2,...
            uint8(hex2dec({'fe','04','21','dd'})'),4, [];...
            'Add irrigation voltage',uint8(hex2dec({'ff','05','21','0d','ce'})'),...
            2,uint8(hex2dec({'fe','04','21','dd'})'),4, [];...
            'Add trigger info',uint8(hex2dec({'ff','05','21','10','cb'})'),...
            2,uint8(hex2dec({'fe','04','21','dd'})'),4, [];...
            'Add direction hall',uint8(hex2dec({'ff','05','21','11','ca'})'),...
            2,uint8(hex2dec({'fe','04','21','dd'})'),4, [];...
            'Add speed command',uint8(hex2dec({'ff','05','21','12','c9'})'),...
            2,uint8(hex2dec({'fe','04','21','dd'})'),4, [];...
            'Start Streaming',uint8(hex2dec({'ff','04','23','da'})'),1,...
            uint8(hex2dec({'fe','04','23','db'})'),4, @getHandPieceData;...
            };
        
        testCmdStruct = cell2struct(cmdList,cmdListFields,2);
        
        numOfCommands = length(testCmdStruct);
        
        %pre allocate for gui items
        txTB =zeros(1,length(testCmdStruct));
        ptTB =zeros(1,length(testCmdStruct));
        %create gui to displace test item and patch for results
        for i= 1: numOfCommands
            x = 0.1;
            y = 0.9 - 0.03 * i;
            h = 0.02;
            w = 0.04;
            txTB(i) = text('Parent',axTB,...
                'String',testCmdStruct(i).testDescription,...
                'Units','Normalized',...
                'position',[x, y],...
                'FontUnits','Normalized',...
                'VerticalAlignment','bottom',...
                'FontSize', h...
                );
            x = 0.05;
            ptTB(i) = patch( 'Parent',axTB,...
                'XData', [x    x+w  x+w  x ],...
                'YData', [y    y    y+h  y+h],...
                'FaceColor',[0.5,0.5,0.5]);
        end
        
        %setup additonal uicontrol
        nA2D = length(testData.limits.names);
        
        %get the number of return has to compared
        nRplChecks =0;
        for i=1:length(testCmdStruct)
            if testCmdStruct(i).mode < 1
                nRplChecks = nRplChecks + 1;
            end
        end
        
        % create a figure to hold some gui in uipanel
        w = 0.05;
        h = 0.05;
        for i = 1 : nA2D
            switch( i )
                case 1
                    x = 0.33;
                    y = 0.7;
                case { 2 ,3, 4, 5 }
                    x = 0.25 + 0.055 *( i - 2 );
                    y = 0.5;
                case { 6, 7 }
                    x = 0.30 + 0.06 *(i - 6);
                    y = 0.3;
            end
            % Create axes, patch, and text
            sensorGui.axes(i) = axes('parent', guiHandles.uiPanel,...
                'Position', [ x, y, w, h ], ...
                'XLim', [0 1], ...
                'YLim', [0 1], ...
                'ytick', [], ...
                'xtick', []); %#ok<LAXES>
            
            sensorGui.patch(i) = patch( 'parent',sensorGui.axes(i),...
                'XData', [0  0 1 1 ], ...
                'YData', [0  1 1 0 ] );
            
            sensorGui.text(i) = text( 'parent',sensorGui.axes(i),...
                'VerticalAlignment','middle',...
                'HorizontalAlignment','center',...
                'String','***',...
                'Units','Normalized',...
                'Position',[0.5,0.5],...
                'FontSize',0.2,...
                'FontUnits','normalized');
            
            sensorGui.label(i) = uicontrol('parent', guiHandles.uiPanel,...
                'style','text',...
                'Units','normalized',...
                'position',[x, y-0.07, 0.05 ,0.05],...
                'string',testData.limits.names(i),...
                'HorizontalAlignment', 'Center', ...
                'FontUnits', 'Normalized', ...
                'ForegroundColor', 'black',...
                'FontSize', 0.5 );
            % The start clolor is grey
            set(sensorGui.patch(i), 'FaceColor',[1,1,1]);
        end
        
        %make user cancel button visible
        set(pbUserStop,'visible','on');
        
        %force a redraw
        drawnow;
        
        %setup tcp connection
        tcpHdl = jSocket(varargin{3 : end});
        
        %add firmware version
        fwVersion = getTriggerBoardFirmwareVersion('HANDPIECE',tcpHdl);
        if isempty(fwVersion)
            testData.results.testSummary = 'Trigger board firmware version is empty';
            presentMakoResults(guiHandles, 'FAILURE', ...
                testData.results.testSummary);
            return;
        end
        %save firmware version to results
        testData.results.fwTriggerBoard = fwVersion;
        
        % also display firmware version
        text('Parent',axTB,...
            'String',sprintf('Trigger Board Firmware Rev: %s',fwVersion),...
            'Units','Normalized',...
            'position',[0.1, 0.96],...
            'FontUnits','Normalized',...
            'VerticalAlignment','bottom',...
            'FontSize', 0.03,...
            'Interpreter','none'...
            );
        
        %add firmware version of commutation board as well
        fwVersion = getTriggerBoardFirmwareVersion('COMMUTATIONBOARD',tcpHdl);
        if isempty(fwVersion)
            testData.results.testSummary = 'Commutation board firmware version is empty';
            presentMakoResults(guiHandles, 'FAILURE', ...
                testData.results.testSummary);
            return;
        end
        %save firmware version to results
        testData.results.fwCommutationBoard = fwVersion;
        
        % also display firmware version
        text('Parent',axTB,...
            'String',sprintf('Commutation Board Firmware Rev: %s',fwVersion),...
            'Units','Normalized',...
            'position',[0.1, 0.92],...
            'FontUnits','Normalized',...
            'VerticalAlignment','bottom',...
            'FontSize', 0.03,...
            'Interpreter','none'...
            );
        
        for i=1:length(testCmdStruct)
            % write command
            TCPWrite(tcpHdl, testCmdStruct(i).command);
            pause(0.5);
            %reset
            if(strcmp('Reset', testCmdStruct(i).testDescription))
                %clear buffer, this will cause a timeout warning,
                %so supress it
                warning off all;
                rpl = TCPRead(tcpHdl,testCmdStruct(i).replySize)';
                warning on all;
                if(~isempty(rpl))
                    set(ptTB(i),'FaceColor',[0,1,0]);
                    testData.results.commandPass(i) = 1;
                else
                    set(ptTB(i),'FaceColor',[1,0,0]);
                    testData.results.commandPass(i) = 0;
                end
            else
                %read reply
                tcpReply = TCPRead(tcpHdl,testCmdStruct(i).replySize)';
                rpl = [];
                if( ~isempty(tcpReply))
                    rpl = typecast(tcpReply,'uint8');
                end
                % if reply is empty, then test failed
                if(isempty(rpl))
                    set(ptTB(i),'FaceColor',[1,0,0]);
                    testData.results.commandPass(i) = 0;
                else
                    %based on command mode, check reply accordingly
                    if ~isempty(testCmdStruct(i).expectedReply)
                        switch (testCmdStruct(i).mode)
                            case 1
                                if(strfind(char(rpl),testCmdStruct(i).expectedReply))
                                    set(ptTB(i),'FaceColor',[0,1,0]);
                                    testData.results.commandPass(i) = 1;
                                else
                                    set(ptTB(i),'FaceColor',[1,0,0]);
                                    testData.results.commandPass(i) = 0;
                                end
                            case 2
                                if (rpl == testCmdStruct(i).expectedReply)
                                    set(ptTB(i),'FaceColor',[0,1,0]);
                                    testData.results.commandPass(i) = 1;
                                else
                                    set(ptTB(i),'FaceColor',[1,0,0]);
                                    testData.results.commandPass(i) = 0;
                                end
                            otherwise
                                MICSTestClose();
                                error('Unsupported command type');
                        end
                    end
                end
            end
            %if there is a call back for the test, call it
            if ~isempty(testCmdStruct(i).callBack)
                feval(testCmdStruct(i).callBack);
            end
            %refresh
            drawnow;
        end
    end

%--------------------------------------------------------------------------
% Internal function for commutation board test
%--------------------------------------------------------------------------
    function testCommutationBoard(varargin)
        
    end

%--------------------------------------------------------------------------
% Internal function for MICS test
%--------------------------------------------------------------------------
    function testMICS(varargin)
        
    end

%--------------------------------------------------------------------------
% Internal function for MICS congiuration through serial port
%--------------------------------------------------------------------------
    function configMICS(varargin)
        %change ui main button
        set(guiHandles.mainButtonInfo,'style','text',...
            'String',{sprintf('%s',testType),...
            'Follow instruction to configure handpiece'});
        %set ip to static
        system(['netsh interface ip set address ',...
            'name="Local Area Connection" static ','10.1.1.150',...
            ' 255.255.255.0 ']);
        pause(5.0)
        mics = mako_mics();        
        eeSN = mics.serial_number;
        eeConstDataMICS(1,:) = mics.ee_origin;
        eeConstDataMICS(2,:) = mics.ee_tool_axis;
        eeConstDataMICS(3,:) = mics.ee_normal_axis;
        delete(mics);

        rNames ={'Origin','ToolAxis Point','Normal Axis Point'};
        cNames ={'x(mm)','y(mm)','z(mm)'};
        
        % created a uipanel to hold ee constants
        uiPanelEEConst = uipanel('parent',guiHandles.uiPanel, ...
            'Title','MICS constants',...
            'Units','normalized',...
            'position',[0,0,1,1]);
        % created a uipanel to hold ee constants
        uiPanelEEConstMICS = uipanel('parent',uiPanelEEConst, ...
            'Title',sprintf('From MICS:SN-%0d',eeSN),...
            'Units','normalized',...
            'position',[0.05,0.2,0.9,0.35]);
        %load and fill in the original ee constants
        uiTableMICS = uitable('parent',uiPanelEEConstMICS,...
            'RowName',rNames,...
            'ColumnName',cNames,...
            'Data',eeConstDataMICS,...
            'Units','normalized',...
            'Position',[0,0,1,1], ...
            'ColumnFormat',{'short','short','short'},...
            'ColumnWidth','auto' ...
            );
        uiPanelEEConstFile = uipanel('parent',uiPanelEEConst, ...
            'Title','From File:SN-#######',...
            'Units','normalized',...
            'position',[0.05,0.6,0.9,0.35]);
        %load new constants from file
        guiHandles.uiTableFile = uitable('parent',uiPanelEEConstFile,...
            'RowName',rNames,...
            'ColumnName',cNames,...
            'Units','normalized',...
            'Position',[0,0,1,1], ...
            'ColumnFormat',{'short','short','short'},...
            'ColumnWidth','auto' ...
            );
        guiHandles.uiPbEEConstCancel = uicontrol(uiPanelEEConst,...
            'units','normalized',...
            'position',[0.6,0.1,0.15,0.05],...
            'String','Cancel',...
            'Callback',{@cancelEEConstants,guiHandles.uiTableFile,eeConstDataMICS,eeSN}...
            ); 
        guiHandles.uiPbEEConstLoad = uicontrol(uiPanelEEConst,...
            'units','normalized',...
            'position',[0.1,0.1,0.15,0.05],...
            'String','Load',...
            'Callback',{@loadEEConstantsFromFile,guiHandles.uiTableFile}...
            ); 
        guiHandles.uiPbEEConstSave = uicontrol(uiPanelEEConst,...
            'units','normalized',...
            'position',[0.3,0.1,0.15,0.05],...
            'String','Save',...
            'Callback',{@saveEEConstants,guiHandles.uiTableFile,uiTableMICS,varargin{ 3 : end }}...
            );
    end

%--------------------------------------------------------------------------
% Internal function for checkA2D of the handpiece
%--------------------------------------------------------------------------
    function checkA2D(varargin)
        set(guiHandles.mainButtonInfo,...
            'String',{sprintf('%s Test',testType),...
            'Follow instruction for hall and temperature, if test is done, click stop button'});
        %flag for polarity check
        polarityInitDone =0;
        
        %get limit save typing
        a2dMin = testData.results.min;
        a2dMax = testData.results.max;
        a2dRangeLimit = testData.limits.a2dRangeLimit;
        a2dMaxLimit = testData.limits.a2dMaxLimit;
        a2dMinLimit = testData.limits.a2dMinLimit;
        numberOfSensors = length(a2dRangeLimit);
        a2d = zeros(1,numberOfSensors);
        plrt = testData.results.polarity;
        px = ones(1,numberOfSensors);
        strDataSize = 24;
        try
            while ~userStopTest
                %keep reading data, use the last data set in the stream
                while(sHdl.BytesAvailable < 240)
                    pause(0.01);
                end
                rpl = fread(sHdl)';
                idx = strfind(char(rpl),'StrmRpl');
                
                %find the first complete data set in the read buffer
                %there should be one byte before the 'StrmRpl'
                id = idx(find((idx > 1), 1));
                
                %next byte follows the header is number of bytes, and next is
                %the actual sensor data, every sensor data is a 16 bit integer
                if(length(rpl) > id + strDataSize - 1 )
                    mData = uint8( rpl( id - 1 : id + strDataSize - 2 ));
                else
                    pause(0.1);
                    continue;
                end
                
                %run a checksum on the data
                ckSum = uint8(0);
                for i =1: strDataSize-1
                    ckSum = CRC_8(ckSum, mData(i));
                end
                
                %check if we get a valid data
                if ckSum ~= mData(strDataSize)
                    pause(0.1);
                    continue;
                end
                
                %get the data out, first 9 bytes are headers, last byte is
                %check sum
                mData = mData( 10 : 23 );
                
                %check and set polairty
                if( ~ polarityInitDone )
                    % hall for speed
                    for i = 2 : 5
                        a2d(i) = typecast( mData( 2*i-1 : 2*i ),'uint16' );
                        if( a2d(i) > 300 )
                            plrt(2:5) = 1;
                            break;
                        end
                    end
                    
                    % hall for direction
                    for i =6:7
                        a2d(i) = typecast( mData( 2*i-1 : 2*i ),'uint16' );
                        if( a2d(i) > 300 )
                            plrt( 6 : 7 ) = 1;
                            break;
                        end
                    end
                    
                    polarityInitDone = 1;
                    continue;
                end
                
                %parsing data and update results
                for i = 1 : numberOfSensors
                    a2d(i) = double( typecast( mData( 2*i-1 : 2*i ),'uint16' ));
                    
                    %calculate temperature and wrapp around hall readings if
                    %neccessary
                    if (i == 1)
                        %convert to teperature reading, see datasheet
                        a2d(1) = (a2d(1) * 5 *1000/1024 -500)/10;
                    elseif( plrt(i) && i < 6)
                        a2d(i) = 512 - a2d(i);
                    elseif( i > 5)
                        a2d(i) = a2d(i) * 3 /512;
                    end
                    
                    %update max and min
                    if(a2d(i) > a2dMax(i))
                        a2dMax(i) = a2d(i);
                    end
                    if(a2d(i) < a2dMin(i))
                        a2dMin(i) = a2d(i);
                    end
                    %find patch range and color
                    if(a2dRangeLimit(i) == 0.0)
                        px(i) = 1;
                    else
                        px(i) =(a2dMax(i)- a2dMin(i))/a2dRangeLimit(i);
                    end
                    if px(i) >= 1
                        px(i) =1;
                        testData.results.sensorPass(i) = 1;
                    end
                    %update gui
                    try                        
                        set(sensorGui.patch(i), 'FaceColor',[0, px(i), 0],...
                            'XData',[0, px(i), px(i), 0],...
                            'YData',[0, 0,  1,  1]);
                        set(sensorGui.text(i), 'String', num2str(a2d(i)));
                    catch ME
                        testData.results.testSummary = ME.message;
                        presentMakoResults(guiHandles, 'FAILURE', ...
                            testData.results.testSummary);
                        return;
                    end
                    %save some data
                    testData.results.min(i) = a2dMin(i);
                    testData.results.max(i) = a2dMax(i);
                    testData.results.polarity(i) = plrt(i);
                end
                testData.results.data(:,end+1) = a2d;
                %refresh
                drawnow;
                
                %check if test is completed, if all pass, then return
%                 if testData.results.sensorPass
%                     break;
%                 end
                pause(0.01);
            end
        catch ME
            testData.results.testSummary = ME.message;
            presentMakoResults(guiHandles, 'FAILURE', ...
                testData.results.testSummary);
            return;
        end
        %update temperature sensor data, only the last 10 samples are used
        if(length(testData.results.data(1,:)) > 10)
            temperatureData = testData.results.data(1 , end - 10 : end);
            a2dMax(1) = max( temperatureData);
            a2dMin(1) = min( temperatureData);
            testData.results.min(1) = a2dMin(1);
            testData.results.max(1) = a2dMax(1);
        end
        %either test is automatically sompleted or user stop it
        %check the range been hit, if not, update to red
        for i=1 : numberOfSensors
            %check for range
            if( a2dMax(i)- a2dMin(i) < a2dRangeLimit(i) )
                %set red color
                set(sensorGui.patch(i), ...
                    'FaceColor',[1,0,0],...
                    'XData',[0, px(i), px(i), 0],...
                    'YData',[0, 0, 1, 1]);
                testData.results.sensorPass(i) = 0;
                %parse error string
                if ~isempty(testData.results.testSummary)
                    testData.results.testSummary = {testData.results.testSummary{1:end},...
                        sprintf('%s sensor range measured %.1f, expected %.1f',...
                        testData.limits.names{i}, a2dMax(i)- a2dMin(i), a2dRangeLimit(i))};
                else
                    testData.results.testSummary = {sprintf(...
                        '%s sensor range measured %.1f, expected %.1f',...
                        testData.limits.names{i}, a2dMax(i)- a2dMin(i), a2dRangeLimit(i))};
                end
                drawnow;
            end
            %check for maximum value
            if( a2dMax(i) > a2dMaxLimit(i) )
                %set red color
                set(sensorGui.patch(i), ...
                    'FaceColor',[1,0,0],...
                    'XData',[0, px(i), px(i), 0],...
                    'YData',[0, 0, 1, 1]);
                testData.results.sensorPass(i) = 0;
                %parse error string
                if ~isempty(testData.results.testSummary)
                    testData.results.testSummary = {testData.results.testSummary{1:end},...
                        sprintf('%s sensor maximum measured %.1f, expected %.1f',...
                        testData.limits.names{i}, a2dMax(i), a2dMaxLimit(i))};
                else
                    testData.results.testSummary = {sprintf(...
                        '%s sensor maximum measured %.1f, expected %.1f',...
                        testData.limits.names{i}, a2dMax(i), a2dMaxLimit(i))};
                end
                drawnow;
            end
            
            %check for minimum value
            if( a2dMin(i) < a2dMinLimit(i) )
                %set red color
                set(sensorGui.patch(i), ...
                    'FaceColor',[1,0,0],...
                    'XData',[0, px(i), px(i), 0],...
                    'YData',[0, 0, 1, 1]);
                testData.results.sensorPass(i) = 0;
                %parse error string
                if ~isempty(testData.results.testSummary)
                    testData.results.testSummary = {testData.results.testSummary{1:end},...
                        sprintf('%s sensor minimum measured %.1f, expected %.1f',...
                        testData.limits.names{i}, a2dMin(i), a2dMinLimit(i))};
                else
                    testData.results.testSummary = {sprintf(...
                        '%s sensor minimum measured %.1f, expected %.1f',...
                        testData.limits.names{i}, a2dMin(i), a2dMinLimit(i))};
                end
                drawnow;
            end
        end
        
        % save the data
        logFile = [sprintf('%s-',testType), datestr(now,'yyyy-mm-dd-HH-MM')];
        fullLogFile = fullfile(guiHandles.reportsDir,logFile);
        save(fullLogFile,'testData');
        
        % now check and present the final result
        try
            testResults = ...
                [testData.results.sensorPass,testData.results.commandPass];
            if (all(testResults) == 1) %#ok<BDSCI>
                presentMakoResults(guiHandles, 'SUCCESS');
            else
                presentMakoResults(guiHandles, 'FAILURE',...
                    testData.results.testSummary);
            end
        catch %#ok<*CTCH>
            return;
        end
        
    end
%--------------------------------------------------------------------------
% Internal function to read handpiece data
%--------------------------------------------------------------------------
    function getHandPieceData(varargin)
        set(guiHandles.mainButtonInfo,...
            'style','text',...
            'String',{sprintf('%s Test',testType),...
            'Follow instructions, click stop button once finish'});
        %get limit save typing
        a2dMin = testData.results.min; 
        a2dMax = testData.results.max; 
        a2dRangeLimit = testData.limits.a2dRangeLimit;
        numberOfSensors = length(a2dRangeLimit);
        a2d = zeros(1,numberOfSensors); 
        px = ones(1,numberOfSensors); 
        strDataSize = 38;
        plotVariableNames = {'current (amps)','bus voltage (x10 volts)', 'speed (kRPM)', ...
            'command Speed (kRPM)', 'temperature (x10 \circC)', 'irrigation voltage (x10 volts)'};
        %create a buffer for data recording, about 1 minute data
        dataBufferSize = 600;
        nuberOfVariables = 6;
        dataBuffer = zeros(dataBufferSize,nuberOfVariables);
        temperatureBuffer = zeros(dataBufferSize,1);
        hallInfoBuffer = zeros(dataBufferSize,6);
        faultBuffer = zeros(dataBufferSize,1);
        dirBuffer = zeros(dataBufferSize,1);
        scaleFactors = [1.0,0.1,0.001,0.001,0.1,0.1];
        dataCollectionStarted = 0;
        tid = [];
       
        %get plot handle
        ph = plot(dataBuffer,'parent',axPlot);
        legend(ph,plotVariableNames);
        grid(axPlot,'minor');
        ylim(axPlot,[-2,20]);
        while ~userStopTest
            tcpReply = TCPRead(tcpHdl,strDataSize *3);
            idx =strfind(tcpReply',[253,strDataSize]);
            %check if enough data is ready
            if(~isempty(idx))
                if ((length(tcpReply) - idx(end)) >= (strDataSize - 1))
                    rpl = tcpReply(idx : idx + strDataSize - 1);
                    motorCurrent = double(typecast(rpl(3:4),'int16')) / 1000;
                    busVoltage = double(typecast(rpl(5:8),'int32')) / 1000;
                    speed = double(typecast(rpl(9:12),'uint32'));
                    if(speed > 5000 && ~dataCollectionStarted) 
                        dataCollectionStarted =1;
                        tid = tic;
                    end
                    dirRotor = rpl(13);
                    fault = typecast(rpl(14:17),'uint32');
                    temperature = double(typecast(rpl(18:19),'int16'));
                    irrigationVoltage = double(typecast(rpl(20:21),'int16')) / 1000;
                    speedCmd = double(typecast(rpl(34:37),'uint32'));
                    for i = 0 : 2: 11
                        hallInfo(idivide(uint8(i),2)+1) = double(typecast(rpl(22+i:23+i),'uint16')); %#ok<AGROW>
                    end
                  
                    %collect data                     
                    dataBuffer = [dataBuffer(2:end,:); [motorCurrent, busVoltage, ...
                        speed, speedCmd, temperature, irrigationVoltage]];
                    temperatureBuffer = [temperatureBuffer(2:end);temperature];
                    hallInfoBuffer = [hallInfoBuffer(2:end,:);hallInfo];
                    faultBuffer = [faultBuffer(2:end); fault];
                    dirBuffer = [dirBuffer(2:end); dirRotor];
                    %update
                    for i=1: nuberOfVariables
                        set(ph(i),'YData',dataBuffer(:,i)*scaleFactors(i));
                    end
                    %update temperature
                    set(sensorGui.text(1),'String',temperature);
                    %update trigger info 
                    for i = 2:5
                        set(sensorGui.text(i),'String',hallInfo(i-1));
                    end
                    
                    for i = 6:7
                        set(sensorGui.text(i),'String',hallInfo(i-1) * 3 / 512);
                    end
                end
                drawnow;
            end
            %stop test after motor running for requred test time
            if(~isempty(tid))
                if(toc(tid) > testData.time)
                    break;
                end
            end
            pause(0.01);
        end
        
        if(~isempty(tid))
            time_tested = toc(tid); % Time spent on acutal test
        else
            time_tested = 0;
        end
        
        %Test completed, check data against limits: motor current, speed
        %error,
        testData.results.sensorPass = ones(1,4);

        % determine dataBuffer size based on actual time tested
        % The buffer has ~60 seconds. Requirements state the last 20
        % seconds to be used for calculation when available
        if time_tested >= 20.05 
            dataFinal = dataBuffer(end-200:end,:); % ~20seconds = 200 index, last in first out
        else % < 20 seconds
            dataFinal = dataBuffer(end-floor(time_tested)*10:end,:);
        end
            
            
        %check for current limit     
        if( mean(dataFinal(:,1)) > testData.limits.maxCurrentNoLoad)
            testData.results.sensorPass(1) = 0;
            %parse error string
            if ~isempty(testData.results.testSummary)
                testData.results.testSummary = {testData.results.testSummary{1:end},...
                    sprintf('Motor current exceeds limits, measured %f, expected %f',...
                    mean(dataFinal(:,1)), testData.limits.maxCurrentNoLoad)};
            else
                testData.results.testSummary = {sprintf(...
                    'Motor current exceeds limits: measured %f, expected %f',...
                    mean(dataFinal(:,1)), testData.limits.maxCurrentNoLoad)};
            end
            drawnow;
        end
        %check for speed error
        maxSpeedError = max(abs(dataFinal(:,4) - dataFinal(:,3)));
        if( maxSpeedError > testData.limits.speedError)
            testData.results.sensorPass(2) = 0;
            %parse error string
            if ~isempty(testData.results.testSummary)
                testData.results.testSummary = {testData.results.testSummary{1:end},...
                    sprintf('Motor speed error exceeds limits: measured %.1f, expected %.1f',...
                    maxSpeedError, testData.limits.speedError)};
            else
                testData.results.testSummary = {sprintf(...
                    'Motor speed error exceeds limits: measured %.1f, expected %.1f',...
                    maxSpeedError, testData.limits.speedError)};
            end
            drawnow;
        end
        
        %check for maximum speed error
        maxSpeed = mean(dataFinal(:,4));
        if( maxSpeed < testData.limits.lowerMaxSpeed)
            testData.results.sensorPass(3) = 0;
            %parse error string
            if ~isempty(testData.results.testSummary)
                testData.results.testSummary = {testData.results.testSummary{1:end},...
                    sprintf('Motor maximum speed exceeds limits: measured %.1f, expected %.1f',...
                    maxSpeed, testData.limits.lowerMaxSpeed)};
            else
                testData.results.testSummary = {sprintf(...
                    'Motor maximum speed exceeds limits: measured %.1f, expected %.1f',...
                    maxSpeed, testData.limits.lowerMaxSpeed)};
            end
            drawnow;
        end
        if(testData.checkFault)
            %check for other faults
            faultIndices = find(faultBuffer > 0);
            if(~isempty(faultIndices))
                testData.results.sensorPass(4) = 0;
                %parse error string
                logIndex = log2(double(faultBuffer(faultIndices(1)))) + 1;
                if ~isempty(testData.results.testSummary)
                    testData.results.testSummary = {testData.results.testSummary{1:end},...
                        sprintf('%s',testData.faultMsg{logIndex})};
                else
                    testData.results.testSummary = { sprintf('%s',testData.faultMsg{logIndex})};
                end
                drawnow;
            end
        end
               
        % save the data
        logFile = [sprintf('%s-',testType), datestr(now,'yyyy-mm-dd-HH-MM')];
        fullLogFile = fullfile(guiHandles.reportsDir,logFile);
        testData.results.data.dataBuffer = dataBuffer;
        testData.results.data.dataFinal = dataFinal;
        testData.results.data.temperatureBuffer = temperatureBuffer;
        testData.results.data.hallInfoBuffer = hallInfoBuffer;
        testData.results.data.faultBuffer = faultBuffer;
        testData.results.data.dirBuffer = dirBuffer;
        save(fullLogFile,'testData');
        
        % now check and present the final result
%         try
            testResults = ...
                [testData.results.sensorPass,testData.results.commandPass];
            if all(testResults == 1) && (time_tested >= testData.time) %#ok<BDSCI>
                if(testData.reportCurrent)
                    presentMakoResults(guiHandles, 'SUCCESS',...
                        sprintf('Average current %.2f (Amps)',abs(mean(dataFinal(:,1)))));
                else
                    presentMakoResults(guiHandles, 'SUCCESS');
                end
                
            elseif all(testResults == 1) && ~(time_tested >= testData.time) %#ok<BDSCI>
                if(testData.reportCurrent)
                    presentMakoResults(guiHandles, 'WARNING',...
                        {sprintf('Average current %.2f (Amps)',abs(mean(dataFinal(:,1)))), ...
                        sprintf('Time spent collecting data %.2f (s), %.2f (s) required',time_tested, testData.time)});
                else
                    presentMakoResults(guiHandles, 'WARNING', ...
                        sprintf('Time spent collecting data %.2f (s), %.2f (s) required',time_tested, testData.time));
                end
                
            else
                if(testData.reportCurrent)
                    presentMakoResults(guiHandles, 'FAILURE',...
                    sprintf('Average current: %.2f (Amps)',abs(mean(dataFinal(:,1)))));
                else
                    presentMakoResults(guiHandles, 'FAILURE',...
                    testData.results.testSummary);
                end
            end
            drawnow;
%         catch %#ok<*CTCH>
%             return;
%         end
    end
%--------------------------------------------------------------------------
% Internal function to stop test
%--------------------------------------------------------------------------
    function stopTest(varargin)
        userStopTest = 1;
        set(pbUserStop, 'enable', 'off');
    end
%--------------------------------------------------------------------------
% Internal function to exit the code
%--------------------------------------------------------------------------
    function MICSTestClose(varargin)
        %check serial handle and close it accordingly
        if ~isempty(sHdl)
            fclose(sHdl);
            delete(sHdl);
            clear(sHdl);
        end
        %check and close tcp connection
        if ~isempty(tcpHdl)
            tcpHdl.Close();
            clear all;
        end
        %update flag as well
        userStopTest = 1;
        
        %set ip to dynamic
        system(['netsh interface ip set address ',...
            'name="Local Area Connection" dhcp']);
    end
%--------------------------------------------------------------------------
% Internal function to initialize the test data for trigger board
%--------------------------------------------------------------------------
    function initTriggerBoardData(varargin)
        
        %limit setting
        testData.limits.a2dRangeLimit =[0, 105, 105, 105, 105, 0, 0]; % 0 means do not care
        testData.limits.a2dMinLimit = [47, 57, 57, 57, 57, 2.3, 1.3]; 
        testData.limits.a2dMaxLimit = [53, 276, 276, 276, 276, 2.7, 1.6]; 
        testData.limits.names = {'Temperature', 'Hall-1', 'Hall-2', 'Hall-3', 'Hall-4', 'Voltage1', 'Voltage2'};
        testData.results.min = 2^16 * ones(1,length(testData.limits.a2dRangeLimit));
        testData.results.max = zeros(1,length(testData.limits.a2dRangeLimit));
        testData.results.polarity = zeros(1,length(testData.limits.a2dRangeLimit));
        testData.results.sensorPass = zeros(1,length(testData.limits.a2dRangeLimit));
        testData.results.commandPass =[]; % will be initialized in the test function
        testData.results.data = [];
        testData.results.testSummary = [];
        testData.time = 60;
    end

%--------------------------------------------------------------------------
% Internal function to initialize the test data for trigger board
%--------------------------------------------------------------------------
    function initHandPieceData(varargin)
        %limit setting for trigger board
        initTriggerBoardData();
        
        %set ip to static
        system(['netsh interface ip set address ',...
            'name="Local Area Connection" static ','10.1.1.150',...
            ' 255.255.255.0 ']);
        
        testData.limits.a2dRangeLimit =[0, 126, 126, 126, 126, 0, 0]; % 0 means do not care
        testData.limits.a2dMinLimit = [0, 84, 84, 84, 84, 2.3, 1.3];
        testData.limits.a2dMaxLimit = [0, 275, 275, 275, 275, 2.7, 1.6];
        
        %limit setting for handpiece
        testData.limits.lowerMaxSpeed = 11800; %rpm
        testData.limits.maxCurrentNoLoad = 1.8; %amp
        testData.limits.speedError = 200; %rpm
        %test time
        testData.time = 60; %1 min
        testData.checkFault = 0;
        testData.reportCurrent = 0;
        
        testData.faultMsg = {...
            'Software E-Stop fault', ...
            'Low bus voltage fault',...
            'High bus voltage fault',...
            'Low current fault',...
            'High current fault',...
            'Watchdog fault',...
            'High temperature fault',...
            'Irrigation short fault',...
            'Hardware current fault',...
            'MICS system fault',...
            'Handpiece communication fault',...
            'Handpiece hall fault',...
            'Motor short fault',...
            'Handpiece trigger initial position fault',...
            'MICS current offset fault',...
            'Handpiece ADC fault',...
            'Reserved',...
            'Reserved',...
            'Handpiece voltage range warning',...
            'Handpiece trigger range warning',...
            'Handpiece trigger sequence warning',...
            'Reserved',...
            'Reserved',...
            'Reserved',...
            'Handpiece trigger hall-1 high warning',...
            'Handpiece trigger hall-2 high warning',...
            'Handpiece trigger hall-3 high warning',...
            'Handpiece trigger hall-4 high warning',...
            'Handpiece trigger hall-1 low warning',...
            'Handpiece trigger hall-2 low warning',...
            'Handpiece trigger hall-3 low warning',...
            'Handpiece trigger hall-4 low warning',...
            };        
    end

%--------------------------------------------------------------------------
% Internal function to initialize the test data for motor seal
%--------------------------------------------------------------------------
    function initMotorSealData(varargin)

        %call inial trigger board data
        initHandPieceData();
        
        %change other settings
        testData.limits.a2dRangeLimit =[0, 0, 0, 0, 0, 0, 0]; %0 means do not care
        testData.limits.a2dMinLimit = [0, 0, 0, 0, 0, 0, 0]; %do not care
        testData.limits.a2dMaxLimit = ones(7,1) * 1.0e10;
        
        %limit setting for handpiece
        testData.limits.speedError = 1.0e10; %do not care
        
        %test time
        testData.time = 600; %10 mins
        testData.checkFault = 0; % do not check firmware fault
        testData.reportCurrent = 1;
    end
%--------------------------------------------------------------------------
% Internal function to read trigger board firmware version
%--------------------------------------------------------------------------
    function fwVersion = getTriggerBoardFirmwareVersion(comm,mHdl)
        switch comm
            case 'TRIGGERBOARD'
                %set to debug mode
                cmdFv = uint8(hex2dec({'ff','05','80','00','a7'})');
                fwrite(mHdl,cmdFv);
                warning off all;
                fread(mHdl);
                warning on all;
                %now start reading firmware version
                cmdFv = uint8(hex2dec({'ff','05','81','16','d0'})');
                fwrite(mHdl,cmdFv);
                while(mHdl.BytesAvailable < 26)
                    pause(0.01);
                end
                fwVersion = fread(mHdl,26)';
                idx =find(fwVersion);
                % firmware version start from 10th byte and stop at second
                % last non-zero byte, the last non-zero byte is check sum
                fwVersion = char(fwVersion(10:idx(end-1)));
            case 'HANDPIECE'
                %stop streaming
                cmdFv = uint8(hex2dec({'ff','04','24','d9'})');
                TCPWrite(mHdl,cmdFv);
                warning off all;
                TCPRead(mHdl,9999);
                warning on all;
                %now start reading firmware version
                cmdFv = uint8(hex2dec({'ff','05','12','4f','9B'})');
                TCPWrite(mHdl,cmdFv);
                fwVersion = TCPRead(mHdl,24)';
                idx =find(fwVersion);
                % firmware version start from 3rd byte and stop at second
                % last non-zero byte, the last non-zero byte is check sum
                fwVersion = char(fwVersion(4 : idx(end-1)));
            case 'COMMUTATIONBOARD'
                %stop streaming
                cmdFv = uint8(hex2dec({'ff','04','24','d9'})');
                TCPWrite(mHdl,cmdFv);
                warning off all;
                TCPRead(mHdl,9999);
                warning on all;
                %now start reading firmware version
                cmdFv = uint8(hex2dec({'ff','05','12','00','ea'})');
                TCPWrite(mHdl,cmdFv);
                fwVersion = TCPRead(mHdl,24)';
                idx =find(fwVersion);
                % firmware version start from 3rd byte and stop at second
                % last non-zero byte, the last non-zero byte is check sum
                fwVersion = char(fwVersion(4 : idx(end-1)));
            otherwise
                fwVersion = '';
        end
    end
%--------------------------------------------------------------------------
% Internal function to generate CRC8
%--------------------------------------------------------------------------
    function checkSum = CRC_8(iCRC, iChar)
        data = uint16(bitxor(iCRC, iChar));
        data = bitshift(data, 8);
        for i = 1: 8
            if(bitand(data, uint16(2 ^15)) ~= 0)
                data = bitxor(data, bitshift(uint16(4208), 3));
            end
            data = bitshift(data, 1);
        end
        checkSum = uint8(bitshift(data, -8));
    end
%--------------------------------------------------------------------------
% Internal function to save EE constants
%--------------------------------------------------------------------------
    function saveEEConstants(hObject, eventdata, varargin) %#ok<INUSL>
        set(guiHandles.mainButtonInfo,...
            'style','text',...
            'String',{sprintf('%s Test',testType),...
            'update constants, wait...'});
        %turn off enable to prevent repeated click
        set(guiHandles.uiPbEEConstCancel,'Enable','off');
        set(guiHandles.uiPbEEConstLoad,'Enable','off');
        set(guiHandles.uiPbEEConstSave,'Enable','off');
        
        newData = get(varargin{1},'Data');    
        eeSNStr = get(get(varargin{1},'parent'),'Title');
        
        dataMICS = get(varargin{2},'Data');         
        eeSNStrMICS = get(get(varargin{2},'parent'),'Title');
        eeSN = sscanf(eeSNStr,['From File:SN-' '%f']);
        micsTable = varargin{2};
        mics = mako_mics();
        
        %update ee serial number first
        if(~isempty(eeSN))      
            
            %check and update the ee constants as needed
            mics.ee_origin = newData(1,:);
            mics.ee_tool_axis = newData(2,:);
            mics.ee_normal_axis = newData(3,:);
            mics.serial_number = eeSN;
            
            
            % check ee constants
            ee_origin = mics.ee_origin;
            ee_normal_axis = mics.ee_normal_axis;
            ee_tool_axis = mics.ee_tool_axis;
            
            % normLimit ignored by making threshold 1e10
            normLimit = 1e10; % dont care
            if(norm(ee_origin - newData(1,:))> normLimit)
                presentMakoResults(guiHandles,'FAILURE','ee origin mismatch');
                
            elseif(norm(ee_tool_axis - newData(2,:))> normLimit)
                presentMakoResults(guiHandles,'FAILURE','ee normal axis mismatch');
                
            elseif (norm(ee_normal_axis - newData(3,:)) > normLimit)
                presentMakoResults(guiHandles,'FAILURE','ee tool axis mismatch');
                
            else
                set(micsTable,'Data',newData);
                set(get(micsTable,'parent'),'Title',sprintf('From MICS:SN-%07d',eeSN));
                presentMakoResults(guiHandles,'SUCCESS');
            end
            
            % Hide the Cancel, Load, and Save buttons upon script
            % completion regardless of pass, warning, or fail. 
            set(guiHandles.uiPbEEConstCancel,'Visible','off');
                set(guiHandles.uiPbEEConstLoad,'Visible','off');
                set(guiHandles.uiPbEEConstSave,'Visible','off');
        end
        pause(2.0);%add a pause for UI to finish update
        delete(mics);
    end
%--------------------------------------------------------------------------
% Internal function to cancel update EE constants
%--------------------------------------------------------------------------
    function cancelEEConstants(hObject, eventdata, varargin) %#ok<INUSL>
         set(guiHandles.uiPbEEConstCancel,'Visible','off');
         set(guiHandles.uiPbEEConstLoad,'Visible','off');
         set(guiHandles.uiPbEEConstSave,'Visible','off'); 
        %restore the ee constant data
        set(varargin{1},'Data',{});        
        set(get(varargin{1},'parent'),...
            'Title',sprintf('From File:SN-%d',[]));
        presentMakoResults(guiHandles,'WARNING','WARNING File Not Loaded');
    end

%--------------------------------------------------------------------------
% Internal function to load update EE constants from a file
%--------------------------------------------------------------------------
    function loadEEConstantsFromFile(hObject, eventdata, varargin) %#ok<INUSL>
      
        [fName,pName] = uigetfile({'*.txt;*.tcl'},'Select EE constants file');
        eefileName = fullfile(pName,fName);
        fh = fopen(eefileName, 'r');
        set(guiHandles.uiPbEEConstLoad,'Enable','off');
        % ee file is in the following format
        % Measured Date
        % 2012-12-09
        % EE Serial Number
        % SN-1234567
        % Origin(mm)
        % -85.1234, 0.1234, -41.1234
        % Tool axis point(mm)
        % -130.1234, 0.1234, -41.1234
        % Normal axis point(mm)
        % -85.1234, 0.1234, -21.1234
        %read the first two lines and ignore them
        try
        eeContantDate = fgetl(fh); %#ok<*NASGU>
        eeContantDate = fgetl(fh);
        eeSNName = fgetl(fh); %#ok<NASGU>
        eeSNStr = fgetl(fh);
        eeSN = sscanf(eeSNStr,['SN-' '%07d']);
        rNames{1} = fgetl(fh);
        eeOrigin = fscanf(fh,'%f,%f,%f');
        rNames{2} = fgetl(fh);
        eeToolAxis = fscanf(fh,'%f,%f,%f');
        rNames{3} = fgetl(fh); %#ok<NASGU>
        eeNormalAxis = fscanf(fh,'%f,%f,%f');
        eeConstData = [eeOrigin';eeToolAxis';eeNormalAxis'];
        set(varargin{1},'Data',eeConstData);
        set(get(varargin{1},'parent'),...
            'Title',sprintf('From File:SN-%d',eeSN));
        drawnow;
        catch
            presentMakoResults(guiHandles, 'FAILURE','Bad Constants File');
            return;
        end
    end

end


% --------- END OF FILE ----------
