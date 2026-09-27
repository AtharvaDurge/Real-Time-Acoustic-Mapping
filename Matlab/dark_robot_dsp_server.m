%% ============================================================
%        ACOUSTIC DARK-VISION MATLAB DSP SERVER
%        REAL-TIME 2D ACOUSTIC MAPPING
%
%        MATLAB <---- UDP ----> UNITY
%
%        MATLAB performs:
%        1. Chirp generation
%        2. Echo simulation
%        3. Noise addition
%        4. Matched filtering
%        5. Peak detection
%        6. Time-of-flight calculation
%        7. Distance estimation
%
% ============================================================

clear;
clc;
close all;

%% ============================================================
%                     PARAMETERS
% ============================================================

Fs = 44100;

c = 343;

f0 = 3000;
f1 = 7000;

chirpDuration = 0.005;

matlabPort = 55000;
unityPort  = 55001;

unityIP = '127.0.0.1';

noiseLevel = 0.015;

maxDistance = 10;

%% ============================================================
%                     HEADER
% ============================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('        ACOUSTIC DARK-VISION MATLAB DSP SERVER\n');
fprintf('============================================================\n');

fprintf('Sampling frequency : %d Hz\n',Fs);
fprintf('Chirp              : %d -> %d Hz\n',f0,f1);
fprintf('Chirp duration     : %.2f ms\n',chirpDuration*1000);
fprintf('Speed of sound     : %.1f m/s\n',c);
fprintf('MATLAB UDP port    : %d\n',matlabPort);
fprintf('Unity UDP port     : %d\n',unityPort);

fprintf('============================================================\n');
fprintf('\n');

%% ============================================================
%                     GENERATE CHIRP
% ============================================================

t = (0:1/Fs:chirpDuration-1/Fs)';

k = (f1-f0)/chirpDuration;

tx = sin( ...
    2*pi*( ...
    f0*t + ...
    0.5*k*t.^2));

%% ============================================================
%                     HANN WINDOW
% ============================================================

N = length(tx);

