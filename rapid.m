% This program is free software; you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation; either version 3 of the License, or
% (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.

classdef rapid < magstim & handle
    properties (SetAccess = private)
    	enhancedPowerModeStatus = 0; %Enhanced Power Setting Mode
        rapidType
        unlockCode = [];
        version = [];
        controlCommand = '';
        controlBytes;
    end
    
    methods
    	function self = rapid(PortID, rapidType, varargin)
            if nargin < 1
                error('Not Enough Input Arguments');
            end
            if nargin < 2
                rapidType = 'rapid';
            end
            if ~ismember(lower(rapidType),['rapid','super','superplus'])
                error('rapidType Must Be ''Rapid'', ''Super'', or ''SuperPlus''.')
            end
            if length(varargin) > 1
                error('Too Many Input Arguments');
            end
            self = self@magstim(PortID);
            self.rapidType = lower(rapidType);
            if nargin > 2
                self.unlockCode = varargin{1};
            end
        end 
        
        function [errorOrSuccess, deviceResponse] = setAmplitudeA(self, power, varargin)
            % Inputs:
            % power<double> : is the desired power amplitude for stimulator A
            % varargin<bool> refers to getResponse<bool> that can be True (1) or False (0)
            % indicating whether a response from device is required or not.
            % The default value is set to false.

            % Outputs:
            % deviceResponse: is the response that is sent back by the
            % device to the port indicating current information about the device
            % errorOrSuccess: is a boolean value indicating succecc = 0 or error = 1
            % in performing the desired task

            %% Check Input Validity:
            if nargin < 2
                error('Not Enough Input Arguments');
            end
            if nargin < 3
                getResponse = false ; %Default Value Set To 0
            else
                getResponse = varargin{1};
            end
            if (getResponse ~= 0 && getResponse ~= 1 )
                error('getResponse Must Be A Boolean');
            end
            if ~(isnumeric(power))|| rem(power,1)~=0
                error('power Must Be A Whole Number');
            end
            if (power < 0 || ((power > 100) && (self.enhancedPowerMode == 0)) || power > 110)
                error('power Must Be A Positive Value Less Than Or Equal To 100 (or 110 if Enhanced Power Mode activated)');
            end             
            if length(power) > 1
                error('Invaid Power Amplitude. It Must Be A Single Numeric');
            end
            
            %% Create Control Command           
            [errorOrSuccess, deviceResponse] = self.processCommand(['@' sprintf('%03s',num2str(power))], getResponse, 3);

        end
         
        function [errorOrSuccess, deviceResponse] = setTrain(self, trainParameters , varargin)

            % Inputs:           
            % trainParameters<double struct>: is a numeric struct with three fields
            % indicating the desired 'frequency', 'numberOfPulses', 'duration'. In each call of the
            % function, only two of the three parameters can be set, leaving the third field null ([]). 
            % varargin<bool>: refers to getResponse<bool> that can be True (1) or False (0)
            % indicating whether a response from device is required or not.
            % The default value is set to false.
            
            % Outputs:
            % deviceResponse: is the response that is sent back by the
            % device to the port indicating current information about the device
            % errorOrSuccess: is a boolean value indicating succecc = 0 or error = 1
            % in performing the desired task
            
            %% Check Input Validity:
            if nargin < 2
                 error('Not Enough Input Arguments');
            end
            if length(varargin) > 1
                error('Too Many Input Arguments');
            end
            if nargin < 3
                getResponse = false ; %Default Value Set To 0
            else
                getResponse = varargin{1};
            end
            if (getResponse ~= 0 && getResponse ~= 1)
                   error('getResponse Must Be A Boolean');
            end
            
            if ~isempty(trainParameters.frequency)
                frequency = trainParameters.frequency;
            else
                frequency = [];
            end
             if ~isempty(trainParameters.numberOfPulses)
                numberOfPulses = trainParameters.numberOfPulses;
            else
                numberOfPulses = [];
             end
             if ~isempty(trainParameters.duration)
                duration = trainParameters.duration;
            else
                duration = [];
            end
                                            
            if (isnumeric(frequency)) || ~(isnumeric(numberOfPulses))|| ~(isnumeric(duration))
                error('frequency, numberOfPulses,and duration Must Be Numbers');
            end
            if (length(frequency) > 1) || (length(numberOfPulses) > 1) || (length(duration) > 1)
                error('Train Parameters Must Be Single Numerics');
            end
            
            if ~(isempty(frequency) || isempty(numberOfPulses)|| isempty(duration))
                error('Too Many Input Train Parameters');
            end
            if (isempty(frequency) && isempty(numberOfPulses)) || (isempty(frequency) && isempty(duration))...
                || (isempty(duration) && isempty(numberOfPulses)) || (isempty(duration) && isempty(numberOfPulses)&& isempty(frequency) )
                error('Not Enough Input Train Parameters');
            end
           
            
           energyPowerTable = [  0.0,   0.0,   0.1,   0.2,   0.4,   0.6,   0.9,   1.2,   1.6,   2.0,...
                                 2.5,   3.0,   3.6,   4.3,   4.9,   5.7,   6.4,   7.3,   8.2,   9.1,...
                                 10.1,  11.1,  12.2,  13.3,  14.5,  15.7,  17.0,  18.4,  19.7,  21.2,...
                                 22.7,  24.2,  25.8,  27.4,  29.1,  30.8,  32.6,  34.5,  36.4,  38.3,...
                                 40.3,  42.3,  44.4,  46.6,  48.8,  51.0,  53.3,  55.6,  58.0,  60.5,...
                                 63.0,  65.5,  68.1,  70.7,  73.4,  76.2,  79.0,  81.8,  84.7,  87.7,...
                                 90.7,  93.7,  96.8, 100.0, 103.2, 106.4, 109.7, 113.0, 116.4, 119.9,...
                                123.4, 126.9, 130.5, 134.2, 137.9, 141.7, 145.5, 149.3, 153.2, 157.2,...
                                161.2, 165.2, 169.3, 173.5, 177.7, 181.9, 186.3, 190.6, 195.0, 199.5,...
                                204.0, 208.5, 213.1, 217.8, 222.5, 227.3, 232.1, 236.9, 241.9, 246.8, 252];
            
           [~, deviceResponse] = self.getParameters;
           ePulse = energyPowerTable(deviceResponse.PowerA + 1); 
            
           if isempty(duration)
               duration = numberOfPulses/frequency;
           elseif isempty(numberOfPulses)  
               numberOfPulses = duration * frequency;
           elseif isempty(frequency)
               frequency = numberOfPulses/duration;
           end                
                            
          
           %Frequency Validity
           if (frequency > 100 || frequency <0)
               error('frequency Out Of Bounds');
           end
           if (frequency > 60 || frequency <0)
               warning('Absolute maximum stimulation frequency is 100.0Hz for 240V systems, and 60Hz for 115V.');
           end
            
           frequencycheck = frequency;
           decimalPlaces = 0; % no of places after decimal initialized to 0.
           temp = floor(frequencycheck);
           diff = frequencycheck - temp;
           while(diff > 0)
                decimalPlaces = decimalPlaces + 1;
                frequencycheck = frequencycheck * 10;
                temp = floor(frequencycheck);
                diff = frequencycheck - temp;
            end
                
            if decimalPlaces > 1
               error('frequency Can Have Up To Just A Single Decimal Place');
            end
           
            if ((frequency / 10) > (1050 / ePulse))
               error('Frequency Out Of Bounds');
            end

                
            %Duration Validity
             if self.version{1} >= 9
                 if ~(duration>=0 && duration<=100) 
                     error('duration Out Of Bounds');
                 end
             else
                 if ~(duration>=0 && duration<=10)
                     error('duration Out Of Bounds');
                 end
             end
                           
             durationcheck = duration;
             decimalPlaces = 0; % no of places after decimal initialized to 0.
             temp = floor(durationcheck);
             diff = durationcheck - temp;
             while(diff > 0)
                decimalPlaces = decimalPlaces + 1;
                durationcheck = durationcheck * 10;
                temp = floor(durationcheck);
                diff = durationcheck - temp;
             end
                
             if decimalPlaces > 1
                error('duration Can Have Up To Just A Single Decimal Place');
             end
             if duration > (63000 / (ePulse * frequency))
                error('Duration Out Of Bounds');
             end
             
                                    
             %numberOfPulses Validity
              if  rem(numberOfPulses,1)~=0
                  error('numberOfPulses Must Be A Whole Number');
              end
                
              if self.version{1} >= 9
                  if ~(numberOfPulses>=1 && numberOfPulses<=6000)
                      error('numberOfPulses Out Of Bounds');
                  end
              else
                  if ~(numberOfPulses>=1 && numberOfPulses<=1000)
                      error('numberOfPulses Out Of Bounds');
                  end
              end 
              if numberOfPulses >(1050 * deviceResponse.WaitTime * frequency) / ((frequency * ePulse) - 1050)                            
                  error('Number Of Pulses Out Of Bounds');
              end                
                                                                                                             
              %% Create Control Command
                                                             
               %1. Frequency
               self.processCommand(['B' sprintf('%04s',num2str(frequency))], getResponse, 4);
                             
               %2. Duration
               if self.version{1} >= 9
                     padding = '%04s';
               else
                     padding = '%03s';
               end
              self.processCommand(['[' sprintf(padding,num2str(duration))], getResponse, 4);
               
               %3. Number Of Pulses
               if self.version{1} >= 9
                    padding = '%05s';
                else
                    padding = '%04s';
                end
              [errorOrSuccess, deviceResponse] = self.processCommand(['D' sprintf(padding,num2str(numberOfPulses))], getResponse, 4);
                                              
        end
        
        
        function [errorOrSuccess, deviceResponse] = enhancedPowerMode(self, enable, varargin)
            % Inputs:
            % enable<boolean> is a boolean that can be True(1) to
            % enable and False(0) to disable the enhanced power mode
            % varargin<bool> refers to getResponse<bool> that can be True (1) or False (0)
            % indicating whether a response from device is required or not.
            % The default value is set to false.
            
            % Outputs:
            % deviceResponse: is the response that is sent back by the
            % device to the port indicating current information about the device
            % errorOrSuccess: is a boolean value indicating succecc = 0 or error = 1
            % in performing the desired task
            
            %% Check Input Validity:
            if nargin < 2
            	error('Not Enough Input Arguments');
            end
            if length(varargin) > 1
                error('Too Many Input Arguments');
            end
            if nargin < 3
                getResponse = false; %Default Value Set To 0
            else
                getResponse = varargin{1};
            end
            if (getResponse ~= 0 && getResponse ~= 1)
            	error('getResponse Must Be A Boolean');
            end
            if (enable ~= 0 && enable ~= 1)
            	error('enable Must Be A Boolean');
            end
           
            %% Create Control Command 
            if enable %Enable
                commandString = '^@';
            else %Disable
                commandString = '_@';
            end
               
            [errorOrSuccess, deviceResponse] =  self.processCommand(commandString, getResponse, 4);
        end
          
        function [errorOrSuccess, deviceResponse] = ignoreCoilSafetyInterlock(self, varargin)
            % Inputs:
            % varargin<bool> refers to getResponse<bool> that can be True (1) or False (0)
            % indicating whether a response from device is required or not.
            % The default value is set to false.
            
            % Outputs:
            % deviceResponse: is the response that is sent back by the
            % device to the port indicating current information about the device
            % errorOrSuccess: is a boolean value indicating succecc = 0 or error = 1
            % in performing the desired task
            
            %% Check Input Validity:
            if nargin < 1
            	error('Not Enough Input Arguments');
            end
            if length(varargin) > 1
                error('Too Many Input Arguments');
            end
            if nargin < 2
                getResponse = false ; %Default Value Set To 0
            else
                getResponse = varargin{1};
            end
            if (getResponse ~= 0 && getResponse ~= 1)
            	error('getResponse Must Be A Boolean');
            end
           
            %% Create Control Command 
            [errorOrSuccess, deviceResponse] =  self.processCommand('b@', getResponse, 3);
        end
          
        
        function [errorOrSuccess, deviceResponse] = rTMSMode(self, enable, varargin)
            % Inputs:
            % enable<boolean> is a boolean that can be True(1) to
            % enable and False(0) to disable the switching between single-pulse and repetitive mode
            % varargin<bool> refers to getResponse<bool> that can be True (1) or False (0)
            % indicating whether a response from device is required or not.
            % The default value is set to false.
            
            % Outputs:
            % DeviceResponse: is the response that is sent back by the
            % device to the port indicating current information about the device
            % errorOrsuccess: is a boolean value indicating succecc = 0 or error = 1
            % in performing the desired task
            
            %% Check Input Validity:
            if nargin < 2
                error('Not Enough Input Arguments');
            end
            if length(varargin) > 1
                error('Too Many Input Arguments');
            end
            if nargin < 3
                getResponse = false ; %Default Value Set To 0
            else
                getResponse = varargin{1};
            end
            if (getResponse ~= 0 && getResponse ~= 1)
            	error('getResponse Must Be A Boolean');
            end
            if (enable ~= 0 && enable ~= 1 )
            	error('enable Must Be A Boolean');
            end
            
            %% Create Control Command
            if self.version{1} >= 9
                padding = '%04s';
            else
                padding = '%03s';
            end
            if enable
                [errorOrSuccess, deviceResponse] = self.processCommand(['[' sprintf(padding,'10')], getResponse, 4);
            else
                [errorOrSuccess, deviceResponse] = self.processCommand(['[' sprintf(padding,'00')], getResponse, 4);
            end
            
        end
       
        function [errorOrSuccess, deviceResponse] = getParameters(self)  
            % Outputs:
            % deviceResponse: is the response that is sent back by the
            % device to the port indicating current information about the device
            % errorOrSuccess: is a boolean value indicating succecc = 0 or error = 1
            % in performing the desired task
            
            %% Check Input Validity
            if nargin < 1
            	error('Not Enough Input Arguments');
            end
          
            %% Create Control Command 
            if self.version{1} >= 9
                returnBytes = 24;
            elseif self.version{1} >= 7
                returnBytes = 22;
            else
                returnBytes = 21;
            end
            [errorOrSuccess, deviceResponse] =  self.processCommand('\@', true, returnBytes);
        end
           
        %% Get Version
        function [errorOrSuccess, deviceResponse] = getDeviceVersion(self)
        %% Create Control Command
            if isempty(self.version)
                [errorOrSuccess, deviceResponse] = self.processCommand('ND', true);
            else
                errorOrSuccess = 0;
                deviceResponse = self.version;
            end
        end
        
        function [errorOrSuccess, deviceResponse] = remoteControl(self, enable, varargin)
            % Inputs:
            % enable<boolean> is a boolean that can be True(1) to
            % enable and False(0) to disable the device
            % varargin<bool> refers to getResponse<bool> that can be True (1) or False (0)
            % indicating whether a response from device is required or not.
            % The default value is set to false.
            
            % Outputs:
            % deviceResponse: is the response that is sent back by the
            % device to the port indicating current information about the device
            % errorOrSuccess: is a boolean value indicating succecc = 0 or error = 1
            % in performing the desired task
            
            %% Check Input Validity
            if nargin < 2
            	error('Not Enough Input Arguments');
            end
            if length(varargin) > 1
            	error('Too Many Input Arguments');
            end
            if nargin < 3
            	getResponse = false;
            else
            	getResponse = varargin{1};
            end
            if (enable ~= 0 && enable ~= 1 )
                error('enable Must Be A Boolean');
            end
            if (getResponse ~= 0 && getResponse ~= 1 )
                error('getResponse Must Be A Boolean');
            end
           
            %% Create Control Command
            if enable %Enable
                if ~isempty(self.unlockCode)
                    commandString = ['Q' self.unlockCode];
                else
                    commandString = 'Q@';
                end
            else %Disable
                commandString = 'R@';
                % Attempt to disarm the stimulator
                self.disarm();
            end
            
            % Keep a record of if we're connecting for the first time
            alreadyConnected = self.connected;
            [errorOrSuccess, deviceResponse] =  self.processCommand(commandString, getResponse, 3);
            if ~errorOrSuccess
                self.connected = enable;
                if enable
                    % If we're not already connected, that means we're
                    % tring to connect for the first time. So check for
                    % what software version the magstim has installed.
                    if ~alreadyConnected
                        [errorCode, magstimVersion] = self.getDeviceVersion();
                        if errorCode
                            errorOrSuccess = errorCode;
                            deviceResponse = magstimVersion;
                            return
                        else
                            self.version = magstimVersion;
                        end
                    end
                    if self.version{1} >= 9
                        self.controlBytes = 6;
                        self.controlCommand = 'x@G';
                    else
                        self.controlBytes = 3;
                        self.controlCommand = 'Q@n';
                    end
                    self.enableCommunicationTimer()
                else
                    self.disableCommunicationTimer()
                end
            end
        end
        
        %% Get System Status
        function [errorOrSuccess, deviceResponse] = getSystemStatus(self)
            if nargin < 1
            	error('Not Enough Input Arguments');
            elseif nargin > 1
                error('Too Many Input Arguments');
            end
            %% Create Control Command
            if self.version{1} >= 9
                [errorOrSuccess, deviceResponse] =  self.processCommand('x@', true, 6);
            else
                errorOrSuccess = 7;
                deviceResponse = 'This command is unavailable on your device';
            end
        end        

        %% Get Error Code
        function [errorOrSuccess, deviceResponse] = getErrorCode(self)
            if nargin < 1
            	error('Not Enough Input Arguments');
            elseif nargin > 1
                error('Too Many Input Arguments');
            end
            %% Create Control Command
        	[errorOrSuccess, deviceResponse] = self.processCommand('I@', true, 6);
        end

        %% Set Charge Delay
        function [errorOrSuccess, deviceResponse] = setChargeDelay(self, chargeDelay, varargin)
            % Inputs:         
            % chargeDelay<double> is the desired duration of the charge delay
            % varargin<bool> refers to getResponse<bool> that can be True (1) or False (0)
            % indicating whether a response from device is required or not.
            % The default value is set to false.
            
            % Outputs:
            % deviceResponse: is the response that is sent back by the
            % device to the port indicating current information about the device
            % errorOrSuccess: is a boolean value indicating success = 0 or error = 1
            % in performing the desired task
            %% Check Input Validity:
            if nargin < 2
            	error('Not Enough Input Arguments');
            end
            if length(varargin) > 1
                error('Too Many Input Arguments');
            end
            if nargin < 3
                getResponse = false ; %Default Value Set To 0
            else
                getResponse = varargin{1};
            end
            if (getResponse ~= 0 && getResponse ~= 1)
            	error('getResponse Must Be A Boolean');
            end
            if ~(isnumeric(chargeDelay)) || rem(chargeDelay,1)~=0
                error('The chargeDelay Must Be A Number');
            end
            if (chargeDelay < 0)
                error('chargeDelay Must Be A Positive Value');
            end
            if length(chargeDelay) > 1
                error('Invaid chargeDelay. It Must Be A Single Numeric');
            end            
            %% Create Control Command
            if self.version{1} >= 9
                if self.version{1} >= 10
                    %if chargeDelay > 10000
                    %    error('Maximum chargeDelay is 10000 ms.');
                    %end
                    padding = '%05s';
                else
                    %if chargeDelay > 2000
                    %    error('Maximum chargeDelay is 2000 ms.');
                    %end
                    padding = '%04s';
                end
                [errorOrSuccess, deviceResponse] = self.processCommand(['n' sprintf(padding,num2str(chargeDelay))], getResponse, 3);
            else
                errorOrSuccess = 7;
                deviceResponse = 'This command is unavailable on your device';
            end
        end 
        
        %% Get Charge Delay
        function [errorOrSuccess, deviceResponse] = getChargeDelay(self)
            if nargin < 1
            	error('Not Enough Input Arguments');
            elseif nargin > 1
                error('Too Many Input Arguments');
            end            
            %% Create Control Command
            if self.version{1} >= 9
                if self.version{1} >= 10
                    returnBytes = 7;
                else
                    returnBytes = 6;
                end
                [errorOrSuccess, deviceResponse] =  self.processCommand('o@', true, returnBytes);
            else
                errorOrSuccess = 7;
                deviceResponse = 'This command is unavailable on your device';
            end
        end        
    end
    
    methods (Access = 'protected')
        function maintainCommunication(self)
        	fprintf(self.port, self.controlCommand);    
            fread(self.port, self.controlBytes);
        end
    end
    
    methods (Access = 'protected')
        %%
        function info = parseResponse(self, command, readData)
            %% Asking For Version?
            if command == 'N'
                % Get valid parts of returned numbers
                info = cellfun(@(x) str2double(x), regexp(readData,'\d*','Match'),'UniformOutput',false);
            else
                %% Getting Instrument Status (always returned unless asking for version)
                statusCode = bitget(double(readData(1)),1:8);
                info = struct('InstrumentStatus',struct('Standby',             statusCode(1),...
                                                        'Armed',               statusCode(2),...
                                                        'Ready',               statusCode(3),...
                                                        'CoilPresent',         statusCode(4),...
                                                        'ReplaceCoil',         statusCode(5),...
                                                        'ErrorPresent',        statusCode(6),...
                                                        'ErrorType',           statusCode(7),...
                                                        'RemoteControlStatus', statusCode(8)));
                %% Is Rapid Status Returned With This Command?
                if ismember(command,['\', '[', 'D', 'B', '^', '_', 'x'])
                    statusCode = bitget(double(readData(2)),1:8);
                    info.RapidStatus = struct('EnhancedPowerMode',     statusCode(1),...
                                              'Train',                 statusCode(2),...
                                              'Wait',                  statusCode(3),...
                                              'SinglePulseMode',       statusCode(4),...
                                              'HVPSUConnected',        statusCode(5),...
                                              'CoilReady',             statusCode(6),...
                                              'ThetaPSUDetected',      statusCode(7),...
                                              'ModifiedCoilAlgorithm', statusCode(8));
                end
                %% Get Remaining Information
                %Get commands
                if command == '\' %getParameters
                    info.PowerA = str2double(char(readData(3:5)));
                    info.Frequency = str2double(char(readData(6:9))) / 10;
                    if self.version{1} >= 9
                        info.NPulses = str2double(char(readData(10:14)));
                        info.Duration = str2double(char(readData(15:18))) / 10;
                        info.WaitTime = str2double(char(readData(19:22))) / 10;
                    elseif self.version{1} >= 7
                        info.NPulses = str2double(char(readData(10:13)));
                        info.Duration = str2double(char(readData(14:16))) / 10;
                        info.WaitTime = str2double(char(readData(17:20))) / 10;
                    else
                        info.NPulses = str2double(char(readData(10:13)));
                        info.Duration = str2double(char(readData(14:16))) / 10;
                        info.WaitTime = str2double(char(readData(17:19))) / 10;
                    end
                elseif command == 'F'  %getTemperature
                    info.CoilTemp1 = str2double(char(readData(2:4))) / 10;
                    info.CoilTemp2 = str2double(char(readData(5:7))) / 10;
                elseif command == 'I'  %getErrorCode
                    info.ErrorCode = char(readData(2:4));
                elseif command == 'x'  %getSystemStatus
                    statusCode = bitget(double(readData(4)),1:8);
                    info.SystemStatus = struct('Plus1ModuleDetected',      statusCode(1),...
                                               'SpecialTriggerModeActive', statusCode(2),...
                                               'ChargeDelaySet',           statusCode(3));
                elseif command == '0'  %getChargeDelay
                    if self.version{1} >= 10
                        info.ChargeDelay = str2double(char(readData(2:5)));
                    else
                        info.ChargeDelay = str2double(char(readData(2:4)));
                    end
                end
            end
        end
    end
    
end
