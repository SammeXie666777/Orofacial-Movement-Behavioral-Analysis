%% 1) Cut frame for movies 2) Align frames to Bpod for on mouse for ONE MOUSE
% Bpod: all dates for one mouse saved in one folder
% pathtoBpod = 'C:\Users\jaegerlabuser\OneDrive - Emory University\Matlab\Orofacial_movement\Ellie_Opto_Video\AP036\Bpod\Session Data';
clear; close
pathtoBpod = '/Users/samme/Library/CloudStorage/OneDrive-EmoryUniversity/Matlab/Orofacial_movement/Ellie_Opto_Video/AP036/Bpod/Session Data';
Date = 'All'; % one date (20231121) or All 
states = {'InitialDelay','Baseline'};
ID = 'AP036';

% Movie: of selected date or All
frameRate = 100;
tPerFrame = 1/frameRate; % time pin 
camID = '40051935'; 
pathToMovie= '/Users/samme/Library/CloudStorage/OneDrive-EmoryUniversity/Matlab/Orofacial_movement/Ellie_Opto_Video/AP036/Video';
pathOutput = '/Users/samme/Library/CloudStorage/OneDrive-EmoryUniversity/Matlab/Orofacial_movement/Ellie_Opto_Video/AP036/Processed_video';

% Cropping ROI: Leave the face and paws 
% Full size = [840,490]; [horizontal,vertical]
ROI = [240,0,690,500];  %[xmin ymin xMax yMax]; Left up corner: [0,0]

%% 1) Find idx for intended states frames  
cd (pathtoBpod);
listBpod = dir(['*' 'mat']);
if ~strcmp(Date,'All')
    idx = cellfun(@(x) ~isempty(x), strfind({listBpod(:).name},Date));
    listBpod = listBpod(idx);  
end

idk = cellfun(@(x) ~contains(x,'movieIdx'),{listBpod(:).name});
listBpod = listBpod(idk,:);
if size(listBpod,1) == 0
    disp('No corresponding Bpod file');
    quit;
end
% 1. idx period of interest for each trial
for i = 1:length(listBpod)
    fileN = listBpod(i).name;
    load(fileN);
    nTrials = SessionData.nTrials;
    T_total = zeros(1,nTrials); % length of each trial   
    movie = struct();
    for j = 1:nTrials % for one Bpod mat file
        trialN = sprintf('trial_%d',j);
        T_total(j) = SessionData.RawEvents.Trial{1,j}.States.TimerEnd(1,2);
        T_tick = zeros(1,floor(T_total(j)/tPerFrame)); %total # frames in this trial
        PoI = [];
        for k = 1: numel(states)
            temp = SessionData.RawEvents.Trial{1,j}.States.(states{k});
            PoI = [PoI;temp]; % period of interest concatenated (2 by m)
        end
        PoI = floor(PoI/tPerFrame)+1;
        %PoI = reshape(PoI', 1, numel(PoI));
        for z = 1:size(PoI,1)
            T_tick (PoI(z,1):1:PoI(z,2)) = 1; 
            if PoI(z,1) == PoI(z,2)
                T_tick (PoI(z,1)) = 1;
            end
        end
        movie.(trialN) = T_tick;
    end
    movie.T_total = T_total;
    save(strcat(pathToMovie,'/',fileN(1:end-4),"_movieIdx.mat"),"movie");
    % index saved as same folder of raw movide
end
clearvars -except Date ID frameRate tPerFrame camID pathToMovie pathOutput ROI

%% Indexa all files for relevant date (run this always)
cd (pathToMovie);
listdir = dir();
if ~strcmp(Date,'All') 
    idx = cellfun(@(x) ~isempty(x), strfind({listdir(:).name},Date));
    listdir = listdir(idx);  
else % if idx All date
    idx = arrayfun(@(x) (x.isdir & ~ismember(x.name, {'.', '..'})) | (endsWith(x.name, '.mat') & ~ismember(x.name, {'.', '..'})), listdir);
    listdir = listdir(idx); 
end
listdir = listdir(cellfun(@(x) ~contains(x,'output'),{listdir(:).name}));
listFolder = listdir([listdir.isdir]);

%% 2) Cropping all interested videos from date folder; cropped videos saved under each date along with original videos
tic;
for i = 1:numel(listFolder) % one folder is one date
    vdlist = dir(fullfile(listFolder(i).folder,listFolder(i).name,'*.mp4'));
    vdlist = vdlist(cellfun(@(x) ~isempty(x),strfind({vdlist(:).name},camID)));
    %d = vdlist(1).name(end-21:end-14);
    for j = 1:numel(vdlist)
        inputName = fullfile(vdlist(j).folder,vdlist(j).name);
        outputName = fullfile(vdlist(j).folder,strcat('Cropped_',vdlist(j).name));
        cropMatlab(inputName, outputName, ROI); 
    end
end
  
elapsedTime = toc; % End timer and capture elapsed time
fprintf('Time taken to run cropping section: %f seconds\n', elapsedTime);

%% 3). cut the frames between time points: go through each date and concatenate frames into one video for per day
clearvars -except listdir listFolder Date ID frameRate tPerFrame camID pathToMovie pathOutput ROI

tic;
totalFrames = zeros(1,numel(listFolder)); %record # frames for each video
for i = 1:numel(listFolder)
    d = listFolder(i).name;
    vdlist = dir(fullfile(listFolder(i).folder,listFolder(i).name,'*.mp4'));
    vdlist = vdlist(cellfun(@(x) contains(x, camID) && contains(x, 'Cropped'), {vdlist(:).name}));
    videoW = VideoWriter(fullfile(pathOutput,strcat('BpodAligned_Cropped_',camID,'_',ID,'_',d)), 'MPEG-4'); % one video just one day
    videoW.FrameRate = frameRate; 
    for j = 1:numel(vdlist)
        id = vdlist(j).name(end-12:end-10);
        allIdx = listdir(arrayfun(@(x) (~x.isdir),listdir));
        temp = arrayfun(@(x) strcmp(x.name(end-18:end-16),id) && contains(x.name,d),allIdx);
        load(fullfile(allIdx(temp).folder,allIdx(temp).name));
        trialIdx = 0;
        for z = 1:numel(fieldnames(movie))-1 
            temp = movie.(sprintf('trial_%d', z));
            trialIdx = [trialIdx,temp];
        end
        % position of frames to extract for one video
        trialIdx = find(trialIdx == 1);
        videoR = VideoReader(fullfile(vdlist(j).folder,vdlist(j).name));
        totalFrames(1,i) = videoR.NumFrames + totalFrames; % frame number for each clip
        open(videoW);
        for f = 1:length(trialIdx)
            t = (trialIdx(f)-1) / videoR.FrameRate;
            videoR.CurrentTime = t; % each frame is 0.01 sec
            currentFrame = readFrame(videoR);
            writeVideo(videoW, currentFrame);
        end
    end

    actualFrames = videoW.NumFrames;
    if actualFrames ~= totalFrames(1,i)
        disp('Frames from contanenated movie not equal to sum of all video clips');
    end
    close(videoW);         
end

elapsedTime = toc; % End timer and capture elapsed time
fprintf('Time taken to run align bpod section: %f seconds\n', elapsedTime);

