%%% Conditional observer model with memory recall and motor noise
%%% Contain both no-resample and resample versions of correct and incorrect trials
flagSC = 1; % 1: self-conditioned model
           % 0: standard Bayes
includeIncongruentTrials = 0;
correctType = 1; % 1: no resampling
                 % 2: resampling (center m, variance: memory)
                 % 3: no resampling, noise model, m_m sampled from N(theta, sigma_combined)
incorrectType = 12; % 1: flip the decision bit
                   % 2: flip the estimates
                   % 3: resample mm, centered on mm, variance: sensory+memory
                   % 4: resample m, centered on m, variance: sensory+memory
                   % 5: lose all information and use prior to make estimate
                   % 6: set new likelihood center at the boundary
                   % 7: resample m, centered on m, variance: memory
                   % 8: resample m, centered on m, variance: sensory+memory, No rejection on incorrect side
                   % 9: flip likelihood after conditioning p(mm|theta, Chat)
                   % 10: set new likelihood center at the estimate
                   % 11: weight LH width by confidence (KL, multiplicative)
                   % 12: uncertainty only, estimate at std sensory
dstep = 0.1;
paramsAll = [5.1033   10.3703           0.0000     46.6421     4.7921   0.8187    3.3313    0.0000];
lapseRate = paramsAll(3);

% stimulus orientation
thetaStim = -22:0.1:22; % 
thetaStim = round(thetaStim*(1/dstep))/(1/dstep);

% sensory noise
stdSensory = paramsAll(1:2);

% memory recall noise
stdMemory = paramsAll(5);

% motor noise;
stdMotor = paramsAll(7);

% priors
smoothFactor = paramsAll(6);

%% LOOP - noise levels
pC = [0.5, 0.5]'; % [cw ccw]
pthcw = paramsAll(4);
pthccw = -paramsAll(4); % paramsAll(4)

rangeth = [-60 60];
th = rangeth(1):dstep:rangeth(2);
th = round(th*(1/dstep))/(1/dstep);
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

