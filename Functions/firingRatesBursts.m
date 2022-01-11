function [Ephys] = firingRatesBursts(spikeMatrix,Params,Info)
% 	Calculate basic firing properties as well as network burst metrics on
% 	MEA data. Note currently defaults to Bakkum (2014) method but
% 	burstDetect function (written by Timothy Sit) utilised here has
% 	functionality for other methods.
% 
%   2020-2022
%   Alexander WE Dunn, CU
%   Rachael C Feord, CU
%   Timothy Sit, UCL
% 
%   Modification History:
%   March 2020:     Original (Alexander WE Dunn) 
%   October 2021:   Firing rate stats & network bursts merged into one
%                   structural array output (Rachael C Feord)
%   December 2021:  Correction to firing rate calculation and bug where
%                   <2 bursts occur (Alexander WE Dunn) 
% 
%   Future updates: 
%       Within-electrode burst metrics; firing regularity 
% 
%       Remove default to Bakkum (2014) method and add 
%       params.networkBurstMethod into MEApipeline script once other burst
%       detection methods have been tested 

% set firing rate threshold in Hz
FR_threshold = 0.01; % in Hz or spikes/s
% get spike counts
FiringRates = full(sum(spikeMatrix))/Info.duration_s;
% calculate firing rates
%remove ref channel spikes:
FiringRates(Info.channels == 15)    =  0;     
active_chanIndex = FiringRates      >= FR_threshold;
ActiveFiringRates = FiringRates(active_chanIndex);  %spikes of only active channels ('active'= >7)

Ephys.FR = ActiveFiringRates;
% currently calculates only on active channels (>=FR_threshold)
% stats
Ephys.FRmean = round(mean(ActiveFiringRates),3);
Ephys.FRstd = round(std(ActiveFiringRates),3);
Ephys.FRsem = round(std(ActiveFiringRates)/(sqrt(length(ActiveFiringRates))),3);
Ephys.FRmedian = round(median(ActiveFiringRates),3);
Ephys.FRiqr = round(iqr(ActiveFiringRates),3);
Ephys.numActiveElec = length(ActiveFiringRates);

%get rid of NaNs where there are no spikes; change to 0
if isnan(Ephys.FRmean)
    Ephys.FRmean=0;
end
if isnan(Ephys.FRmedian)
    Ephys.FRmedian=0;
end


method ='Bakkum';
%note, Set N = 30 (min number of bursts)
%ensure bursts are excluded if fewer than 3 channels (see inside burstDetect
%function)
%to change min channels change line 207 of burstDetect.m
%to change N (min n spikes) see line 170 of burstDetect.m
N = 10; minChan = 3;

[burstMatrix, burstTimes, burstChannels] = burstDetect(spikeMatrix, method, Params.fs, N, minChan);
nBursts = size(burstTimes,1);

if ~isempty(burstMatrix)
    for Bst=1:length(burstMatrix)
        sp_in_bst(Bst)=sum(sum(burstMatrix{Bst,1}));
        train = sum(burstMatrix{Bst,1},2);%sum across channels
        train(train>1)=1; %re-binarise
        sp_times = find(train==1);
        sp_times2= sp_times(2:end);
        ISI_within = sp_times2 - sp_times(1:end-1);
        mean_ISI_w(Bst) = round(mean(ISI_within)/Params.fs*1000,3); %in ms with 3 d.p.
        chans_involved(Bst) = length(burstChannels{Bst,1});
        
        NBLength(Bst) = size(burstMatrix{Bst,1},1)/Params.fs;
        
        clear ISI_within sp_times sp_times2 train
        
    end
    sp_in_bst=sum(sp_in_bst);
    
    train = sum(spikeMatrix,2);%sum across channels
    train(train>1)=1; %re-binarise
    sp_times = find(train==1);
    sp_times2= sp_times(2:end);
    ISI_outside = sp_times2 - sp_times(1:end-1);
    
    %get IBIs
    end_times = burstTimes(1:end-1,2); %-1 because no IBI after end of last burst
    sta_times = burstTimes(2:end,1); %start from burst start time 2
    IBIs      = sta_times -end_times;
    % calculate CV of IBI and non need to convert from samples to seconds
    % (as relative measure it would be the same)
    
    % NOTE: these are based on the ISI across all channels!!!
    Ephys.meanNBstLengthS = mean(NBLength); % mean length burst in s
    Ephys.numNbursts = size(burstTimes,1);
    Ephys.meanNumChansInvolvedInNbursts = mean(chans_involved);
    Ephys.meanISIWithinNbursts_ms = mean(mean_ISI_w);
    Ephys.meanISIoutsideNbursts_ms = round(mean(ISI_outside)/Params.fs*1000,3);
    Ephys.CVofINBI = round((std(IBIs)/mean(IBIs)),3); %3 decimal places
    Ephys.NBurstRate = round(60*(nBursts/(length(spikeMatrix(:,1))/Params.fs)),3);
    Ephys.fracInNburst = round(sp_in_bst/sum(sum(spikeMatrix)),3);
    
    %need to go into burst detect and edit as it is not deleting the bursts
    %with <5 channels from burstChannels and burstTimes hence they are longer
    %need this for easier plotting of burst
    
else
    disp('no bursts detected')
    sp_in_bst=0;
    
    Ephys.meanNBstLengthS = nan; % mean length burst in s
    Ephys.numNbursts = nan;
    Ephys.meanNumChansInvolvedInNbursts = nan;
    Ephys.meanISIWithinNbursts_ms = nan;
    Ephys.meanISIoutsideNbursts_ms = nan;
    Ephys.CVofINBI = nan; %3 decimal places
    Ephys.NBurstRate = nan;
    Ephys.fracInNburst = nan;
    
end