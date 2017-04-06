function AnspachBoxTest

% AnspachBoxTest Gui to test out the Anaspach box
% Syntax:
%   AnspachBoxTest
%       This function will perform a test of all the software
%       communication with the Anspach
%
% Notes:
%   The test assumes that Anspach has been power cycled and is connected to
%   COM1.
%
% VERY IMPORTANT NOTE is using Matlab 2007b or lower.  apply patch as
% described in Bug #2975 for reliable operation.  Otherwise there might be
% fwrite errors
%
% See also:
%   peripheral_gui
%

%
% $Author: dmoses $
% $Revision: 4149 $
% $Date: 2015-09-28 14:30:33 -0400 (Mon, 28 Sep 2015) $
% Copyright: MAKO Surgical corp (2008)
%

% Query the user for the serial number/workid
jobId = getMakoJobId;

% handle the cancel button
if isempty(jobId)
    return;
end

% Generate the gui
guiHandles = generateMakoGui('Anspach Box Test',[],jobId);

% Now setup the callback to allow user to press and start the test
updateMainButtonInfo(guiHandles,@anspachTests);

%--------------------------------------------------------------------------
% Internal function to update the gui display elements
%--------------------------------------------------------------------------
    function anspachTests(varargin)
        
        % HARDCODE the expected responses for the sequence.  This is done
        % so that the test is always repeated and does not adapt to
        % changing conditions like someone pressing a pedal or button etc
        % adapting to changing conditions might give us false positives
        
        commandSequence = {...
            {'V','get status',{'foot1','forward',0,80000,1,'no_error'}},...            
            {'T','change to foot control port 2',{'foot2','forward',0,80000,1,'no_error'}},...
            {'T','change to foot control port 1',{'foot1','forward',0,80000,1,'no_error'}},...
            {'H','change to hand control',{'hand','forward',0,80000,1,'no_error'}},...
            {'T','change to foot control port 1',{'foot1','forward',0,80000,1,'no_error'}},...
            {'B','Reverse direction',{'foot1','reverse',0,80000,1,'no_error'}},...
            {'F','forward direction',{'foot1','forward',0,80000,1,'no_error'}},...
            {'G','Turn on drip',{'foot1','forward',1,80000,1,'no_error'}},...
            {'G','Turn off drip',{'foot1','forward',0,80000,1,'no_error'}},...
            {'G','Turn on drip again (to test drip level)',{'foot1','forward',1,80000,1,'no_error'}},...
            {'R','Increase drip (1)',{'foot1','forward',2,80000,1,'no_error'}},...
            {'R','Increase drip (2)',{'foot1','forward',3,80000,1,'no_error'}},...
            {'R','Increase drip (3)',{'foot1','forward',4,80000,1,'no_error'}},...
            {'R','Increase drip (4)',{'foot1','forward',5,80000,1,'no_error'}},...
            {'R','Increase drip (5)',{'foot1','forward',6,80000,1,'no_error'}},...
            {'R','Increase drip (6)',{'foot1','forward',7,80000,1,'no_error'}},...
            {'R','Increase drip (7)',{'foot1','forward',8,80000,1,'no_error'}},...
            {'R','Increase drip (8)',{'foot1','forward',8,80000,1,'no_error'}},...
            {'L','Decrease drip (8)',{'foot1','forward',7,80000,1,'no_error'}},...
            {'L','Decrease drip (7)',{'foot1','forward',6,80000,1,'no_error'}},...
            {'L','Decrease drip (6)',{'foot1','forward',5,80000,1,'no_error'}},...
            {'L','Decrease drip (5)',{'foot1','forward',4,80000,1,'no_error'}},...
            {'L','Decrease drip (4)',{'foot1','forward',3,80000,1,'no_error'}},...
            {'L','Decrease drip (3)',{'foot1','forward',2,80000,1,'no_error'}},...
            {'L','Decrease drip (2)',{'foot1','forward',1,80000,1,'no_error'}},...
            {'L','Decrease drip (1)',{'foot1','forward',1,80000,1,'no_error'}},...
            {'G','Turn Drip off to return to default state',{'foot1','forward',0,80000,1,'no_error'}},...
            {'D','Decrease speed (8)',{'foot1','forward',0,70000,1,'no_error'}},...
            {'D','Decrease speed (7)',{'foot1','forward',0,60000,1,'no_error'}},...
            {'D','Decrease speed (6)',{'foot1','forward',0,50000,1,'no_error'}},...
            {'D','Decrease speed (5)',{'foot1','forward',0,40000,1,'no_error'}},...
            {'D','Decrease speed (4)',{'foot1','forward',0,30000,1,'no_error'}},...
            {'D','Decrease speed (3)',{'foot1','forward',0,20000,1,'no_error'}},...
            {'D','Decrease speed (2)',{'foot1','forward',0,10000,1,'no_error'}},...
            {'D','Decrease speed (1)',{'foot1','forward',0,10000,1,'no_error'}},...
            {'U','Increase speed (1)',{'foot1','forward',0,20000,1,'no_error'}},...
            {'U','Increase speed (2)',{'foot1','forward',0,30000,1,'no_error'}},...
            {'U','Increase speed (3)',{'foot1','forward',0,40000,1,'no_error'}},...
            {'U','Increase speed (4)',{'foot1','forward',0,50000,1,'no_error'}},...
            {'U','Increase speed (5)',{'foot1','forward',0,60000,1,'no_error'}},...
            {'U','Increase speed (6)',{'foot1','forward',0,70000,1,'no_error'}},...
            {'U','Increase speed (7)',{'foot1','forward',0,80000,1,'no_error'}},...
            {'U','Increase speed (8)',{'foot1','forward',0,80000,1,'no_error'}},...
            {'V','Verify settings for manual QIP procedure',{'foot1','forward',0,80000,1,'no_error'}}...
	    };
    
    
        commandSequence2 = {...
            {'V','get status',{'foot1','forward',0,80000,1,'no_error'}},...            
            {'T','change to foot control port 2',{'foot2','forward',0,80000,1,'no_error'}},...
            {'T','change to foot control port 1',{'foot1','forward',0,80000,1,'no_error'}},...
            {'H','change to hand control',{'hand','forward',0,80000,1,'no_error'}},...
            {'T','change to foot control port 1',{'foot1','forward',0,80000,1,'no_error'}},...
            {'B','Reverse direction',{'foot1','reverse',0,80000,1,'no_error'}},...
            {'F','forward direction',{'foot1','forward',0,80000,1,'no_error'}},...
            {'G','Turn on drip',{'foot1','forward',1,80000,1,'no_error'}},...
            {'G','Turn off drip',{'foot1','forward',0,80000,1,'no_error'}},...
            {'G','Turn on drip again (to test drip level)',{'foot1','forward',1,80000,1,'no_error'}},...
            {'R','Increase drip (1)',{'foot1','forward',2,80000,1,'no_error'}},...
            {'R','Increase drip (2)',{'foot1','forward',3,80000,1,'no_error'}},...
            {'R','Increase drip (3)',{'foot1','forward',4,80000,1,'no_error'}},...
            {'R','Increase drip (4)',{'foot1','forward',5,80000,1,'no_error'}},...
            {'R','Increase drip (5)',{'foot1','forward',6,80000,1,'no_error'}},...
            {'R','Increase drip (6)',{'foot1','forward',7,80000,1,'no_error'}},...
            {'R','Increase drip (7)',{'foot1','forward',8,80000,1,'no_error'}},...
            {'R','Increase drip (8)',{'foot1','forward',8,80000,1,'no_error'}},...
            {'L','Decrease drip (8)',{'foot1','forward',7,80000,1,'no_error'}},...
            {'L','Decrease drip (7)',{'foot1','forward',6,80000,1,'no_error'}},...
            {'L','Decrease drip (6)',{'foot1','forward',5,80000,1,'no_error'}},...
            {'L','Decrease drip (5)',{'foot1','forward',4,80000,1,'no_error'}},...
            {'L','Decrease drip (4)',{'foot1','forward',3,80000,1,'no_error'}},...
            {'L','Decrease drip (3)',{'foot1','forward',2,80000,1,'no_error'}},...
            {'L','Decrease drip (2)',{'foot1','forward',1,80000,1,'no_error'}},...
            {'L','Decrease drip (1)',{'foot1','forward',1,80000,1,'no_error'}},...
            {'G','Turn Drip off to return to default state',{'foot1','forward',0,80000,1,'no_error'}},...
            {'D','Decrease speed (8)',{'foot1','forward',0,70000,1,'no_error'}},...
            {'D','Decrease speed (7)',{'foot1','forward',0,60000,1,'no_error'}},...
            {'D','Decrease speed (6)',{'foot1','forward',0,50000,1,'no_error'}},...
            {'D','Decrease speed (5)',{'foot1','forward',0,40000,1,'no_error'}},...
            {'D','Decrease speed (4)',{'foot1','forward',0,30000,1,'no_error'}},...
            {'D','Decrease speed (3)',{'foot1','forward',0,20000,1,'no_error'}},...
            {'D','Decrease speed (2)',{'foot1','forward',0,10000,1,'no_error'}},...
            {'D','Decrease speed (1)',{'foot1','forward',0,10000,1,'no_error'}},...
            {'U','Increase speed (1)',{'foot1','forward',0,20000,1,'no_error'}},...
            {'U','Increase speed (2)',{'foot1','forward',0,30000,1,'no_error'}},...
            {'U','Increase speed (3)',{'foot1','forward',0,40000,1,'no_error'}},...
            {'U','Increase speed (4)',{'foot1','forward',0,50000,1,'no_error'}},...
            {'U','Increase speed (5)',{'foot1','forward',0,60000,1,'no_error'}},...
            {'U','Increase speed (6)',{'foot1','forward',0,70000,1,'no_error'}},...
            {'U','Increase speed (7)',{'foot1','forward',0,80000,1,'no_error'}},...
            {'U','Increase speed (8)',{'foot1','forward',0,80000,1,'no_error'}},...
            {'V','Verify settings for manual QIP procedure',{'foot1','forward',0,80000,1,'no_error'}}...
	    };
    
        % Automatically setup the command list to be tested.  Stack them in
        % columns 15 rows long
        blockSize = 0.8/15/1.5;
        
        % determine number of columns and appropriate spacing for them
        numCols = ceil(length(commandSequence)/15);
        colSize = 0.9/numCols-0.05;  % 0.05 is reserved for margins
        
        for i=1:length(commandSequence)
            commandLabels(i) = uicontrol(guiHandles.uiPanel,...
                'Style','text',...
                'String',commandSequence{i}(2),...
                'Units','normalized',...
                'Position',[ 0.05+floor((i-1)/15)*(colSize+0.05) ...
                    0.9-1.5*mod(i-1,15)*blockSize ...
                    colSize blockSize ]...
                ); %#ok<AGROW>
        end
        
        % Wait for anspach to Reset
        updateMainButtonInfo(guiHandles,'text','Waiting for Anspach to reset');
        pause(3);
        
        % setup connection to anspach
        updateMainButtonInfo(guiHandles,'text','Connecting on COM1');
        % delete previous  connections if any
        delete(instrfind('port','COM1'));
        serial_id = serial('COM1');
        set(serial_id,'Terminator',0,'InputBufferSize',11,'Baud',1200);
        fopen(serial_id);
        updateMainButtonInfo(guiHandles,'Connection successful');
        pause(0.5);
        
        % Start testing
        updateMainButtonInfo(guiHandles,'Testing communication....');
        pause(1);
        
        % do a get status just to clear up the buffer if this test is being
        % repeated or someting like that
        anspachComm(serial_id,'V');
        
        % Go through the sequence of commands comparing command to response
        testSuccess = true;
        for i=1:length(commandSequence)
            updateMainButtonInfo(guiHandles,commandSequence{i}{2});
            responseReceived = anspachComm(serial_id,commandSequence{i}{1});
            
            %parse anspach reply
            anspachReplyParsed=anspachReplyParse(responseReceived);
            
            %compare the commands and replies
            for j=1:6
                % if it is a number compare numbers
                if isnumeric(commandSequence{i}{3}{j})
                    if( anspachReplyParsed{j}~=commandSequence{i}{3}{j} && anspachReplyParsed{j}~=commandSequence2{i}{3}{j} ) 
                        errorQipMsg=sprintf('(expected %d got %d)',...
                            commandSequence{i}{3}{j},...
                            anspachReplyParsed{j});
                        testSuccess=false;
                        break;
                    end
                else
                    % if it is a string compare strings
                    if( ~strcmp(anspachReplyParsed{j},commandSequence{i}{3}{j}) && ~strcmp(anspachReplyParsed{j},commandSequence2{i}{3}{j}) ) 
                        errorQipMsg=sprintf('(expected %s got %s)',commandSequence{i}{3}{j},...
                            anspachReplyParsed{j});
                        testSuccess=false;
                        break;
                    end
                end
            end
            
            % change color if tests are successful
            % on failure change color and stop test immediately
            if testSuccess
                set(commandLabels(i),'Background','green');
            else
                set(commandLabels(i),'Background','red');
                % if this was the first run suggest checking reset
                if (i==1)
                    errorQipMsg=sprintf('Default status mismatch, Ensure reset button was pressed');
                end
                break;
            end   
        end
        

        
        % Now present the results
        if testSuccess
            %turn on the drip
            anspachComm(serial_id,'G');
            pause(0.2);
            %increase the drip to maximum
            for i=1:8
                anspachComm(serial_id,'R');
                pause(0.2);
            end

            presentMakoResults(guiHandles,'SUCCESS');

        else
            presentMakoResults(guiHandles,'FAILURE',...
                {sprintf('Failed on command %s',commandSequence{i}{1}),...
                errorQipMsg,...
                });
        end

         % Cleanup
        fclose(serial_id);
        delete(serial_id);
    end

