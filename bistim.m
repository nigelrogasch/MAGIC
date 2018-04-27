classdef bistim < magstim &handle
    properties (SetAccess = private)
        highRes = 0; %Bistim High Resolution Time Setting Mode
    end
    
    methods
        function self = bistim(PortID)
            self = self@magstim(PortID);
        end
    end
    
    methods
        
        function [errorOrSuccess, deviceResponse] = setAmplitudeB(self, power, varargin)
            % Inputs:
            % power<double> : is the desired power amplitude for stimulator B 
            % varargin<bool> refers to getResponse<bool> that can be True (1) or False (0)
            % indicating whether a response from device is required or not.
            % The default value is set to false.
            
            % Outputs:
            % deviceResponse: is the response that is sent back by the
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
            if (getResponse ~= 0 && getResponse ~= 1 )
                error('getResponse Must Be A Boolean');
            end
         
            if rem(power,1)~=0
                error('power Must Be A Number');
            end
            if (power < 0 || power > 100)
                error('power Must Be A Positive Value Less Than Or Equal To 100');
            end
                        
            if length(power) > 1
                error('Invaid Power Amplitude. It Must be A Single Numeric');
            end
            
            %% Create Control Command

            [errorOrSuccess, deviceResponse] = self.processCommand(['A' sprintf('%03s',num2str(power))], getResponse, 3);

        end
        
        function [errorOrSuccess, deviceResponse] = setPulseInterval(self, ipi,checkWarning, varargin)
            % Inputs:
            % ipi<double> : is the desired interpulse interval 
            % checkWarning<bool> : is a boolean determining whether to
            % check for potential warnings in the ipi boundries 
            % varargin<bool>: refers to getResponse<bool> that can be True (1) or False (0)
            % indicating whether a response from device is required or not.
            % The default value is set to false.
            
            % Outputs:
            % deviceResponse: is the response that is sent back by the
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
            if nargin < 4
                getResponse = false ; %Default Value Set To 0
            else
                getResponse = varargin{1};
            end
            if (getResponse ~= 0 && getResponse ~= 1 )
                error('getResponse Must Be A Boolean');
            end
         
            if ~(isnumeric(ipi))
                error('ipi Must Be A Number');
            end
            
            if self.highRes == 1 % Device already set to highRes Mode
                if rem(ipi,0.1)~=0
                    error('ipi Can Have Up To Just A Single Decimal Place In High Resolution Mode');
                end
            else % Not known whether in highRes mode
                
                ipicheck = ipi;
                decimalPlaces = 0; % no of places after decimal initialized to 0.
                temp = floor(ipicheck);
                diff = ipicheck - temp;
                while(diff > 0)
                decimalPlaces = decimalPlaces + 1;
                ipicheck = ipicheck * 10;
                temp = floor(ipicheck);
                diff = ipicheck - temp;
                end
                
                if decimalPlaces == 1
                    if checkWarning ==1
                    warning('ipi Value Can Be A Fractional Only In High Resolution Mode');
                    end
                elseif decimalPlaces~=0 && decimalPlaces~=1
                    error('ipi Can Have Up To Just A Single Decimal Place In High Resolution Mode');
                end
                
           end
            
            %% Create Control Command

            [errorOrSuccess, deviceResponse] = self.processCommand(['C' sprintf('%03s',num2str(ipi))], getResponse, 3);


                        
        end
        
        function [errorOrsuccess, deviceResponse] = highResolutionMode(self, enable, varargin)
            % Inputs:
            % enable<boolean> is a boolean that can be True(1) to
            % enable and False(0) to disable the High Resolution Time Setting Mode
            % varargin<bool> refers to getResponse<bool> that can be True (1) or False (0)
            % indicating whether a response from device is required or not.
            % The default value is set to false.
            
            % Outputs:
            % DeviceResponse: is the response that is sent back by the
            % device to the port indicating current information about the device
            % errorOrsuccess: is a boolean value indicating succecc = 0 or error = 1
            % in performing the desired task
            
            %% Check Input Validity
            if nargin < 2
                error('Not Enough Input Arguments');
            end
            if length(varargin) > 1
                error('Too Many Input Arguments');
            end
            if nargin < 3
                getResponse = false ;
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
                commandString = 'Y@';
            else %Disable
                commandString = 'Z@';                               
            end
            [errorOrsuccess, deviceResponse] =  self.processCommand(commandString, getResponse, 3);
        end

        
        function [errorOrSuccess, deviceResponse] = getParameters(self)  
            % Outputs:
            % DeviceResponse: is the response that is sent back by the
            % device to the port indicating current information about the device
            % errorOrsuccess: is a boolean value indicating succecc = 0 or error = 1
            % in performing the desired task

            %% Check Input Validity
            if nargin < 1
                error('Not Enough Input Arguments');
            end

            %% Create Control Command
            [errorOrSuccess, deviceResponse] =  self.processCommand('J@', true, 12);
            if self.highRes
                deviceResponse.IPI = deviceResponse.IPI / 10;
            end
        end
    end
    
    methods (Access = 'protected')        
        %%
        function info = parseResponse(self, command, readData)
            %% Getting Instrument Status (always returned)
            statusCode = bitget(double(readData(1)),1:8);
            info = struct('InstrumentStatus',struct('Standby',             statusCode(1),...
                                                    'Armed',               statusCode(2),...
                                                    'Ready',               statusCode(3),...
                                                    'CoilPresent',         statusCode(4),...
                                                    'ReplaceCoil',         statusCode(5),...
                                                    'ErrorPresent',        statusCode(6),...
                                                    'ErrorType',           statusCode(7),...
                                                    'RemoteControlStatus', statusCode(8)));
                        
            %% Getting All Information
            %Get commands
            if command == 'J' %getParameters
                info.PowerA = str2double(char(readData(2:4)));
                info.PowerB = str2double(char(readData(5:7)));
                info.IPI = str2double(char(readData(8:10)));
            elseif command == 'F'  %getTemperature
                info.CoilTemp1 = str2double(char(readData(2:4))) / 10;
                info.CoilTemp2 = str2double(char(readData(5:7))) / 10;
            end               

        end
    end
end