hannWindow = ...
    0.5 - ...
    0.5*cos(2*pi*(0:N-1)'/(N-1));

tx = tx .* hannWindow;

%% ============================================================
%                     MATCHED FILTER
% ============================================================

matchedFilter = flipud(tx);

%% ============================================================
%                     CREATE UDP SOCKET
% ============================================================

try

    socket = java.net.DatagramSocket(matlabPort);

catch ME

    fprintf('\n');
    fprintf('============================================================\n');
    fprintf('UDP SOCKET ERROR\n');
    fprintf('============================================================\n');

    fprintf('%s\n',ME.message);

    fprintf('\n');
    fprintf('Port %d is probably already being used.\n',matlabPort);

    return;

end

fprintf('MATLAB UDP socket created successfully.\n');
fprintf('Waiting for Unity...\n\n');

%% ============================================================
%                     FIGURE
% ============================================================

fig = figure( ...
    'Name','Acoustic Dark Vision - MATLAB DSP', ...
    'NumberTitle','off', ...
    'Color','w');

tl = tiledlayout(fig,2,2);

sgtitle( ...
    tl, ...
    'REAL-TIME ACOUSTIC DARK-VISION DSP');

%% ============================================================
%                     PLOT 1
%                     TX CHIRP
% ============================================================

ax1 = nexttile(tl);

hTx = plot( ...
    ax1, ...
    t*1000, ...
    tx);

grid(ax1,'on');

xlabel(ax1,'Time (ms)');
ylabel(ax1,'Amplitude');

title(ax1,'Transmitted Acoustic Chirp');

xlim(ax1,[0 chirpDuration*1000]);
ylim(ax1,[-1.1 1.1]);

%% ============================================================
%                     PLOT 2
%                     RX ECHO
% ============================================================

ax2 = nexttile(tl);

hRx = plot(ax2,0,0);

grid(ax2,'on');

xlabel(ax2,'Time (ms)');
ylabel(ax2,'Amplitude');

title(ax2,'Received Echo + Noise');

ylim(ax2,[-1.2 1.2]);

%% ============================================================
%                     PLOT 3
%                     MATCHED FILTER
% ============================================================

ax3 = nexttile(tl);

hMF = plot(ax3,0,0);

hold(ax3,'on');

hPeak = plot( ...
    ax3, ...
    0, ...
    0, ...
    'ro', ...
    'MarkerSize',8);

grid(ax3,'on');

xlabel(ax3,'Sample');
ylabel(ax3,'Correlation');

title(ax3,'Matched Filter Output');

%% ============================================================
%                     PLOT 4
%                     DISTANCE VS ANGLE
% ============================================================

ax4 = nexttile(tl);

hDistance = plot( ...
    ax4, ...
    0, ...
    0, ...
    'o-');

grid(ax4,'on');

xlabel(ax4,'Angle (degrees)');
ylabel(ax4,'Distance (m)');

title(ax4,'Acoustic Distance vs Angle');

xlim(ax4,[-180 180]);
ylim(ax4,[0 maxDistance]);

%% ============================================================
%                     READY
% ============================================================

scanNumber = 0;

fprintf('============================================================\n');
fprintf('MATLAB is ready. Start Unity and press PLAY.\n');
fprintf('============================================================\n\n');

%% ============================================================
%                     MAIN LOOP
% ============================================================

try

    while ishandle(fig)

        %% ====================================================
        % CREATE UDP RECEIVE BUFFER
        % =====================================================

        buffer = zeros(1,65535,'int8');

        packet = java.net.DatagramPacket( ...
            buffer, ...
            length(buffer));

        %% ====================================================
        % WAIT FOR UNITY PACKET
        % =====================================================

        fprintf('Waiting for UDP packet...\n');

        socket.receive(packet);

        %% ====================================================
        % PACKET RECEIVED
        % =====================================================

        packetLength = packet.getLength();

        fprintf( ...
            'UDP packet received: %d bytes\n', ...
            packetLength);

        if packetLength <= 0

            continue;

        end

        %% ====================================================
        % GET JAVA BYTE ARRAY
        % =====================================================

        javaBytes = packet.getData();

        %% ====================================================
        % EXPLICIT BYTE CONVERSION
        %
        % Java byte = signed [-128,127]
        %
        % UDP data = unsigned [0,255]
        %
        % Therefore:
        %
        % negative byte + 256
        % =====================================================

        rawBytes = ...
            zeros(1,packetLength,'uint8');

        for byteIndex = 1:packetLength

            b = double(javaBytes(byteIndex));

            if b < 0

                b = b + 256;

            end

            rawBytes(byteIndex) = uint8(b);

        end

        %% ====================================================
        % CONVERT BYTES TO TEXT
        % =====================================================

        message = char(rawBytes);

        message = strtrim(message);

        fprintf('Received message:\n');
        fprintf('%s\n',message);

        %% ====================================================
        % CHECK MESSAGE
        % =====================================================

        if isempty(message)

            fprintf('Empty UDP packet.\n');

            continue;

        end

        if ~strncmp(message,'SCAN',4)

            fprintf( ...
                'Packet ignored: not a SCAN packet.\n');

            continue;

        end

        %% ====================================================
        % REMOVE "SCAN"
        % =====================================================

        scanText = strtrim( ...
            message(5:end));

        if isempty(scanText)

            fprintf('SCAN packet contained no data.\n');

            continue;

        end

        %% ====================================================
        % SPLIT RAYS
        %
        % Example:
        %
        % SCAN -180,4.2;-175,4.3;-170,4.5;
        %
        % =====================================================

        rayStrings = strsplit( ...
            scanText, ...
            ';');

        angles = [];

        trueDistances = [];

        %% ====================================================
        % PARSE RAYS
        % =====================================================

        for i = 1:length(rayStrings)

            ray = strtrim(rayStrings{i});

            if isempty(ray)

                continue;

            end

            values = sscanf( ...
                ray, ...
                '%f,%f');

            if numel(values) ~= 2

                continue;

            end

            angle = values(1);

            distance = values(2);

            angles(end+1) = angle; %#ok<SAGROW>

            trueDistances(end+1) = distance; %#ok<SAGROW>

        end

        %% ====================================================
        % CHECK RAYS
        % =====================================================

        if isempty(angles)

            fprintf('No valid rays found.\n');

            continue;

        end

        %% ====================================================
        % START NEW SCAN
        % =====================================================

        scanNumber = scanNumber + 1;

        estimatedDistances = ...
            zeros(size(trueDistances));

        %% ====================================================
        % PROCESS EVERY RAY
        % =====================================================

        for rayIndex = 1:length(angles)

            angle = angles(rayIndex);

            trueDistance = ...
                trueDistances(rayIndex);

            %% =================================================
            % LIMIT DISTANCE
            % =================================================

            trueDistance = ...
                max(0.05, ...
                min(trueDistance,maxDistance));

            %% =================================================
            % ROUND-TRIP PROPAGATION TIME
            %
            % tau = 2d/c
            % =================================================

            roundTripTime = ...
                (2*trueDistance)/c;

            %% =================================================
            % DELAY IN SAMPLES
            % =================================================

            delaySamples = ...
                round(roundTripTime*Fs);

            %% =================================================
            % RECEIVED SIGNAL LENGTH
            % =================================================

            rxLength = ...
                delaySamples + ...
                length(tx) + ...
                100;

            %% =================================================
            % BACKGROUND NOISE
            % =================================================

            rx = ...
                noiseLevel * ...
                randn(rxLength,1);

            %% =================================================
            % INSERT DELAYED ECHO
            % =================================================

            startIndex = ...
                delaySamples + 1;

            endIndex = ...
                startIndex + ...
                length(tx) - 1;

            if endIndex <= rxLength

                rx(startIndex:endIndex) = ...
                    rx(startIndex:endIndex) + tx;

            end

            %% =================================================
            % MATCHED FILTER
            %
            % y[n] = x[n] * h[n]
            %
            % h[n] = time-reversed transmitted chirp
            % =================================================

            mf = abs( ...
                conv( ...
                rx, ...
                matchedFilter, ...
                'same'));

            %% =================================================
            % PEAK DETECTION
            % =================================================

            [peakValue,peakIndex] = ...
                max(mf);

            %% =================================================
            % ESTIMATED DELAY
            % =================================================

            estimatedDelaySamples = ...
                peakIndex - ...
                floor(length(tx)/2);

            estimatedDelaySamples = ...
                max(0,estimatedDelaySamples);

            %% =================================================
            % TIME OF FLIGHT
            % =================================================

            estimatedTime = ...
                estimatedDelaySamples/Fs;

            %% =================================================
            % DISTANCE
            %
            % d = c*tau/2
            % =================================================

            estimatedDistance = ...
                (c*estimatedTime)/2;

            %% =================================================
            % VALIDITY CHECK
            % =================================================

            if estimatedDistance <= 0 || ...
               estimatedDistance > maxDistance

                estimatedDistance = ...
                    trueDistance;

            end

            estimatedDistances(rayIndex) = ...
                estimatedDistance;

            %% =================================================
            % DISPLAY FIRST RAY
            % =================================================

            if rayIndex == 1

                %% ---------------------------------------------
                % RECEIVED SIGNAL
                % ---------------------------------------------

                rxTime = ...
                    (0:length(rx)-1)/Fs*1000;

                set( ...
                    hRx, ...
                    'XData',rxTime, ...
                    'YData',rx);

                xlim( ...
                    ax2, ...
                    [0 max(rxTime)]);

                title( ...
                    ax2, ...
                    sprintf( ...
                    'Received Echo + Noise | Angle %.1f deg', ...
                    angle));

                %% ---------------------------------------------
                % MATCHED FILTER
                % ---------------------------------------------

                set( ...
                    hMF, ...
                    'XData',1:length(mf), ...
                    'YData',mf);

                %% ---------------------------------------------
                % PEAK
                % ---------------------------------------------

                set( ...
                    hPeak, ...
                    'XData',peakIndex, ...
                    'YData',peakValue);

                xlim( ...
                    ax3, ...
                    [1 length(mf)]);

                title( ...
                    ax3, ...
                    sprintf( ...
                    'Matched Filter | Distance = %.2f m', ...
                    estimatedDistance));

            end

        end

        %% ====================================================
        % UPDATE DISTANCE GRAPH
        % ====================================================

        set( ...
            hDistance, ...
            'XData',angles, ...
            'YData',estimatedDistances);

        %% ====================================================
        % CREATE RESPONSE
        % ====================================================

        response = 'MEAS ';

        for i = 1:length(angles)

            response = sprintf( ...
                '%s%.2f,%.3f;', ...
                response, ...
                angles(i), ...
                estimatedDistances(i));

        end

        %% ====================================================
        % CONVERT RESPONSE TO BYTES
        % ====================================================

        responseBytes = ...
            uint8(response);

        %% ====================================================
        % CREATE DESTINATION
        % ====================================================

        destinationAddress = ...
            java.net.InetAddress.getByName( ...
            unityIP);

        %% ====================================================
        % CREATE RESPONSE PACKET
        % ====================================================

        sendPacket = ...
            java.net.DatagramPacket( ...
            responseBytes, ...
            length(responseBytes), ...
            destinationAddress, ...
            unityPort);

        %% ====================================================
        % SEND RESPONSE TO UNITY
        % ====================================================

        socket.send(sendPacket);

        %% ====================================================
        % COMMAND WINDOW
        % ====================================================

        fprintf('\n');

        fprintf( ...
            '============================================================\n');

        fprintf( ...
            'SCAN %04d | %d rays processed | MATLAB -> Unity\n', ...
            scanNumber, ...
            length(angles));

        fprintf( ...
            '============================================================\n');

        fprintf( ...
            ' Angle(deg)     Distance(m)\n');

        fprintf( ...
            ' --------------------------\n');

        numberToDisplay = ...
            min(12,length(angles));

        for i = 1:numberToDisplay

            fprintf( ...
                '%8.2f       %8.3f\n', ...
                angles(i), ...
                estimatedDistances(i));

        end

        if length(angles) > numberToDisplay

            fprintf( ...
                '... (%d more rays)\n', ...
                length(angles)-numberToDisplay);

        end

        %% ====================================================
        % REFRESH MATLAB FIGURE
        % ====================================================

        drawnow;

    end

catch ME

    %% ========================================================
    % ERROR DISPLAY
    % ========================================================

    fprintf('\n');
    fprintf('============================================================\n');
    fprintf('MATLAB DSP SERVER ERROR\n');
    fprintf('============================================================\n');

    fprintf('Error message:\n');
    fprintf('%s\n',ME.message);

    fprintf('\n');

    if ~isempty(ME.stack)

        fprintf( ...
            'Error occurred at line %d.\n', ...
            ME.stack(1).line);

    end

end

%% ============================================================
%                     CLOSE SOCKET
% ============================================================

try

    socket.close();

catch

end

fprintf('\n');
fprintf('MATLAB UDP socket closed.\n');

fprintf('============================================================')