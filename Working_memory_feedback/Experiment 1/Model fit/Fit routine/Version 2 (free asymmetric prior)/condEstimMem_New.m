% conditional observer model with memory recall and motor noise
% for orientation stimulus (infinite space approximation)
% ********** Old version - condition the prior only ********** 
% astocker - lluu
% 06.2017
flagSC = 1; % 1: self-conditioned model
           % 0: standard Bayes
includeIncongruentTrials = 0;
incorrectType = 2; % 1: flip the decision bit
                   % 2: flip the estimates
                   % 3: resample the measurement mm until getting a consistent sample
                   % 4: lose all information and use prior to make estimate

dstep = 0.1;
paramsAll = [5.1500   10.0831           0.0000     44.0107   -56.0947   4.3459    3.3313];
lapseRate = paramsAll(3);

% stimulus orientation
thetaStim = -21:0.1:21; % 
thetaStim = round(thetaStim, -log10(dstep));

% sensory noise
stdSensory = paramsAll(1:2);

% memory recall noise
stdMemory = paramsAll(6);
stdMemoryIncorrect = sqrt(stdMemory^2 + 0^2);

% motor noise;
stdMotor = paramsAll(7);

% priors
smoothFactor = 0;

%% LOOP - noise levels
% pC = [30/42, 12/42]'; % [cw ccw]
pC = [0.5, 0.5]';
pthcw = paramsAll(4);
pthccw = paramsAll(5); % paramsAll(4)

rangeth = [-60 60];
th = rangeth(1):dstep:rangeth(2);
th = round(th, -log10(dstep));
nth = length(th);

pthGC = zeros(2,nth);

if flagSC
    pthGC(1,:) = TukeyWindow([0 pthcw], 0, smoothFactor, th);
    pthGC(2,:) = TukeyWindow([pthccw 0], 1, smoothFactor, th);
else
    pth = (TukeyWindow([0 pthcw], 0, smoothFactor, th) + TukeyWindow([pthccw 0], 1, smoothFactor, th))/2;
    pth(th==0) = 0;
    pth(th==0) = max(pth);
    pthGC(1,:) = pth;
    pthGC(2,:) = pth;
end