%--------------------------------------------------------------------------
% Internal function to communicate with the anspach controller firmware
%--------------------------------------------------------------------------
    function response=anspachComm(serial_id,command)
        
        % send the command (command V is reserved for getting status
        if command~='V'
            fwrite(serial_id,command);
        end
        
        % wait for sometime to allow the firmware to respond
        pause(0.2);
        
        % port command should take more time.  so add some delay
        if (command=='P')
            pause(1);
        end
        
        % send a V to get the latest status
        fwrite(serial_id,'V');
        response = fread(serial_id);
        
        % convert to string for easy handling later on
        response = char(response');
        if isempty(response)
            response = 'NoResponse';
        end

    end

%--------------------------------------------------------------------------
% Internal function to parse the anspach return string
%--------------------------------------------------------------------------
    function anspachReply=anspachReplyParse(anspachReplyString)        
        
        %bit masks
        handfootMask=sscanf('0013','%x');
        directionMask=sscanf('000c','%x');
        dripMask=sscanf('ff00','%x');
        portMask=sscanf('0060','%x');
        speedMask=sscanf('ff0000','%x');
        errorCharMask=sscanf('007900','%x');
        errorCodeMask=sscanf('00007f','%x');
        
        %error number numeric value
        e1Bits=sscanf('06','%x');
        e2Bits=sscanf('5b','%x');
        e3Bits=sscanf('4f','%x');
        e4Bits=sscanf('66','%x');
        e5Bits=sscanf('6d','%x');
        e6Bits=sscanf('7d','%x');
        e7Bits=sscanf('07','%x');
        e8Bits=sscanf('7f','%x');
        e9Bits=sscanf('6f','%x');
        errorCodeArray=[e1Bits,e2Bits,e3Bits,e4Bits,e5Bits,e6Bits,e7Bits,e8Bits,e9Bits];
        
        
        statusField=sscanf(anspachReplyString,'%6x%4x');
        %speed setting
        temp=bitand(statusField(1),speedMask);
        if(temp==0)
            spd=0;
        else
            spd=(floor(log2(bitshift(temp,-15))))*10000;
        end

        
        %error 
        err='no_error';
        errorChar=bitand(statusField(1),errorCharMask);
        if(errorChar==errorCharMask)
            %find error code
            errorCodeTemp=bitand(statusField(1),errorCodeMask);
            errorCodeNumber=0;
            for i=1:length(errorCodeArray)
                if (errorCodeTemp-errorCodeArray(i)==0)
                    errorCodeNumber=i;
                end
            end
            if(errorCodeNumber)
                err=sprintf('E%d',errorCodeNumber);
            end
        end
        

        %hand foot
        temp=bitand(statusField(2), handfootMask);
        if(bitand(temp,1))
            hf='foot1';
        elseif(bitand(bitshift(temp,-1),1))
            hf='foot2';
        elseif (bitand(bitshift(temp,-4),1))
            hf='hand';
        else
            hf='unknown';
        end
        
        %port number
        temp=bitand(statusField(2), portMask);
        port=log2(bitshift(temp,-4));
        
        %direction
        temp=bitand(statusField(2), directionMask);
        if(bitand(bitshift(temp,-2),1))
            dir='forward';
        elseif(bitand(bitshift(temp,-3),1))
            dir='reverse';
        else
            dir='unknown';
        end

        %drip level
        temp=bitand(statusField(2),dripMask);
        if(temp==0)
            drip=0;
        else
            drip=floor(log2(bitshift(temp,-7)));
        end
        
        %put the reply into cell
        anspachReply={hf,dir,drip,spd,port,err};
    end


end


% --------- END OF FILE ----------