pth_erased = zeros(2,nth);
pth_erased(1, th >= 0) = 1;
pth_erased(2, th < 0) = 1;

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
    if correctType == 1
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
    elseif correctType == 2
        pmrGth = exp(-((MR_th-THmr).^2)./(2*(stdSensory(kk)^2 + stdMemory^2)));
        pmrGth = pmrGth./(repmat(sum(pmrGth,1),nmr,1)); 
        pthGmrChcw = (pmrGth.*repmat(pthGC(1,:),nmr,1))';
        pthGmrChcw = pthGmrChcw./repmat(sum(pthGmrChcw,1),nth,1);
        pthGmrChcw(isnan(pthGmrChcw)) = 0;

        pthGmrChccw = (pmrGth.*repmat(pthGC(2,:),nmr,1))';
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

        % Resample m until we have a sample that is consistent with feedback
        % p(mr|m, theta, Chat)
        MR_m = repmat(mr', 1, nm);
        pmrGmth = exp(-((MR_m-repmat(m, nmr, 1)).^2)./(2*(stdMemory^2))); 

        pmrGmthChcw = pmrGmth;
        pmrGmthChcw(mr < 0, :) = 0;
        % put the tail with all 0 to 1 (deal with small memory noise)
        indZero = sum(pmrGmthChcw, 1) == 0;
        pmrGmthChcw(mr > 0, indZero) = 1;
        pmrGmthChcw = pmrGmthChcw./(repmat(sum(pmrGmthChcw,1),nmr,1));
        pmrGmthChcw(mr > 0, indZero) = 1e-50;

        pmrGmthChccw = pmrGmth;
        pmrGmthChccw(mr > 0, :) = 0;
        % put the tail with all 0 to 1 (deal with small memory noise)
        indZero = sum(pmrGmthChccw, 1) == 0;
        pmrGmthChccw(mr < 0, indZero) = 1;        
        pmrGmthChccw = pmrGmthChccw./(repmat(sum(pmrGmthChccw,1),nmr,1));
        pmrGmthChccw(mr < 0, indZero) = 1e-50;

        % Marginalize over m that lead to cw/ccw decision to compute likelihood p(mr|theta, Chat)
        pmGthChcw = pmGth(:, ismember(th, thetaStim)).*repmat(PChGm(1,:)',1,length(thetaStim));
        pmrGthChcw = pmrGmthChcw * pmGthChcw;   
        pmrGthChcw = pmrGthChcw ./ (repmat(sum(pmrGthChcw,1),nmr,1)); 
        pmrGthChcw(isnan(pmrGthChcw)) = 0;

        pmGthChccw = pmGth(:, ismember(th, thetaStim)).*repmat(PChGm(2,:)',1,length(thetaStim));
        pmrGthChccw = pmrGmthChccw * pmGthChccw;
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
    elseif correctType == 3
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
        pmmGthChcw = pmmGth(:, ismember(th, thetaStim));
        b = repmat(a',1,length(thetaStim)) .* pmmGthChcw(indKeepCw, :);        
        pthhGthChcw = interp1(EthChcw,b,th,'linear','extrap');
        % add motor noise
        pthhGthChcw = conv2(pthhGthChcw,pdf('norm',th,0,stdMotor)','same');
        pthhGthChcw(pthhGthChcw < 0) = 0; 

        a = 1./gradient(EthChccw,dstep);
        % attention marginalization: compute distribution only over those ms that lead to cw decision!
        pmmGthChccw = pmmGthChcw;        
        b = repmat(a',1,length(thetaStim)) .* pmmGthChccw(indKeepCcw, :);        
        pthhGthChccw = interp1(EthChccw,b,th,'linear','extrap');
        % add motor noise
        pthhGthChccw = conv2(pthhGthChccw,pdf('norm',th,0,stdMotor)','same');
        pthhGthChccw(pthhGthChccw < 0) = 0;         
    end
    
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
        pmmGth = exp(-((MM_th-THmm).^2)./(2*(stdSensory(kk)^2 + stdMemory^2))); % p(mm|th) = N(th, sm^2 + smm^2)
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
        pmmGm = exp(-((MM_m-repmat(m, nmm, 1)).^2)./(2*stdMemory^2)); 
        pmmGm = pmmGm./(repmat(sum(pmmGm,1),nmm,1));   

        % attention marginalization: compute distribution only over those ms that lead to cw decision!
        if correctType == 3
            pmmGthChcw = pmmGth(:, ismember(th, thetaStim));
        else
            pmmGthChcw = pmmGm * (pmGth(:, ismember(th, thetaStim)).*repmat(PChGm(1,:)',1,length(thetaStim)));
        end
        b = repmat(a',1,length(thetaStim)) .* pmmGthChcw(indKeepCw, :);        

        pthhGthChcw = interp1(EthChcw,b,th,'linear','extrap');
        % add motor noise
        pthhGthChcw = conv2(pthhGthChcw,pdf('norm',th,0,stdMotor)','same');
        pthhGthChcw(pthhGthChcw < 0) = 0; 

        a = 1./gradient(EthChccw,dstep);
        % attention marginalization: compute distribution only over those ms that lead to cw decision!
        if correctType == 3
            pmmGthChccw = pmmGthChcw;
        else
            pmmGthChccw = pmmGm * (pmGth(:, ismember(th, thetaStim)).*repmat(PChGm(2,:)',1,length(thetaStim)));   
        end
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
        % Likelihood function the same as correct decision p(mm|th) = N(th, sm^2 + smm^2)           
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

        % Resample m until we have a sample that is consistent with feedback
        % p(mr|m, theta, Chat)
        MR_m = repmat(mr', 1, nm);
        pmrGmth = exp(-((MR_m-repmat(m, nmr, 1)).^2)./(2*(stdSensory(kk)^2 + stdMemory^2))); 

        pmrGmthChcw = pmrGmth;
        pmrGmthChcw(mr > 0, :) = 0;
        pmrGmthChcw = pmrGmthChcw./(repmat(sum(pmrGmthChcw,1),nmr,1));

        pmrGmthChccw = pmrGmth;
        pmrGmthChccw(mr < 0, :) = 0;
        pmrGmthChccw = pmrGmthChccw./(repmat(sum(pmrGmthChccw,1),nmr,1));

        % Marginalize over m that lead to cw/ccw decision to compute likelihood p(mr|theta, Chat)
        pmGthChcw = pmGth(:, ismember(th, thetaStim)).*repmat(PChGm(1,:)',1,length(thetaStim));
        pmrGthChcw = pmrGmthChcw * pmGthChcw;   
        pmrGthChcw = pmrGthChcw ./ (repmat(sum(pmrGthChcw,1),nmr,1)); 
        pmrGthChcw(isnan(pmrGthChcw)) = 0;

        pmGthChccw = pmGth(:, ismember(th, thetaStim)).*repmat(PChGm(2,:)',1,length(thetaStim));
        pmrGthChccw = pmrGmthChccw * pmGthChccw;
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
        pthhGthChcw(:, thetaStim > 0) = 0;                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         
        pthhGthChccw(:, thetaStim < 0) = 0;         
    elseif incorrectType == 5
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
        pthhGthChcw(:, thetaStim > 0) = 0;                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         
        pthhGthChccw(:, thetaStim < 0) = 0; 
    elseif incorrectType == 6
        % Compute the estimate
        pthGmm = normpdf(th, 0, sqrt(stdSensory(kk)^2 + stdMemory^2));
        pthGmmChcw = pthGmm;
        pthGmmChcw(th<0) = 0;
        pthGmmChcw = pthGmmChcw / sum(pthGmmChcw);
        thhChcw = th * pthGmmChcw';
        
        pthhGthChcw = repmat(normpdf(th', -thhChcw, stdMotor), 1, length(thetaStim));
        pthhGthChcw = pthhGthChcw./repmat(sum(pthhGthChcw,1),nth,1);   
        pthhGthChcw = pthhGthChcw  .* repmat(PChGtheta_lapse(1,:),nth,1);

        pthhGthChccw = repmat(normpdf(th', thhChcw, stdMotor), 1, length(thetaStim)) .* repmat(PChGtheta_lapse(2,:),nth,1); 
        pthhGthChccw = pthhGthChccw./repmat(sum(pthhGthChccw,1),nth,1); 
        pthhGthChccw =  pthhGthChccw .* repmat(PChGtheta_lapse(2,:),nth,1); 
           

        if includeIncongruentTrials == 0
            % modify the estimate distribution p(thetaHat|theta, Chat, Congrudent)
            pthhGthChccw(th'<= 0, :) = 0;
            pthhGthChcw(th'> 0, :) = 0;
        end

        % remove 'correct' trials
        pthhGthChcw(:, thetaStim > 0) = 0;                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         
        pthhGthChccw(:, thetaStim < 0) = 0;   
    elseif incorrectType == 7
        % Likelihood function the same as correct decision p(mm|th) = N(th, sm^2 + smm^2)           
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

        % Resample m until we have a sample that is consistent with feedback
        % p(mr|m, theta, Chat)
        MR_m = repmat(mr', 1, nm);
        pmrGmth = exp(-((MR_m-repmat(m, nmr, 1)).^2)./(2*(stdMemory^2))); 

        pmrGmthChcw = pmrGmth;
        pmrGmthChcw(mr > 0, :) = 0;
        % put the tail with all 0 to 1 (deal with small memory noise)
        indZero = sum(pmrGmthChcw, 1) == 0;
        pmrGmthChcw(mr < 0, indZero) = 1;
        pmrGmthChcw = pmrGmthChcw./(repmat(sum(pmrGmthChcw,1),nmr,1));
        pmrGmthChcw(mr < 0, indZero) = 1e-50;

        pmrGmthChccw = pmrGmth;
        pmrGmthChccw(mr < 0, :) = 0;
        % put the tail with all 0 to 1 (deal with small memory noise)
        indZero = sum(pmrGmthChccw, 1) == 0;
        pmrGmthChccw(mr > 0, indZero) = 1;        
        pmrGmthChccw = pmrGmthChccw./(repmat(sum(pmrGmthChccw,1),nmr,1));
        pmrGmthChccw(mr > 0, indZero) = 1e-50;

        % Marginalize over m that lead to cw/ccw decision to compute likelihood p(mr|theta, Chat)
        pmGthChcw = pmGth(:, ismember(th, thetaStim)).*repmat(PChGm(1,:)',1,length(thetaStim));
        pmrGthChcw = pmrGmthChcw * pmGthChcw;   
        pmrGthChcw = pmrGthChcw ./ (repmat(sum(pmrGthChcw,1),nmr,1)); 
        pmrGthChcw(isnan(pmrGthChcw)) = 0;

        pmGthChccw = pmGth(:, ismember(th, thetaStim)).*repmat(PChGm(2,:)',1,length(thetaStim));
        pmrGthChccw = pmrGmthChccw * pmGthChccw;
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
        pthhGthChcw(:, thetaStim > 0) = 0;                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          
        pthhGthChccw(:, thetaStim < 0) = 0;      
    elseif incorrectType == 8
        pmmGth = exp(-((MM_th-THmm).^2)./(2*(stdSensory(kk)^2 + stdMemory^2))); % p(mm|th) = N(th, sm^2 + smm^2)
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
        pmmGm = exp(-((MM_m-repmat(m, nmm, 1)).^2)./(2*(stdSensory(kk)^2 + stdMemory^2))); 
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
        pthhGthChcw(:, thetaStim > 0) = 0;                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         
        pthhGthChccw(:, thetaStim < 0) = 0; 
    elseif incorrectType == 9
        pmmGth = exp(-((MM_th-THmm).^2)./(2*(stdSensory(kk)^2 + stdMemory^2))); % p(mm|th) = N(th, sm^2 + smm^2)
        pmmGth = pmmGth./(repmat(sum(pmmGth,1),nmm,1)); 

        pmmGthChcw = pmmGth.*repmat(pth_erased(1,:),nmm,1);
        pmmGthChcw_flip = fliplr(pmmGthChcw);
        pthGmmChcw = (pmmGthChcw_flip.*repmat(pthGC(2,:),nmm,1))';
        pthGmmChcw = pthGmmChcw./repmat(sum(pthGmmChcw,1),nth,1);
        pthGmmChcw(isnan(pthGmmChcw)) = 0;
        
        pmmGthChccw = pmmGth.*repmat(pth_erased(2,:),nmm,1);
        pmmGthChccw_flip = fliplr(pmmGthChccw);
        pthGmmChccw = (pmmGthChccw_flip.*repmat(pthGC(1,:),nmm,1))';
        pthGmmChccw = pthGmmChccw./repmat(sum(pthGmmChccw,1),nth,1);
        pthGmmChccw(isnan(pthGmmChccw)) = 0;

        EthChcw = th * pthGmmChcw;
        EthChccw = th * pthGmmChccw;
        % discard repeating/decreasing values (required for interpolation) 
        indKeepCw = 1:length(EthChcw);
        while sum(diff(EthChcw)>=0) >0
            indDiscardCw = [false diff(EthChcw)>=0];
            EthChcw(indDiscardCw) = [];
            indKeepCw(indDiscardCw) = [];
        end
        indKeepCcw = 1:length(EthChccw);
        while sum(diff(EthChccw)>=0) >0
            indDiscardCcw = [diff(EthChccw)>=0 false];
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
        pthhGthChcw(pthhGthChcw > 0) = 0; 

        a = 1./gradient(EthChccw,dstep);
        % attention marginalization: compute distribution only over those ms that lead to cw decision!
        pmmGthChccw = pmmGm * (pmGth(:, ismember(th, thetaStim)).*repmat(PChGm(2,:)',1,length(thetaStim)));        
        b = repmat(a',1,length(thetaStim)) .* pmmGthChccw(indKeepCcw, :);        
        pthhGthChccw = interp1(EthChccw,b,th,'linear','extrap');
        % add motor noise
        pthhGthChccw = conv2(pthhGthChccw,pdf('norm',th,0,stdMotor)','same');
        pthhGthChccw(pthhGthChccw > 0) = 0; 
        pthhGthChcw = pthhGthChcw./repmat(sum(pthhGthChcw,1),nth,1); % normalize - conv2 is not    
        pthhGthChccw = pthhGthChccw./repmat(sum(pthhGthChccw,1),nth,1);            

        if includeIncongruentTrials == 0
            % modify the estimate distribution p(thetaHat|theta, Chat, Congrudent)
            pthhGthChccw(th'<= 0, :) = 0;
            pthhGthChcw(th'> 0, :) = 0;
        end

        % remove 'correct' trials
        pthhGthChcw(:, thetaStim > 0) = 0;                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        
        pthhGthChccw(:, thetaStim < 0) = 0;
    elseif incorrectType == 10
        %% Inference: p(thetaHat|mr, cHat) = N(th, sm^2 + smm^2)           
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
        

        %% Get the distribution of LH center p(mr| theta, Chat) = p(thetaHat_temp|theta, Chat)
        % memory noise
        pmmGm = exp(-((MM_m-repmat(m, nmm, 1)).^2)./(2*stdMemory^2)); 
        pmmGm = pmmGm./(repmat(sum(pmmGm,1),nmm,1)); 
        
        a = 1./gradient(EthChcw,dstep);
        % attention marginalization: compute distribution only over those ms that lead to cw decision!
        pmmGthChcw = pmmGm * (pmGth(:, ismember(th, thetaStim)).*repmat(PChGm(1,:)',1,length(thetaStim)));
        b = repmat(a',1,length(thetaStim)) .* pmmGthChcw(indKeepCw, :);        
        pmrGthChcw = interp1(EthChcw,b,th,'linear','extrap');
        pmrGthChcw(pmrGthChcw < 0) = 0; 

        a = 1./gradient(EthChccw,dstep);
        % attention marginalization: compute distribution only over those ms that lead to cw decision!
        pmmGthChccw = pmmGm * (pmGth(:, ismember(th, thetaStim)).*repmat(PChGm(2,:)',1,length(thetaStim)));        
        b = repmat(a',1,length(thetaStim)) .* pmmGthChccw(indKeepCcw, :);        
        pmrGthChccw = interp1(EthChccw,b,th,'linear','extrap');
        pmrGthChccw(pmrGthChccw < 0) = 0; 

        %% Marginalize over the LH center to get the predictive distribution p(thetaHat|theta, Chat)
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
        pthhGthChcw(:, thetaStim > 0) = 0;
        pthhGthChccw(:, thetaStim < 0) = 0;   
    elseif incorrectType == 11
        % Scale the LH width by KL divergence
        log_base = 3;        
        scale_factor = PCGm(2,:).*(log2(PCGm(2,:)./PCGm(1,:)) / log2(log_base)) + PCGm(1,:).*(log2(PCGm(1,:)./PCGm(2,:)) / log2(log_base));
        stdSensory_scale = sqrt(1+ scale_factor) * stdSensory(kk);
        pmGth = exp(-((M-THm).^2)./(2*stdSensory_scale.^2)');
    
        pmmGm = exp(-((MM_m-repmat(m, nmm, 1)).^2)./(2*stdMemory^2)); 
        pmmGm = pmmGm./(repmat(sum(pmmGm,1),nmm,1));   
        pmmGth = pmmGm * pmGth;
        
        pthGmmChcw = (pmmGth.*repmat(pthGC(2,:),nmm,1))';
        pthGmmChcw = pthGmmChcw./repmat(sum(pthGmmChcw,1),nth,1);
        pthGmmChcw(isnan(pthGmmChcw)) = 0;

        pthGmmChccw = (pmmGth.*repmat(pthGC(1,:),nmm,1))';
        pthGmmChccw = pthGmmChccw./repmat(sum(pthGmmChccw,1),nth,1);
        pthGmmChccw(isnan(pthGmmChccw)) = 0;

        EthChcw = th * pthGmmChcw;
        EthChccw = th * pthGmmChccw;
        % discard the correct part
        indKeepCw = find(mm>=0);      
        EthChcw = EthChcw(indKeepCw);
        while (sum(diff(EthChcw)>=0) > 0) 
            indDiscardCw = [false (diff(EthChcw)>=0)];
            EthChcw(indDiscardCw) = [];
            indKeepCw(indDiscardCw) = [];
        end
        
        indKeepCcw = find(mm<=0);      
        EthChccw = EthChccw(indKeepCcw);
        while sum(diff(EthChccw)>=0) >0
            indDiscardCcw = [diff(EthChccw)>=0 false];
            EthChccw(indDiscardCcw) = [];
            indKeepCcw(indDiscardCcw) = [];
        end

        a = abs(1./gradient(EthChcw,dstep));
        % memory noise
        pmmGm = exp(-((MM_m-repmat(m, nmm, 1)).^2)./(2*stdMemory^2)); 
        pmmGm = pmmGm./(repmat(sum(pmmGm,1),nmm,1));   

        % attention marginalization: compute distribution only over those ms that lead to cw decision!
        pmGth = exp(-((M-THm).^2)./(2*stdSensory(kk)^2));
        pmGth = pmGth./(repmat(sum(pmGth,1),nm,1)); 
        pmmGthChcw = pmmGm * (pmGth(:, ismember(th, thetaStim)).*repmat(PChGm(1,:)',1,length(thetaStim)));
        pmmGthChcw = pmmGthChcw./(repmat(sum(pmmGthChcw,1),nmm,1));  
        b = repmat(a',1,length(thetaStim)) .* pmmGthChcw(indKeepCw, :);        

        pthhGthChcw = interp1(EthChcw,b,th,'linear');
        pthhGthChcw(isnan(pthhGthChcw)) = 0;
        % add motor noise
        pthhGthChcw = conv2(pthhGthChcw,pdf('norm',th,0,stdMotor)','same');
        pthhGthChcw(pthhGthChcw < 0) = 0; 

        a = abs(1./gradient(EthChccw,dstep));
        % attention marginalization: compute distribution only over those ms that lead to cw decision!
        pmmGthChccw = pmmGm * (pmGth(:, ismember(th, thetaStim)).*repmat(PChGm(2,:)',1,length(thetaStim)));        
        b = repmat(a',1,length(thetaStim)) .* pmmGthChccw(indKeepCcw, :);        
        pthhGthChccw = interp1(EthChccw,b,th,'linear');
        pthhGthChccw(isnan(pthhGthChccw)) = 0;
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
        pthhGthChcw(:, thetaStim > 0) = 0;                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      
        pthhGthChccw(:, thetaStim < 0) = 0;  
    elseif incorrectType == 12
        std_combined = sqrt(stdSensory(kk)^2 + 0^2);        
        pthhGthChcw = repmat(normpdf(th', -std_combined, stdMotor), 1, length(thetaStim));
        pthhGthChcw = pthhGthChcw./repmat(sum(pthhGthChcw,1),nth,1);   
        pthhGthChcw = pthhGthChcw  .* repmat(PChGtheta_lapse(1,:),nth,1);

        pthhGthChccw = repmat(normpdf(th', std_combined, stdMotor), 1, length(thetaStim)) .* repmat(PChGtheta_lapse(2,:),nth,1); 
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
    showrange = [-21 21];
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
    xRange = [-22 22];
    indX = find(thetaStim >= xRange(1) & thetaStim <= xRange(2));
    xMax = length(indX);
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
    plot([round(xMax/2) round(xMax/2)],[1 yMax],'k:', 'LineWidth', 1);
    plot([1 xMax],[indYStart indYEnd],'b:', 'LineWidth', 1.5);
    set(gca, 'ylim', [1 yMax], 'xlim', [1 xMax], ...
        'XTick', round(linspace(1,xMax,5)), 'XTickLabel', num2cell([-22 -11 0 11 22]),...
        'YTick', round(linspace(1,yMax,5)), 'YTickLabel', num2cell(round(linspace(yRange(1),yRange(2),5))), ...
        'FontSize', 20)
    
    subplot(2,3,4+kk);
    pthhANDth_incorrect = max(pthhANDth_incorrect(:)) - pthhANDth_incorrect;
    xRange = [-22 22];
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
    plot([round(xMax/2) round(xMax/2)],[1 yMax],'k:', 'LineWidth', 1);
    plot([1 xMax],[indYStart indYEnd],'b:', 'LineWidth', 1.5);
    set(gca, 'ylim', [1 yMax], 'xlim', [1 xMax], ...
        'XTick', round(linspace(1,xMax,5)), 'XTickLabel', num2cell([-22 -11 0 11 22]),...
        'YTick', round(linspace(1,yMax,5)), 'YTickLabel', num2cell(round(linspace(yRange(1),yRange(2),5))), ...
        'FontSize', 20)
   

    subplot(2,3,4);
    pthres = 0.000075;
    ind = find(PChGtheta_lapse_new(1,:)>pthres);
    plot(thetaStim(ind),mthhGthChcw_incorrect(ind),'c-','linewidth',2);
    hold on;
    ind = find(PChGtheta_lapse_new(2,:)>pthres);
    plot(thetaStim(ind),mthhGthChccw_incorrect(ind),'g-','linewidth',2);
    axis equal
    axis([showrange(1) showrange(2) yRange(1) yRange(2)]);
    if kk==1
        plot(thetaStim,zeros(1,length(thetaStim)),'k:');
        plot([yRange(1) yRange(2)],[yRange(1) yRange(2)],'k--');
        plot([0 0],[yRange(1) yRange(2)],'k:');
    end
end