figure;
for kk=1:length(stdSensory)  
    rangeM = [min(thetaStim)-5*stdSensory(kk) max(thetaStim)+5*stdSensory(kk)];
    if rangeM(2) < rangeth(2)
        rangeM = rangeth;
    end
    nm = 1000;
    m = linspace(rangeM(1), rangeM(2), nm);

    nmm = 1200;
    rangeMM = [min(rangeM)-6*stdMemory max(rangeM)+6*stdMemory];
    if rangeMM(2) < rangeth(2)
        rangeMM = rangeth;
    end        
    mm = linspace(rangeMM(1), rangeMM(2), nmm);

    nmr = nm;
    mr = m;

    M = repmat(m',1,nth);
    MM_m = repmat(mm',1,nm);
    MM_th = repmat(mm',1,nth); 
    MM_ths = repmat(mm',1,length(thetaStim));
    MR_mm = repmat(mr', 1, nmm);
    MR_th = repmat(mr', 1, nth);
    THm = repmat(th, nm, 1); 
    THmm = repmat(th, nmm, 1);
    THmr = repmat(th, nmr, 1);
    THSmm = repmat(thetaStim, nmm, 1);
    
    %% Correct trials
    % Generative (forward)
    % orientation noise
    pmGth = exp(-((M-THm).^2)./(2*stdSensory(kk)^2));
    pmGth = pmGth./(repmat(sum(pmGth,1),nm,1)); 

    % Inference
    % 1: categorical judgment
    PCGm = (pthGC * pmGth') .* repmat(pC,1,nm);
    % fix the issue when sensory noise is too low
    indFirstNonZero = find(PCGm(2,:), 1);
    PCGm(2, 1: indFirstNonZero-1) = PCGm(2, indFirstNonZero);
    indLastNonZero = find(PCGm(1,:), 1, 'last');
    PCGm(1, indLastNonZero+1:end) = PCGm(1, indLastNonZero);
    PCGm = PCGm./(repmat(sum(PCGm,1),2,1));
    % max posterior decision
    PChGm = round(PCGm);
    % marginalization
    PChGtheta = PChGm * pmGth(:, ismember(th, thetaStim));
    PChGtheta_lapse = lapseRate + (1 - 2*lapseRate) * PChGtheta;
    PChGtheta_lapse = PChGtheta_lapse ./ repmat(sum(PChGtheta_lapse, 1), 2, 1);
    
    % 2: estimation
    pmmGth = exp(-((MM_th-THmm).^2)./(2*(stdSensory(kk)^2 + stdMemory^2))); % p(mm|th) = N(th, sm^2 + smm^2)
    pmmGth = pmmGth./(repmat(sum(pmmGth,1),nmm,1)); 
    pthGmmChcw = (pmmGth.*repmat(pthGC(1,:),nmm,1))';
    pthGmmChcw = pthGmmChcw./repmat(sum(pthGmmChcw,1),nth,1);
    pthGmmChcw(isnan(pthGmmChcw)) = 0;

    pthGmmChccw = (pmmGth.*repmat(pthGC(2,:),nmm,1))';
    pthGmmChccw = pthGmmChccw./repmat(sum(pthGmmChccw,1),nth,1);
    pthGmmChccw(isnan(pthGmmChccw)) = 0;

    EthChcw = th * pthGmmChcw;
    EthChccw = th * pthGmmChccw;
    % discard repeating/decreasing values (required for interpolation) 
    indKeepCw = 1:length(EthChcw);
    while sum(diff(EthChcw)<=0) >0
        indDiscardCw = [false diff(EthChcw)<=0];
        EthChcw(indDiscardCw) = [];
        indKeepCw(indDiscardCw) = [];
    end
    indKeepCcw = 1:length(EthChccw);
    while sum(diff(EthChccw)<=0) >0
        indDiscardCcw = [diff(EthChccw)<=0 false];
        EthChccw(indDiscardCcw) = [];
        indKeepCcw(indDiscardCcw) = [];
    end
    
    a = 1./gradient(EthChcw,dstep);
    % memory noise
    pmmGm = exp(-((MM_m-repmat(m, nmm, 1)).^2)./(2*stdMemory^2)); 
    pmmGm = pmmGm./(repmat(sum(pmmGm,1),nmm,1));   

    % attention marginalization: compute distribution only over those ms that lead to cw decision!
    pmmGthChcw = pmmGm * (pmGth(:, ismember(th, thetaStim)).*repmat(PChGm(1,:)',1,length(thetaStim)));
    b = repmat(a',1,length(thetaStim)) .* pmmGthChcw(indKeepCw, :);        
    pthhGthChcw = interp1(EthChcw,b,th,'linear','extrap');
    % add motor noise
    pthhGthChcw = conv2(pthhGthChcw,pdf('norm',th,0,stdMotor)','same');
    pthhGthChcw(pthhGthChcw < 0) = 0; 
    
    a = 1./gradient(EthChccw,dstep);
    % attention marginalization: compute distribution only over those ms that lead to cw decision!
    pmmGthChccw = pmmGm * (pmGth(:, ismember(th, thetaStim)).*repmat(PChGm(2,:)',1,length(thetaStim)));        
    b = repmat(a',1,length(thetaStim)) .* pmmGthChccw(indKeepCcw, :);        
    pthhGthChccw = interp1(EthChccw,b,th,'linear','extrap');
    % add motor noise
    pthhGthChccw = conv2(pthhGthChccw,pdf('norm',th,0,stdMotor)','same');
    pthhGthChccw(pthhGthChccw < 0) = 0; 
    
    pthhGthChcw = pthhGthChcw./repmat(sum(pthhGthChcw,1),nth,1); % normalize - conv2 is not    
    pthhGthChccw = pthhGthChccw./repmat(sum(pthhGthChccw,1),nth,1);            
    
    if includeIncongruentTrials == 0
        % modify psychometric curve p(Chat|theta, Congruent) ~ p(Congruent| Chat, theta) * p(Chat|Theta)
        pCongruentGcwTh = sum(pthhGthChcw(th' >= 0, :));
        pCongruentGccwTh = sum(pthhGthChccw(th' <= 0, :));
        PChGtheta_lapse_new = PChGtheta_lapse .* [pCongruentGcwTh; pCongruentGccwTh];
        PChGtheta_lapse_new = PChGtheta_lapse_new ./ repmat(sum(PChGtheta_lapse_new, 1), 2, 1);

        % modify the estimate distribution p(thetaHat|theta, Chat, Congrudent)
        pthhGthChccw(th'>= 0, :) = 0;
        pthhGthChcw(th'< 0, :) = 0;
    else
        PChGtheta_lapse_new = PChGtheta_lapse;
    end
    
    if incorrectType == 2
        pthhGthChcw_Incorrect = pthhGthChcw;
        pthhGthChccw_Incorrect = pthhGthChccw;
        
        % remove correct trials
        pthhGthChcw_Incorrect(:, thetaStim > 0) = 0;                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          hcw(:, thetaStim < 0) = 0;
        pthhGthChccw_Incorrect(:, thetaStim < 0) = 0;
        
        % flip the estimate
        pthhGthChcw_Incorrect = flipud(pthhGthChcw_Incorrect);
        pthhGthChccw_Incorrect = flipud(pthhGthChccw_Incorrect);
    end
    
    % remove incorrect trials
    pthhGthChcw(:, thetaStim < 0) = 0;                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          hcw(:, thetaStim < 0) = 0;
    pthhGthChccw(:, thetaStim > 0) = 0;
    
    
    pthhGthChcw_norm = pthhGthChcw./repmat(sum(pthhGthChcw,1),nth,1); 
    pthhGthChccw_norm = pthhGthChccw./repmat(sum(pthhGthChccw,1),nth,1);
    mthhGthChcw_correct = th * pthhGthChcw_norm;
    mthhGthChccw_correct = th * pthhGthChccw_norm;
    mthhGthChcw_correct(thetaStim < 0) = NaN;
    mthhGthChccw_correct(thetaStim > 0) = NaN;
    pthhGthChcw_norm(isnan(pthhGthChcw_norm)) = 0;    
    pthhGthChccw_norm(isnan(pthhGthChccw_norm)) = 0;
    
    pthhANDth_correct = pthhGthChcw_norm.*repmat(PChGtheta_lapse(1,:),nth,1) + pthhGthChccw_norm.*repmat(PChGtheta_lapse(2,:),nth,1);
    pthhANDth_correct(:, thetaStim == 0) = pthhANDth_correct(:, thetaStim == 0) /2;
    
    %% Incorrect trials  
    if incorrectType == 1
        pmmGth = exp(-((MM_th-THmm).^2)./(2*(stdSensory(kk)^2 + stdMemoryIncorrect^2))); % p(mm|th) = N(th, sm^2 + smm^2)
        pmmGth = pmmGth./(repmat(sum(pmmGth,1),nmm,1)); 
        
        pthGmmChcw = (pmmGth.*repmat(pthGC(2,:),nmm,1))';
        pthGmmChcw = pthGmmChcw./repmat(sum(pthGmmChcw,1),nth,1);
        pthGmmChcw(isnan(pthGmmChcw)) = 0;

        pthGmmChccw = (pmmGth.*repmat(pthGC(1,:),nmm,1))';
        pthGmmChccw = pthGmmChccw./repmat(sum(pthGmmChccw,1),nth,1);
        pthGmmChccw(isnan(pthGmmChccw)) = 0;

        EthChcw = th * pthGmmChcw;
        EthChccw = th * pthGmmChccw;
        % discard repeating/decreasing values (required for interpolation) 
        indKeepCw = 1:length(EthChcw);
        while sum(diff(EthChcw)<=0) >0
            indDiscardCw = [false diff(EthChcw)<=0];
            EthChcw(indDiscardCw) = [];
            indKeepCw(indDiscardCw) = [];
        end
        indKeepCcw = 1:length(EthChccw);
        while sum(diff(EthChccw)<=0) >0
            indDiscardCcw = [diff(EthChccw)<=0 false];
            EthChccw(indDiscardCcw) = [];
            indKeepCcw(indDiscardCcw) = [];
        end

        a = 1./gradient(EthChcw,dstep);
        % memory noise
        pmmGm = exp(-((MM_m-repmat(m, nmm, 1)).^2)./(2*stdMemoryIncorrect^2)); 
        pmmGm = pmmGm./(repmat(sum(pmmGm,1),nmm,1));   

        % attention marginalization: compute distribution only over those ms that lead to cw decision!
        pmmGthChcw = pmmGm * (pmGth(:, ismember(th, thetaStim)).*repmat(PChGm(1,:)',1,length(thetaStim)));
        b = repmat(a',1,length(thetaStim)) .* pmmGthChcw(indKeepCw, :);        

        pthhGthChcw = interp1(EthChcw,b,th,'linear','extrap');
        % add motor noise
        pthhGthChcw = conv2(pthhGthChcw,pdf('norm',th,0,stdMotor)','same');
        pthhGthChcw(pthhGthChcw < 0) = 0; 

        a = 1./gradient(EthChccw,dstep);
        % attention marginalization: compute distribution only over those ms that lead to cw decision!
        pmmGthChccw = pmmGm * (pmGth(:, ismember(th, thetaStim)).*repmat(PChGm(2,:)',1,length(thetaStim)));        
        b = repmat(a',1,length(thetaStim)) .* pmmGthChccw(indKeepCcw, :);        
        pthhGthChccw = interp1(EthChccw,b,th,'linear','extrap');
        % add motor noise
        pthhGthChccw = conv2(pthhGthChccw,pdf('norm',th,0,stdMotor)','same');
        pthhGthChccw(pthhGthChccw < 0) = 0; 
        pthhGthChcw = pthhGthChcw./repmat(sum(pthhGthChcw,1),nth,1); % normalize - conv2 is not    
        pthhGthChccw = pthhGthChccw./repmat(sum(pthhGthChccw,1),nth,1);            

        if includeIncongruentTrials == 0
            % modify the estimate distribution p(thetaHat|theta, Chat, Congrudent)
            pthhGthChccw(th'<= 0, :) = 0;
            pthhGthChcw(th'> 0, :) = 0;
        end

        % remove 'correct' trials
        pthhGthChcw(:, thetaStim > 0) = 0;                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          hcw(:, thetaStim < 0) = 0;
        pthhGthChccw(:, thetaStim < 0) = 0;
    elseif incorrectType == 2
        pthhGthChcw = pthhGthChcw_Incorrect;
        pthhGthChccw = pthhGthChccw_Incorrect;
    elseif incorrectType == 3
        % Measurement m is degraded by memory noise p(mm|th, Chat) = p(mm|th) = N(th, sm^2 + smm^2)           
        pmrGth = exp(-((MR_th-THmr).^2)./(2*(stdSensory(kk)^2 + stdMemory^2)));
        pmrGth = pmrGth./(repmat(sum(pmrGth,1),nmr,1)); 

        pthGmrChcw = (pmrGth.*repmat(pthGC(2,:),nmr,1))';
        pthGmrChcw = pthGmrChcw./repmat(sum(pthGmrChcw,1),nth,1);
        pthGmrChcw(isnan(pthGmrChcw)) = 0;

        pthGmrChccw = (pmrGth.*repmat(pthGC(1,:),nmr,1))';
        pthGmrChccw = pthGmrChccw./repmat(sum(pthGmrChccw,1),nth,1);
        pthGmrChccw(isnan(pthGmrChccw)) = 0;

        EthChcw = th * pthGmrChcw;
        EthChccw = th * pthGmrChccw;
        % discard repeating/decreasing values (required for interpolation) 
        indKeepCw = 1:length(EthChcw);
        while sum(diff(EthChcw)<=0) >0
            indDiscardCw = [false diff(EthChcw)<=0];
            EthChcw(indDiscardCw) = [];
            indKeepCw(indDiscardCw) = [];
        end
        indKeepCcw = 1:length(EthChccw);
        while sum(diff(EthChccw)<=0) >0
            indDiscardCcw = [diff(EthChccw)<=0 false];
            EthChccw(indDiscardCcw) = [];
            indKeepCcw(indDiscardCcw) = [];
        end

        % Resample mm until we have a sample that is consistent with feedback
        % p(mr|mm, theta, Chat)
        pmrGmmth = exp(-((MR_mm-repmat(mm, nmr, 1)).^2)./(2*(stdSensory(kk)^2 + stdMemory^2))); 

        pmrGmmthChcw = pmrGmmth;
        pmrGmmthChcw(mr > 0, :) = 0;
        pmrGmmthChcw = pmrGmmthChcw./(repmat(sum(pmrGmmthChcw,1),nmr,1));

        pmrGmmthChccw = pmrGmmth;
        pmrGmmthChccw(mr < 0, :) = 0;
        pmrGmmthChccw = pmrGmmthChccw./(repmat(sum(pmrGmmthChccw,1),nmr,1));

        % Marginalize over mm that lead to cw decision to compute likelihood p(mr|theta, Chat)
        pmrGthChcw = pmrGmmthChcw * pmmGthChcw;   
        pmrGthChcw = pmrGthChcw ./ (repmat(sum(pmrGthChcw,1),nmr,1)); 
        pmrGthChcw(isnan(pmrGthChcw)) = 0;

        pmrGthChccw = pmrGmmthChccw * pmmGthChccw;
        pmrGthChccw = pmrGthChccw ./ (repmat(sum(pmrGthChccw,1),nmr,1)); 
        pmrGthChccw(isnan(pmrGthChccw)) = 0;

        a = 1./gradient(EthChcw,dstep);
        b = repmat(a',1,length(thetaStim)) .* pmrGthChcw(indKeepCw, :);        

        pthhGthChcw = interp1(EthChcw,b,th,'linear','extrap');
        % add motor noise
        pthhGthChcw = conv2(pthhGthChcw,pdf('norm',th,0,stdMotor)','same');
        pthhGthChcw(pthhGthChcw < 0) = 0; 

        a = 1./gradient(EthChccw,dstep);
        b = repmat(a',1,length(thetaStim)) .* pmrGthChccw(indKeepCcw, :);        
        pthhGthChccw = interp1(EthChccw,b,th,'linear','extrap');
        % add motor noise
        pthhGthChccw = conv2(pthhGthChccw,pdf('norm',th,0,stdMotor)','same');
        pthhGthChccw(pthhGthChccw < 0) = 0; 

        pthhGthChcw = pthhGthChcw./repmat(sum(pthhGthChcw,1),nth,1); % normalize - conv2 is not    
        pthhGthChccw = pthhGthChccw./repmat(sum(pthhGthChccw,1),nth,1);            

        if includeIncongruentTrials == 0
            % modify the estimate distribution p(thetaHat|theta, Chat, Congrudent)
            pthhGthChccw(th'<= 0, :) = 0;
            pthhGthChcw(th'> 0, :) = 0;
        end

        % remove 'correct' trials
        pthhGthChcw(:, thetaStim > 0) = 0;                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          hcw(:, thetaStim < 0) = 0;
        pthhGthChccw(:, thetaStim < 0) = 0; 
    elseif incorrectType == 4
        pthhGthChcw = repmat(normpdf(th', pthccw/2, stdMotor), 1, length(thetaStim));
        pthhGthChcw = pthhGthChcw./repmat(sum(pthhGthChcw,1),nth,1);   
        pthhGthChcw = pthhGthChcw  .* repmat(PChGtheta_lapse(1,:),nth,1);

        pthhGthChccw = repmat(normpdf(th', pthcw/2, stdMotor), 1, length(thetaStim)) .* repmat(PChGtheta_lapse(2,:),nth,1); 
        pthhGthChccw = pthhGthChccw./repmat(sum(pthhGthChccw,1),nth,1); 
        pthhGthChccw =  pthhGthChccw .* repmat(PChGtheta_lapse(2,:),nth,1); 
           

        if includeIncongruentTrials == 0
            % modify the estimate distribution p(thetaHat|theta, Chat, Congrudent)
            pthhGthChccw(th'<= 0, :) = 0;
            pthhGthChcw(th'> 0, :) = 0;
        end

        % remove 'correct' trials
        pthhGthChcw(:, thetaStim > 0) = 0;                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          hcw(:, thetaStim < 0) = 0;
        pthhGthChccw(:, thetaStim < 0) = 0;   
    elseif incorrectType == 4
        
    end
    pthhGthChcw_norm = pthhGthChcw./repmat(sum(pthhGthChcw,1),nth,1);    
    pthhGthChccw_norm = pthhGthChccw./repmat(sum(pthhGthChccw,1),nth,1);            
    mthhGthChcw_incorrect = th * pthhGthChcw_norm;
    mthhGthChccw_incorrect = th * pthhGthChccw_norm;
    mthhGthChcw_incorrect(thetaStim > 0) = NaN;
    mthhGthChccw_incorrect(thetaStim < 0) = NaN;
    pthhGthChcw_norm(isnan(pthhGthChcw_norm)) = 0;    
    pthhGthChccw_norm(isnan(pthhGthChccw_norm)) = 0;
    

    pthhANDth_incorrect = pthhGthChcw_norm.*repmat(PChGtheta_lapse(1,:),nth,1) + pthhGthChccw_norm.*repmat(PChGtheta_lapse(2,:),nth,1);
    pthhANDth_incorrect(:, thetaStim == 0) = pthhANDth_incorrect(:, thetaStim == 0)/2;
    
    %% plot
    showrange = [min(thetaStim) max(thetaStim)];
    ind = find(thetaStim >= showrange(1) & thetaStim <= showrange(2));
    nthshow = length(ind);

    subplot(2,3,1);
    pthres = 0.075;
    ind = find(PChGtheta_lapse_new(1,:)>pthres);
    plot(thetaStim(ind),mthhGthChcw_correct(ind),'c-','linewidth',2);
    hold on;
    ind = find(PChGtheta_lapse_new(2,:)>pthres);
    plot(thetaStim(ind),mthhGthChccw_correct(ind),'g-','linewidth',2);
    axis([showrange(1) showrange(2) -40 40]);
    if kk==1
        plot(thetaStim,zeros(1,length(thetaStim)),'k:');
        plot([-40 40],[-40 40],'k--');
        plot([0 0],[-40 40],'k:');
    end
    
    subplot(2,3,1+kk);
    pthhANDth_correct = max(pthhANDth_correct(:)) - pthhANDth_correct;
    xRange = [min(thetaStim) max(thetaStim)];
    indX = find(thetaStim >= xRange(1) & thetaStim <= xRange(2));
    xMax = length(indX);
    xZero = find(thetaStim == 0);
    xDisplay = -10:10:30;
    xTick = find(ismember(thetaStim, xDisplay));
    yRange = [-40 40];
    indY = find(th >= yRange(1) & th <= yRange(2));
    yMax = length(indY);
    thNew = th(indY);
    indYStart = find(thNew == xRange(1));
    indYEnd = find(thNew == xRange(2));
    imagesc(pthhANDth_correct(indY, indX));
    hold on;
    axis xy;
    colormap('gray');
    plot([1 xMax],[round(yMax/2) round(yMax/2)],'k:', 'LineWidth', 1);
    plot([xZero xZero],[1 yMax],'k:', 'LineWidth', 1);
    plot([1 xMax],[indYStart indYEnd],'b:', 'LineWidth', 1.5);
    set(gca, 'ylim', [1 yMax], 'xlim', [1 xMax], ...
        'XTick', xTick, 'XTickLabel', num2cell(xDisplay),...
        'YTick', round(linspace(1,yMax,5)), 'YTickLabel', num2cell(round(linspace(yRange(1),yRange(2),5))), ...
        'FontSize', 20)
    
    
    subplot(2,3,4+kk);
    pthhANDth_incorrect = max(pthhANDth_incorrect(:)) - pthhANDth_incorrect;
    xRange = [min(thetaStim) max(thetaStim)];
    indX = find(thetaStim >= xRange(1) & thetaStim <= xRange(2));
    xMax = length(indX);
    yRange = [-40 40];
    indY = find(th >= yRange(1) & th <= yRange(2));
    yMax = length(indY);
    thNew = th(indY);
    indYStart = find(thNew == xRange(1));
    indYEnd = find(thNew == xRange(2));
    imagesc(pthhANDth_incorrect(indY, indX));
    hold on;
    axis xy;
    colormap('gray');
    plot([1 xMax],[round(yMax/2) round(yMax/2)],'k:', 'LineWidth', 1);
    plot([xZero xZero],[1 yMax],'k:', 'LineWidth', 1);
    plot([1 xMax],[indYStart indYEnd],'b:', 'LineWidth', 1.5);
    set(gca, 'ylim', [1 yMax], 'xlim', [1 xMax], ...
        'XTick', xTick, 'XTickLabel', num2cell(xDisplay),...
        'YTick', round(linspace(1,yMax,5)), 'YTickLabel', num2cell(round(linspace(yRange(1),yRange(2),5))), ...
        'FontSize', 20)


    subplot(2,3,4);
    pthres = 0.000075;
    ind = find(PChGtheta_lapse_new(1,:)>pthres);
    plot(thetaStim(ind),mthhGthChcw_incorrect(ind),'c-','linewidth',2);
    hold on;
    ind = find(PChGtheta_lapse_new(2,:)>pthres);
    plot(thetaStim(ind),mthhGthChccw_incorrect(ind),'g-','linewidth',2);
    axis([showrange(1) showrange(2) yRange(1) yRange(2)]);
    if kk==1
        plot(thetaStim,zeros(1,length(thetaStim)),'k:');
        plot([yRange(1) yRange(2)],[yRange(1) yRange(2)],'k--');
        plot([0 0],[yRange(1) yRange(2)],'k:');
    end
end
