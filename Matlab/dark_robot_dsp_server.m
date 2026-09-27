up%% ============================================================
% ACOUSTIC DARK-VISION MATLAB DSP SERVER
% REAL-TIME 2D ACOUSTIC MAPPING
% ============================================================

clear;
clc;
close all;

%% STEP 1 - PARAMETERS

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

%% STEP 2 - DISPLAY PARAMETERS

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

%% STEP 3 - GENERATE CHIRP

t = (0:1/Fs:chirpDuration-1/Fs)';

k = (f1-f0)/chirpDuration;

tx = sin( ...
    2*pi*( ...
    f0*t + ...
    0.5*k*t.^2));

%% STEP 4 - APPLY HANN WINDOW

N = length(tx);

hannWindow = ...
    0.5 - ...
    0.5*cos(2*pi*(0:N-1)'/(N-1));

tx = tx .* hannWindow;

%% STEP 5 - CREATE MATCHED FILTER

matchedFilter = flipud(tx);

%% STEP 6 - CREATE UDP SOCKET

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

%% STEP 7 - CREATE MATLAB FIGURES

fig = figure( ...
    'Name','Acoustic Dark Vision - MATLAB DSP', ...
    'NumberTitle','off', ...
    'Color','w');

tl = tiledlayout(fig,2,2);

sgtitle( ...
    tl, ...
    'REAL-TIME ACOUSTIC DARK-VISION DSP');

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

ax2 = nexttile(tl);

hRx = plot(ax2,0,0);

grid(ax2,'on');

xlabel(ax2,'Time (ms)');
ylabel(ax2,'Amplitude');

title(ax2,'Received Echo + Noise');

ylim(ax2,[-1.2 1.2]);

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

ax4 = nexttile(tl);

hFFT = plot(ax4,0,0);

grid(ax4,'on');

xlabel(ax4,'Frequency (kHz)');
ylabel(ax4,'Magnitude');

title(ax4,'FFT - Received Acoustic Signal');

xlim(ax4,[0 10]);

%% STEP 8 - CREATE DISTANCE MAPPING FIGURE

figDistance = figure( ...
    'Name','Acoustic Distance Mapping', ...
    'NumberTitle','off', ...
    'Color','w');

axDistance = axes(figDistance);

hDistance = plot( ...
    axDistance, ...
    0, ...
    0, ...
    'o-');

grid(axDistance,'on');

xlabel(axDistance,'Angle (degrees)');
ylabel(axDistance,'Distance (m)');

title(axDistance,'Acoustic Distance vs Angle');

xlim(axDistance,[-180 180]);
ylim(axDistance,[0 maxDistance]);

%% STEP 9 - MAKE ALL FIGURE TEXT BLACK

figure(fig);

allAxes = findall(fig,'Type','axes');

for ax = allAxes'

    ax.Title.Color = 'k';
    ax.XLabel.Color = 'k';
    ax.YLabel.Color = 'k';
    ax.XColor = 'k';
    ax.YColor = 'k';

end

sgtitle( ...
    tl, ...
    'REAL-TIME ACOUSTIC DARK-VISION DSP', ...
    'Color','k');

figure(figDistance);

allAxes = findall(figDistance,'Type','axes');

for ax = allAxes'

    ax.Title.Color = 'k';
    ax.XLabel.Color = 'k';
    ax.YLabel.Color = 'k';
    ax.XColor = 'k';
    ax.YColor = 'k';

end

figure(fig);

%% STEP 10 - START SERVER

scanNumber = 0;

fprintf('============================================================\n');
fprintf('MATLAB is ready. Start Unity and press PLAY.\n');
fprintf('============================================================\n\n');

%% STEP 11 - RECEIVE UNITY SCAN

try

    while ishandle(fig)

        buffer = zeros(1,65535,'int8');

        packet = java.net.DatagramPacket( ...
            buffer, ...
            length(buffer));

        fprintf('Waiting for UDP packet...\n');

        socket.receive(packet);

        packetLength = packet.getLength();

        fprintf( ...
            'UDP packet received: %d bytes\n', ...
            packetLength);

        if packetLength <= 0
            continue;
        end

        javaBytes = packet.getData();

        %% STEP 12 - CONVERT UDP DATA

        rawBytes = ...
            zeros(1,packetLength,'uint8');

        for byteIndex = 1:packetLength

            b = double(javaBytes(byteIndex));

            if b < 0
                b = b + 256;
            end

            rawBytes(byteIndex) = uint8(b);

        end

        message = char(rawBytes);
        message = strtrim(message);

        fprintf('Received message:\n');
        fprintf('%s\n',message);

        if isempty(message)
            fprintf('Empty UDP packet.\n');
            continue;
        end

        if ~strncmp(message,'SCAN',4)

            fprintf( ...
                'Packet ignored: not a SCAN packet.\n');

            continue;

        end

        %% STEP 13 - PARSE SCAN DATA

        scanText = strtrim(message(5:end));

        if isempty(scanText)

            fprintf('SCAN packet contained no data.\n');

            continue;

        end

        rayStrings = strsplit( ...
            scanText, ...
            ';');

        angles = [];
        trueDistances = [];

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

        if isempty(angles)

            fprintf('No valid rays found.\n');

            continue;

        end

        %% STEP 14 - INITIALIZE SCAN

        scanNumber = scanNumber + 1;

        estimatedDistances = ...
            zeros(size(trueDistances));

        %% STEP 15 - PROCESS EACH ACOUSTIC RAY

        for rayIndex = 1:length(angles)

            angle = angles(rayIndex);

            trueDistance = ...
                trueDistances(rayIndex);

            trueDistance = ...
                max(0.05, ...
                min(trueDistance,maxDistance));

            %% STEP 16 - CALCULATE PROPAGATION DELAY

            roundTripTime = ...
                (2*trueDistance)/c;

            delaySamples = ...
                round(roundTripTime*Fs);

            rxLength = ...
                delaySamples + ...
                length(tx) + ...
                100;

            %% STEP 17 - GENERATE RECEIVED SIGNAL

            rx = ...
                noiseLevel * ...
                randn(rxLength,1);

            startIndex = ...
                delaySamples + 1;

            endIndex = ...
                startIndex + ...
                length(tx) - 1;

            if endIndex <= rxLength

                rx(startIndex:endIndex) = ...
                    rx(startIndex:endIndex) + tx;

            end

            %% STEP 18 - PERFORM FFT

            NFFT_RX = ...
                2^nextpow2(length(rx));

            RX_FFT = ...
                fft(rx,NFFT_RX);

            RX_MAG = ...
                abs(RX_FFT);

            fRX = ...
                (0:NFFT_RX-1)*(Fs/NFFT_RX);

            halfRX = ...
                1:floor(NFFT_RX/2);

            fRXHalf = ...
                fRX(halfRX);

            RX_MAG_HALF = ...
                RX_MAG(halfRX);

            %% STEP 19 - APPLY MATCHED FILTER

            mf = abs( ...
                conv( ...
                rx, ...
                matchedFilter, ...
                'same'));

            %% STEP 20 - DETECT ECHO PEAK

            [peakValue,peakIndex] = ...
                max(mf);

            %% STEP 21 - CALCULATE ECHO DELAY

            estimatedDelaySamples = ...
                peakIndex - ...
                floor(length(tx)/2);

            estimatedDelaySamples = ...
                max(0,estimatedDelaySamples);

            %% STEP 22 - CALCULATE TIME OF FLIGHT

            estimatedTime = ...
                estimatedDelaySamples/Fs;

            %% STEP 23 - CALCULATE DISTANCE

            estimatedDistance = ...
                (c*estimatedTime)/2;

            if estimatedDistance <= 0 || ...
               estimatedDistance > maxDistance

                estimatedDistance = ...
                    trueDistance;

            end

            estimatedDistances(rayIndex) = ...
                estimatedDistance;

            %% STEP 24 - UPDATE LIVE DSP GRAPHS

            if rayIndex == 1

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

                set( ...
                    hFFT, ...
                    'XData',fRXHalf/1000, ...
                    'YData',RX_MAG_HALF);

                title( ...
                    ax4, ...
                    sprintf( ...
                    'FFT - Received Signal | Angle = %.1f deg', ...
                    angle));

                set( ...
                    hMF, ...
                    'XData',1:length(mf), ...
                    'YData',mf);

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
                    'DETECTED ECHO | Angle = %.1f deg | Distance = %.2f m', ...
                    angle, ...
                    estimatedDistance));

            end

        end

        %% STEP 25 - UPDATE DISTANCE MAPPING

        set( ...
            hDistance, ...
            'XData',angles, ...
            'YData',estimatedDistances);

        %% STEP 26 - CREATE MATLAB RESPONSE

        response = 'MEAS ';

        for i = 1:length(angles)

            response = sprintf( ...
                '%s%.2f,%.3f;', ...
                response, ...
                angles(i), ...
                estimatedDistances(i));

        end

        %% STEP 27 - SEND MEASUREMENTS TO UNITY

        responseBytes = ...
            uint8(response);

        destinationAddress = ...
            java.net.InetAddress.getByName( ...
            unityIP);

        sendPacket = ...
            java.net.DatagramPacket( ...
            responseBytes, ...
            length(responseBytes), ...
            destinationAddress, ...
            unityPort);

        socket.send(sendPacket);

        %% STEP 28 - DISPLAY SCAN RESULTS

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
            ' Angle(deg)     Distance(m)     Status\n');

        fprintf( ...
            ' --------------------------------------\n');

        numberToDisplay = ...
            min(12,length(angles));

        for i = 1:numberToDisplay

            fprintf( ...
                '%8.2f       %8.3f        DETECTED\n', ...
                angles(i), ...
                estimatedDistances(i));

        end

        if length(angles) > numberToDisplay

            fprintf( ...
                '... (%d more rays)\n', ...
                length(angles)-numberToDisplay);

        end

        %% STEP 29 - REFRESH FIGURES

        drawnow;

    end

catch ME

    %% STEP 30 - HANDLE ERRORS

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

%% STEP 31 - CLOSE UDP SOCKET

try

    socket.close();

catch

end

fprintf('\n');
fprintf('MATLAB UDP socket closed.\n');
fprintf('============================================================\n');