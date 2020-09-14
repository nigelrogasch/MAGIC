% This program is free software; you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation; either version 3 of the License, or
% (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.

classdef duomag < handle
    properties (SetAccess = private)
        port
        connected = 0; %Default value of connected set to 0 to make sure the user connects the port
    end
    methods
        function self = duomag(PortID)
            % PortID <char> defines the serail port id on your computer
            
            %% Find All Available etISerial Ports On Your Computer
            try
                FoundPorts = instrhwinfo('serial');
                ListOfComPorts = FoundPorts.AvailableSerialPorts;
            catch
                ListOfComPorts=PortID;
            end
            
            %% Check Input Validity:
            if nargin <1
                error('Not Enough Input Arguments');
            end
            if ~(ischar(PortID))
                error('The Serial Port ID Must Be a Character Array');
            end
            if ~any(strcmp(ListOfComPorts,PortID))
                error('Invalid Serial Com Port ID');
            end
            
            %% Identifing The Port
            P = serial(PortID);
            P.BaudRate = 1000000;
            %P.DataBits = 8;
            %P.Parity = 'none';
            P.StopBits = 2.0;
            %P.InputBufferSize = 19;
            %P.OutputBufferSize = 512;
            
            self.port = P;
            
        end
    end
    methods
        %% Opening The Desired Port
        function [errorOrSuccess, deviceResponse] = connect(self)
            %% Check Input Validity
            if nargin <1
                error('Not Enough Input Arguments');
            end
            
            %% Open The Port
            fopen(self.port);
            if ~(strcmp (self.port.Status,'closed'))
                self.connected = 1;
                errorOrSuccess = ~ self.connected;
                deviceResponse = [];
            end
            
        end
        %% Closing The Desired Port
        function [errorOrSuccess, deviceResponse] = disconnect(self)
            %% Check Input Validity
            if nargin <1
                error('Not Enough Input Arguments');
            end
            
            %% Close The Port
            fclose(self.port);
            if (strcmp (self.port.Status,'closed'))
                self.connected = 0;
                errorOrSuccess = self.connected;
                deviceResponse = [];
            end
            
        end
    end
    methods
        %% 1.Getting Status From Device
        function [errorOrSuccess, deviceResponse] = getStatus(self)
            % Outputs:
            % deviceResponse: is the response that is sent back by the
            % device to the port indicating current information about the device
            % errorOrSuccess: is a boolean value indicating succecc = 0 or error = 1
            % in performing the desired task
            %% Reconnect the stimulator
            try
                self.disconnect();
                self.connect();
                warning('In case of any problems, try reconnecting the device manually');
                %% Create Control Command
                % Read in data stream.
                nchar = 32; % bytes to read
                iRaw = fread(self.port, nchar, 'uint8');
                
                % Convert to binary to allow us to read inidivudal bits.
                iBin = dec2bin(iRaw);
                
                % Find index for sync bytes (i.e 255).
                getSync = find(iRaw == 255);
                
                % Read input between the most recent sync indexes.
                iBin = iBin(getSync(end-1)+1:getSync(end)-1, :);
                
                % Calculate change intensity.
                changeIntensity                  = iBin( 1, 4:8 ); % get the binary code as character array
                changeIntensity                  = sbin2dec(changeIntensity); % use sbin2dec to convert to signed integer
                
                % Write data to struct.
                DuoSTATUS.demandOnStimTTL          = str2double(iBin( 1,   3 ));
                DuoSTATUS.changeIntensity          = changeIntensity;
                DuoSTATUS.currentIntentity         = bin2dec(iBin( 2,   : ));
                DuoSTATUS.coilTemperatureADC       = bin2dec(iBin( 3,   : ));     % ADC output; units not specified
                DuoSTATUS.resistorTemperatureADC   = bin2dec(iBin( 4,   : ));     % ADC output; units not specified
                DuoSTATUS.dischargeTemperatureADC  = bin2dec(iBin( 5,   : ));     % ADC output; units not specified
                DuoSTATUS.omittedPulseCount        = bin2dec(iBin( 6,   : ));
                
                DuoSTATUS.isPowerOverheat          = str2double(iBin( 7,   2 ));  % 0 = false, 1 = true (all below)
                DuoSTATUS.isCoilDisconnected       = str2double(iBin( 7,   3 ));
                DuoSTATUS.isVoltageHoldError       = str2double(iBin( 7,   4 ));
                DuoSTATUS.isVoltageRechargeError   = str2double(iBin( 7,   5 ));
                DuoSTATUS.isPowerFanSeized         = str2double(iBin( 8,   2 ));
                DuoSTATUS.isCoilOverheat           = str2double(iBin( 8,   4 ));
                DuoSTATUS.isResistorOverheat       = str2double(iBin( 8,   5 ));
                DuoSTATUS.isDischargeOverheat      = str2double(iBin( 8,   6 ));
                DuoSTATUS.isCoilDataOK             = str2double(iBin( 8,   7 ));
                DuoSTATUS.isReceivingUSB           = str2double(iBin( 8,   8 ));
                DuoSTATUS.isIdleTime               = str2double(iBin( 9,   6 ));
                DuoSTATUS.isCharged                = str2double(iBin( 9,   8 ));
                
                % Exponent codes (from Deymed manual).
                exp = ['000';  ... % #0 (x 00.05 ms)
                    '001';  ... % #1 (x 00.10 ms)
                    '010';  ... % #2 (x 00.20 ms)
                    '011';  ... % #3 (x 00.50 ms)
                    '100';  ... % #4 (x 01.00 ms)
                    '101';  ... % #5 (x 02.00 ms)
                    '110';  ... % #6 (x 05.00 ms)
                    '111'];     % #7 (x 10.00 ms)
                
                % Exponent values (from Deymed manual).
                vals = [00.05, ... % in ms
                    00.10, ...
                    00.20, ...
                    00.50, ...
                    01.00, ...
                    02.00, ...
                    05.00, ...
                    10.00];
                
                % Match exponent with equivalent value for recharge delay.
                rechargeExp    = sum(exp == repmat(iBin(12, 2:4), [8, 1, 1]), 2) == 3;
                rechargeExpVal = vals(rechargeExp);
                
                % Match exponent with equivalent value for ISI delay.
                TTLExp    = sum(exp == repmat(iBin(12, 6:8), [8, 1, 1]), 2) == 3;
                TTLExpVal = vals(TTLExp);
                
                % Calculate recharge and ISI delays in ms.
                DuoSTATUS.delayTTL      = bin2dec(iBin(10,   2:8)) * TTLExpVal;
                DuoSTATUS.delayRecharge = bin2dec(iBin(11,   2:8)) * rechargeExpVal;
                
                % Add coil ID if newer Deymed model.
                if size(iBin, 1) > 13
                    DuoSTATUS.typeCoil  = bin2dec(num2str(iBin(15,  : )));
                    
                    % Swap in coil identity if known.
                    % Coil type is saved as an integer, which corresponds to one of the coils
                    % below. Array is ordered as in Deymed manual.
                    
                    % Known coil types.
                    coilsKnown = {'70BF', '70BF-COOL', '120BFV', '100R', '125R', '50BF', '50BFT'};
                    
                    % Check the coil number corresponds to one of the coils above.
                    if DuoSTATUS.typeCoil > 0 && DuoSTATUS.typeCoil <= size(coilsKnown, 2)
                        DuoSTATUS.typeCoil = coilsKnown{DuoSTATUS.typeCoil};
                    end
                end
                
                % To read change in intensity parameter, which is in two's complement (i.e
                % signed binary).
                
                deviceResponse=DuoSTATUS;
                errorOrSuccess=1;
            catch
                deviceResponse=[];
                errorOrSuccess=0;
                warning('The process of getting status from device was unsuccessful, try reconnecting the device manually');
            end
            function [y] = sbin2dec(x)
                if(x(1)=='0')
                    y = bin2dec(x(2:end));
                else
                    y = bin2dec(x(2:end)) - 2 ^ (length(x) - 1);
                end
            end
        end
        %% 2.Setting The Amplitude In Standard Or Twin/Dual Modes
        function [errorOrSuccess, deviceResponse] = setAmplitude(self,desiredAmplitudes,varargin)
            % Inputs:
            % DesiredAmplitudes<double> must be a vector of length 1 indicating A amplitude in
            % percentage ; Or of length 2 in Dual/Twin Mode indicating A &
            % B amplitudes in percentage respectively
            % varargin<bool> refers to getResponse<bool> that can be True (1) or False (0)
            % indicating whether a response from device is required or not.
            % The default value is set to false.
            
            % Outputs:
            % deviceResponse: is the response that is sent back by the
            % device to the port indicating current information about the device
            % errorOrSuccess: is a boolean value indicating succecc = 0 or error = 1
            % in performing the desired task
            
            %% Check Input Validity:
            
            if nargin <2
                error('Not Enough Input Arguments');
            end
            if length(varargin)>1
                error('Too Many Input Arguments');
            end
            if nargin <3
                getResponse = false ; %Default value Set To 0
            else
                getResponse = varargin{1};
            end
            
            if (getResponse ~= 0 && getResponse ~= 1 )
                error('getResponse Must Be A Boolean');
            end
            %% Reconnect the stimulator
            if getResponse ==1
                self.disconnect();
                self.connect();
                warning('In case of any problems, try reconnecting the device manually');
            end
            %%
            if (length(desiredAmplitudes)==1)
                A_Amp = desiredAmplitudes;
                if ~isnumeric(A_Amp) || rem(A_Amp,1)~=0 || A_Amp<0 || A_Amp>100
                    error('Amplitudes Must Be A Whole Numeric Percent value Between 0 and 100');
                end
            end
            %% Create Control Command
            try
                fwrite(self.port, [desiredAmplitudes desiredAmplitudes], 'uint8');
                errorOrSuccess=1; deviceResponse=[];
                if getResponse~=0, [~, deviceResponse]=self.getStatus; end
            catch
                errorOrSuccess=0; deviceResponse=[];
                warning('The process was unsuccessful, try reconnecting the device manually');
            end
        end
        %% 3.Sending A Single Trig To The Specified Port
        function [errorOrSuccess, deviceResponse] = fire(self,varargin)
            % Inputs:
            % varargin<bool> refers to getResponse<bool> that can be True (1) or False (0)
            % indicating whether a response from device is required or not.
            % The default value is set to false.
            
            % Outputs:
            % deviceResponse: is the response that is sent back by the
            % device to the port indicating current information about the device
            % errorOrSuccess: is a boolean value indicating succecc = 0 or error = 1
            % in performing the desired task
            
            %% Check Input Validity
            if nargin <1
                error('Not Enough Input Arguments');
            end
            if length(varargin)>1
                error('Too Many Input Arguments');
            end
            if nargin <2
                getResponse = false ; %Default value Set To 0
            else
                getResponse = varargin{1};
            end
            if (getResponse ~= 0 && getResponse ~= 1 )
                error('getResponse Must Be A Boolean');
            end
            
            %% Reconnect the stimulator
            if getResponse ==1
                self.disconnect();
                self.connect();
                warning('In case of any problems, try reconnecting the device manually');
            end
            
            %% Create Control Command
            try
                fwrite(self.port, [121 121], 'uint8');
                errorOrSuccess=1; deviceResponse=[];
                if getResponse~=0, [~, deviceResponse]=self.getStatus; end
            catch
                errorOrSuccess=0; deviceResponse=[];
                warning('The process was unsuccessful, try reconnecting the device manually');
            end
            
        end
        %% 4.Setting Charge delay Parameters
        function [errorOrSuccess, deviceResponse] = set_ChargeDelay(self,chargeDelay,varargin)
            % Inputs:
            % chargeDelay <int>: defines the time in milliseconds to make the device wait, before
            % recharging.
            % varargin<bool>: refers to getResponse<bool> that can be True (1) or False (0)
            % indicating whether a response from device is required or not.
            % The default value is set to false.
            
            % Outputs:
            % deviceResponse: is the response that is sent back by the
            % device to the port indicating current information about the device
            % errorOrSuccess: is a boolean value indicating succecc = 0 or error = 1
            % in performing the desired task
            
            
            
            %% Check Input Validity:
            if nargin <1
                error('Not Enough Input Arguments');
            end
            if length(varargin)>1
                error('Too Many Input Arguments');
            end
            if nargin <3
                getResponse = false ; %Default value Set To 0
            else
                getResponse = varargin{1};
            end
            if (getResponse ~= 0 && getResponse ~= 1 )
                error('getResponse Must Be A Boolean');
            end
            
            %% Reconnect the stimulator
            if getResponse ==1
                self.disconnect();
                self.connect();
                warning('In case of any problems, try reconnecting the device manually');
            end
            if (chargeDelay>600) || (chargeDelay<0.05)
                error('chargeDelay Out Of Bounds');
            end
            
            %% Create Control Command
            %duoRecharge  Set the recharge delay for the device
            % duoRecharge(self.port, steps, stepSize) sets the recharge delay in
            % milliseconds as defined by inputs STEPS and STEPSIZE. Input STEPS must be
            % a scalar value between 0-127. STEPSIZE is a value in ms which
            % is used to mutliply STEPS to the desired delay value.
            %
            % Example:
            %    tmsTTLDelay(DuoMAG, 60, 2) % i.e. (60 * 2) ms
            %
            % Sets the recharge delay to 120 ms
            %
            % Below are all supported STEPSIZE values:
            %
            %    00.05
            %    00.10
            %    00.20
            %    00.50
            %    01.00
            %    02.00
            %    05.00
            %    10.00
            
            vals = [0.05, 0.10, 0.20, 00.50, 01.00, 02.00, 05.00,10.00];
            
            if round(chargeDelay/vals(8))==single(chargeDelay/vals(8)), var1=ceil(chargeDelay/vals(8));
            else, var1=floor(chargeDelay/vals(8)); end
            var1rem=rem(chargeDelay,vals(8));
            
            if round(var1rem/vals(7))==single(var1rem/vals(7)), var2=ceil(var1rem/vals(7));
            else, var2=floor(var1rem/vals(7));end
            var2rem=rem(var1rem,vals(7));
            
            if round(var2rem/vals(6))==single(var2rem/vals(6)), var3=ceil(var2rem/vals(6));
            else,var3=floor(var2rem/vals(6)); end
            var3rem=rem(var2rem,vals(6));
            
            if round(var3rem/vals(5))==single(var3rem/vals(5)),var4=ceil(var3rem/vals(5));
            else, var4=floor(var3rem/vals(5)); end
            var4rem=rem(var3rem,vals(5));
            
            if round(var4rem/vals(4))==single(var4rem/vals(4)), var5=ceil((var4rem/vals(4)));
            else, var5=floor((var4rem/vals(4))); end
            var5rem=rem(var4rem,vals(4));
            
            if round(var5rem/vals(3))==single(var5rem/vals(3)), var6=ceil(var5rem/vals(3));
            else, var6=floor(var5rem/vals(3));end
            var6rem=rem(var5rem,vals(3));
            
            if round(var6rem/vals(2))==single(var6rem/vals(2)), var7=ceil(var6rem/vals(2));
            else, var7=floor(var6rem/vals(2)); end
            var7rem=rem(var6rem,vals(2));
            
            if round(var7rem/vals(1))==single(var7rem/vals(1)), var8=ceil(var7rem/vals(1));
            else, var8=floor(var7rem/vals(1)); end
            var8rem=rem(var7rem,vals(1));
            
            breakpoint=0;
            for i=1:8
                varname=['var' num2str(i)];
                if eval(varname)~=0
                    switch i
                        case 1
                            stepSize=10;
                            if var1*10==chargeDelay, breakpoint=1; end
                        case 2
                            stepSize=5;
                            if var1*10 + var2*5==chargeDelay, breakpoint=1; end
                        case 3
                            stepSize=2;
                            if var1*10 + var2*5 + var3*2==chargeDelay, breakpoint=1; end
                        case 4
                            stepSize=1;
                            if var1*10 + var2*5 + var3*2 +var4*1==chargeDelay, breakpoint=1; end
                        case 5
                            stepSize=0.5;
                            if var1*10 + var2*5 + var3*2 +var4*1 + var5*0.5==chargeDelay, breakpoint=1; end
                        case 6
                            stepSize=0.2;
                            if var1*10 + var2*5 + var3*2 +var4*1 +var5*0.5+var6*0.2==chargeDelay, breakpoint=1; end
                        case 7
                            stepSize=0.1;
                            if var1*10 + var2*5 + var3*2 +var4*1 +var5*0.5+var6*0.2+var7*0.1==chargeDelay, breakpoint=1; end
                        case 8
                            stepSize=0.05;
                            if var1*10 + var2*5 + var3*2 +var4*1 +var5*0.5+var6*0.2+var7*0.1+var8*0.05==chargeDelay, breakpoint=1; end
                    end
                    setRecursiveChargeDelay(stepSize,eval(varname));
                    if breakpoint==1, break; end
                end
            end

            if var8rem~=0;   warning('Minimum resolution of recharge delay is 0.05 ms, therefore required charge delay could be set apprixmately'); end
            try
                errorOrSuccess=1; deviceResponse=[];
                if getResponse~=0, [~, deviceResponse]=self.getStatus; end
            catch
                errorOrSuccess=0; deviceResponse=[]; warning('The process was unsuccessful, try reconnecting the device manually');
            end
            function setRecursiveChargeDelay(stepSize,steps)
                exp = ['000';  '001';  '010'; '011'; '100'; '101';'110'; '111'];
                
                % Exponent values (from Deymed manual).
                vals = [00.05, 00.10, 00.20, 00.50, 01.00, 02.00, 05.00,10.00];
                
                % Get the corresponding binary code.
                rechargeExpVal = vals == stepSize;
                rechargeExp = exp(rechargeExpVal, :);
                
                % Convert fraction value to binary.
                frc = dec2bin(steps, 7); % for 7-bit array
                
                % Add the fraction value to upper/lower bits.
                upper = bin2dec(['100', frc(1:5)]); % upper bits take bits 1-5
                
                % Add the exp value to the lower bits.
                lower = bin2dec(['101', rechargeExp, frc(6:7)]); % lower bits take bits 6-7
                fwrite(self.port, [upper upper lower lower], 'uint8'); % set bits
            end
        end
        %% 5.Setting Trig Out Delay Parameters
        function [errorOrSuccess, deviceResponse] = set_TriggerOutDelay(self,triggerOutDelay,varargin)
            % Inputs:
            % trigInDelay <int>: allows setting a delay in milliseconds from the time
            % of arrival of an external trigger input to the time for the magnetic stimulation to be provided.
            % trigOutDelay <signed int>: allows setting a delay in milliseconds from
            % the time of the magnetic stimulation to the time of the external trigger to be provided.
            % triggerOutDelay <int>: defines the time in milliseconds to make the device wait, before
            % recharging.
            % varargin<bool>: refers to getResponse<bool> that can be True (1) or False (0)
            % indicating whether a response from device is required or not.
            % The default value is set to false.
            
            % Outputs:
            % deviceResponse: is the response that is sent back by the
            % device to the port indicating current information about the device
            % errorOrSuccess: is a boolean value indicating succecc = 0 or error = 1
            % in performing the desired task
            %% Check Input Validity:
            if nargin <1
                error('Not Enough Input Arguments');
            end
            if length(varargin)>1
                error('Too Many Input Arguments');
            end
            if nargin <3
                getResponse = false ; %Default value Set To 0
            else
                getResponse = varargin{1};
            end
            if (getResponse ~= 0 && getResponse ~= 1 )
                error('getResponse Must Be A Boolean');
            end
            if (triggerOutDelay>600) || (triggerOutDelay<0.05)
                error('chargeDelay Out Of Bounds');
            end
            
            %% Reconnect the stimulator
            if getResponse ==1
                self.disconnect();
                self.connect();
                warning('In case of any problems, try reconnecting the device manually');
            end
            
            %% Create Control Command
            % sets the recharge delay in
            % milliseconds as defined by inputs STEPS and STEPSIZE. Input STEPS must be
            % a scalar value between 0-127. STEPSIZE is a value in ms which
            % is used to mutliply STEPS to the desired delay value.
            %
            % Example:
            %    tmsTTLDelay(DuoMAG, 60, 2) % i.e. (60 * 2) ms
            %
            % Sets the recharge delay to 120 ms
            %
            % Below are all supported STEPSIZE values:
            %
            %    00.05
            %    00.10
            %    00.20
            %    00.50
            %    01.00
            %    02.00
            %    05.00
            %    10.00
            
            vals = [0.05, 0.10, 0.20, 00.50, 01.00, 02.00, 05.00,10.00];
            
            if round(chargeDelay/vals(8))==single(chargeDelay/vals(8)), var1=ceil(chargeDelay/vals(8));
            else, var1=floor(chargeDelay/vals(8)); end
            var1rem=rem(chargeDelay,vals(8));
            
            if round(var1rem/vals(7))==single(var1rem/vals(7)), var2=ceil(var1rem/vals(7));
            else, var2=floor(var1rem/vals(7));end
            var2rem=rem(var1rem,vals(7));
            
            if round(var2rem/vals(6))==single(var2rem/vals(6)), var3=ceil(var2rem/vals(6));
            else,var3=floor(var2rem/vals(6)); end
            var3rem=rem(var2rem,vals(6));
            
            if round(var3rem/vals(5))==single(var3rem/vals(5)),var4=ceil(var3rem/vals(5));
            else, var4=floor(var3rem/vals(5)); end
            var4rem=rem(var3rem,vals(5));
            
            if round(var4rem/vals(4))==single(var4rem/vals(4)), var5=ceil((var4rem/vals(4)));
            else, var5=floor((var4rem/vals(4))); end
            var5rem=rem(var4rem,vals(4));
            
            if round(var5rem/vals(3))==single(var5rem/vals(3)), var6=ceil(var5rem/vals(3));
            else, var6=floor(var5rem/vals(3));end
            var6rem=rem(var5rem,vals(3));
            
            if round(var6rem/vals(2))==single(var6rem/vals(2)), var7=ceil(var6rem/vals(2));
            else, var7=floor(var6rem/vals(2)); end
            var7rem=rem(var6rem,vals(2));
            
            if round(var7rem/vals(1))==single(var7rem/vals(1)), var8=ceil(var7rem/vals(1));
            else, var8=floor(var7rem/vals(1)); end
            var8rem=rem(var7rem,vals(1));
            
            breakpoint=0;
            for i=1:8
                varname=['var' num2str(i)];
                if eval(varname)~=0
                    switch i
                        case 1
                            stepSize=10;
                            if var1*10==chargeDelay, breakpoint=1; end
                        case 2
                            stepSize=5;
                            if var1*10 + var2*5==chargeDelay, breakpoint=1; end
                        case 3
                            stepSize=2;
                            if var1*10 + var2*5 + var3*2==chargeDelay, breakpoint=1; end
                        case 4
                            stepSize=1;
                            if var1*10 + var2*5 + var3*2 +var4*1==chargeDelay, breakpoint=1; end
                        case 5
                            stepSize=0.5;
                            if var1*10 + var2*5 + var3*2 +var4*1 + var5*0.5==chargeDelay, breakpoint=1; end
                        case 6
                            stepSize=0.2;
                            if var1*10 + var2*5 + var3*2 +var4*1 +var5*0.5+var6*0.2==chargeDelay, breakpoint=1; end
                        case 7
                            stepSize=0.1;
                            if var1*10 + var2*5 + var3*2 +var4*1 +var5*0.5+var6*0.2+var7*0.1==chargeDelay, breakpoint=1; end
                        case 8
                            stepSize=0.05;
                            if var1*10 + var2*5 + var3*2 +var4*1 +var5*0.5+var6*0.2+var7*0.1+var8*0.05==chargeDelay, breakpoint=1; end
                    end
                    setRecursiveTriggerOutDelay(stepSize,eval(varname));
                    if breakpoint==1, break; end
                end
            end

            if var8rem~=0;   warning('Minimum resolution of TTL out delay is 0.05 ms, therefore required charge delay could be set apprixmately'); end
            try
                errorOrSuccess=1; deviceResponse=[];
                if getResponse~=0, [~, deviceResponse]=self.getStatus; end
            catch
                errorOrSuccess=0; deviceResponse=[]; warning('The process was unsuccessful, try reconnecting the device manually');
            end
            function setRecursiveTriggerOutDelay(stepSize,steps)
                exp = ['000';  '001';  '010'; '011'; '100'; '101';'110'; '111'];
                
                % Exponent values (from Deymed manual).
                vals = [00.05, 00.10, 00.20, 00.50, 01.00, 02.00, 05.00,10.00];
                
                % Get the corresponding binary code.
                rechargeExpVal = vals == stepSize;
                rechargeExp = exp(rechargeExpVal, :);
                
                % Convert fraction value to binary.
                frc = dec2bin(steps, 7); % for 7-bit array
                
                % Add the fraction value to upper/lower bits.
                upper = bin2dec(['110', frc(1:5)]); % upper bits take bits 1-5
                
                % Add the exp value to the lower bits.
                lower = bin2dec(['111', rechargeExp, frc(6:7)]); % lower bits take bits 6-7
                fwrite(self.port, [upper upper lower lower], 'uint8'); % set bits
            end
        end
    end
end