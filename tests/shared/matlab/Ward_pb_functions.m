function fun = Ward_pb_functions
fun.Ward_pb = @Ward_pb;
fun.iMWKmeans = @iMWKmeans;
end

function [U, Z,Nk, W]=Ward_pb(Data,requiredK, p, beta, InitWithiMWK)
%Implementation of the Minkowski Weighted Ward with 2 exponents 
% 
%
% Ward_pb
% Ref:
%Amorim, R.C., Makarenkov, V., Mirkin, B., A-Wardpβ: Effective hierarchical
%clustering using the Minkowski metric and a fast k-means initialisation, 
%Information Sciences, Elsevier, Vol. 370-371, pp. 343-354, 2016.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Parameters
%Data = Data set, format: EntitiesxFeatures. The data set MUST BE already standardised
%RequiredK = Number of Clusters. If unknown you can set it to 1 and have
%the full hierarchy
%p = Minkowski Exponent p. This is a DISTANCE exponent Good values in [1:0.1:5]
%beta = Weight exponent. Good values in [1:0.1:5]
%InitWithiMWK = True/False. If true, finds a clustering from iMWK (2
%exponents) to start the agglomerative process from
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Returns:
%U: This contains the labels. 
%Format: Each column is a merge iteration. In U(:,1) each entity will have
%a different cluster index since each onf them is a different cluster. In
%U(:,2) two of these clusters will be merged. In U(:,3) Three clusters will
%be merged, etc.
%Final size: NumberOfEntities x (NumberOfEntities-requiredK+1)
%Z: This contains the final centroids. Note that the centroids will be
%located in certain rows only, the others will be marked with NaN.
%Nk: Number of entities per cluster. The index of the numbers will match
%that of the centroids in Z.
%W: Final weights. You should check the weights matching whose row numbers
%match those of the centroids in Z.


[N, M]= size(Data);
if ~exist('InitWithiMWK', 'var'), InitWithiMWK=false; end;

if InitWithiMWK
    [U_tmp, W_tmp, ~, Z_tmp] = iMWKmeans(Data, 0, p, beta, N);
    K=0;
    Z(1:N, 1:M) = NaN;
    Nk(1:N,1)=0;
    U = Nk;
    W(1:N,1:M)=NaN;
    for k = 1 : max(U_tmp)
        k_index = find(U_tmp==k,1);
        if isempty(k_index), continue; end
        Nk(k_index,1) = sum(U_tmp==k);
        Z(k_index,:) = Z_tmp(k,:);
        W(k_index,:) = W_tmp(k,:);            
        U(U_tmp==k,1)=k_index;
        K=K+1;
    end
    clear Z_tmp W_tmp U_tmp;
else
    U = (1:N)';
    K = N;
    Nk(1:N,1)=1; 
    Z = Data;
    W(1:K,1:M)=1/M;
end
   
  


UIndex=1;
while K>requiredK   
    %1st steep: look for clusters to merge
    %Calculates distances
    Dist = inf(((K^2)-K)/2,3);
    DistRowCount=1;
    for k1 = 1 : N-1
      if Nk(k1,1) == 0, continue, end;
        for k2 = k1+1 : N
            if Nk(k2,1) == 0, continue, end;
            %Uses the average of the weights
            avg_W = (W(k1,:) + W(k2,:))/2;
            Dist(DistRowCount,:) = [k1,k2,((Nk(k1,1) * Nk(k2,1)) / (Nk(k1,1) + Nk(k2,1))) * sum((abs(Z(k1,:) - Z(k2,:)).^p).*(avg_W.^beta))];
            DistRowCount = DistRowCount+1;
        end
    end
    [~,MinRow]=min(Dist(:,3));
    kMin=Dist(MinRow,1:2);
    
    %Merge clusters k1Min and k2Min
    UIndex = UIndex+1;
    [U(:,UIndex), Nk, Z, K, W] = Merge(kMin(1,1), kMin(1,2), U(:,UIndex-1), Data, Nk, M, Z,p,K, W);        
    W = GetNewW(Data,W, U(:,UIndex), Z, N, M, p, beta, Nk);
end
end

function W = GetNewW(Data,W, U, Z, K, M,p, beta, Nk)

D=zeros(K,M);
for k = 1 : K
    if Nk(k,1)==0, continue, end;
    for j = 1 : M
        D(k,j) = sum(abs(Data(U==k,j)- Z(k,j)).^p) + 0.0001;
    end
end


%Calculate the actual Weight for each feature
if beta~=1
    exp = 1/(beta-1);
    OnesVector(1,1:M) = 1;
    for k = 1 : K
        if Nk(k,1)==0, continue, end;
        for j = 1 : M
             tmp=D(k,j);
             W(k,j)= 1/sum((tmp(:, OnesVector)./D(k,:)).^exp);
        end
    end
else
    for k = 1 : K
        [~, MinIndex] = min(D(k,:));
        W(k,1:M)=0; %necessary to zero all others
        W(k,MinIndex)=1;
    end
end 
end

function [U, Nk, Z, K, W] = Merge(k1Min, k2Min, U, Data, Nk, M, Z,p,K, W)
Nk(k1Min,1)=Nk(k1Min,1)+Nk(k2Min,1);
U(U==k2Min)=k1Min;
Nk(k2Min,1)=0;
Z(k1Min,:) = New_cmt(Data(U==k1Min,:),p);
%Z(k2Min,1:M) = NaN;
%W(k2Min,1:M)=NaN;
K = K-1;
end

function [DataCenter]=New_cmt(Data,p)
%Calculates the Minkowski center at a given p.
%Data MUST BE EntityxFeatures and standardised.
[N,M]=size(Data);
if p==1
    DataCenter=median(Data,1);
    return;
elseif p==2
    DataCenter=mean(Data,1);
    return;
elseif N==1
    DataCenter=Data;
    return;
end
Gradient(1,1:M)=0.001;
OnesIndex(1:N,1)=1;
DataCenter = sum(Data,1)./N;
DistanceToDataCenter=sum(abs(Data - DataCenter(OnesIndex,:)).^p);
NewDataCenter=DataCenter+Gradient;
DistanceToNewDataCenter=sum(abs(Data - NewDataCenter(OnesIndex,:)).^p);
Gradient(1,DistanceToDataCenter < DistanceToNewDataCenter) = Gradient(1,DistanceToDataCenter < DistanceToNewDataCenter).*-1;
while true 
    NewDataCenter = DataCenter + Gradient;
    DistanceToNewDataCenter=sum(abs(Data - NewDataCenter(OnesIndex,:)).^p);  
    Gradient(1,DistanceToNewDataCenter>=DistanceToDataCenter)=Gradient(1,DistanceToNewDataCenter>=DistanceToDataCenter).*0.9;
    DataCenter(1,DistanceToNewDataCenter<DistanceToDataCenter)=NewDataCenter(1,DistanceToNewDataCenter<DistanceToDataCenter);
    DistanceToDataCenter(1,DistanceToNewDataCenter<DistanceToDataCenter)=DistanceToNewDataCenter(1,DistanceToNewDataCenter<DistanceToDataCenter);    
    if all(abs(Gradient)<0.0001), break, end;
end
end


function [U, FinalW, InitW, FinalZ, InitZ, UDistToZ,LoopCount, AnomalousLabels] = iMWKmeans(Data, ikThreshold, p, beta, MaxK)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%intelligent Minkowski Weighted K-Means
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%From:
%Amorim, R.C. and Mirkin, B., Minkowski Metric, Feature Weighting and Anomalous Cluster Initialisation in K-Means Clustering, 
%Pattern Recognition, vol. 45(3), pp. 1061-1075, 2012.
%
%Parameters:
%Data
%      Dataset, format: Entities x Features
% ikThreshold
%       The intelligent K-Means threshold (theta). If the number of
%       clusters is known set this to zero.
%p 
%      Distance and weight Exponent. 
%MaxK (optional)
%       The maximum number of clusters
%
%
%Outputs
%
%U
%      Cluster Labels. Clearly they may not directly match the dataset
%      labels (you should use a confusion matrix).
%FinalW
%      Final Weights
%InitW
%      Initial Weights
%FinalZ
%      Final Centroids
%InitZ
%      Initial Centroids
%UDistToZ
%      The distance of each entity to its centroid.
%LoopCount
%      The number of loops the algorithm took to converge. The maximum is
%      hard-coded to 500 (variable MaxLoops)
[Initial_Size_Data,N] = size(Data);
Weights = [];
QtdInCluster = [];
Centroids = []; 
EqualWeights(1,1:N)=1/N;
InitialData = Data;

%Calculates the Minkowski Centre 
MinkCentre(1,:)  = New_cmt(Data,p); 
OnesIndex=ones(Initial_Size_Data,1);
%Second Step = Sorts Data Accordint to the centre
[~, index]= sort(MinkDist(Data, MinkCentre(OnesIndex,:), p, EqualWeights.^beta,OnesIndex)); 
Data = Data(index,:);

DataLen = size(Data, 1);
Lables = zeros(DataLen,1);
Index = [1:1:DataLen]';
IData = cat(2, Index, Data);
IData = IData(index,:);

CurrentLabel = 0;
%Third Step Anomalous Patter
while ~isempty (Data)
    DataSize = size(Data,1);
    OnesIndex=ones(DataSize,1);
    TentCentroid = Data(DataSize,:); % Gets a tentative Centroid
    PreviousBelongsToCentroid=[];
    PreviousPreviousBelongsToCentroid=[];
    TentW=EqualWeights;
    LoopControl=0;
    while LoopControl<500
        %BelongsToCentroid(x,1) = True, if x is closer to the tentative
        %centroid than it is to the Minkowski Centre of the data
        BelongsToCentroid = MinkDist(Data, TentCentroid(OnesIndex,:), p, TentW.^beta,OnesIndex) < MinkDist(Data, MinkCentre(OnesIndex,:), p, TentW.^beta,OnesIndex);
        
        NewCentroid(1,:)=New_cmt(Data(BelongsToCentroid==1,:),p);
        if sum(BelongsToCentroid)==0,BelongsToCentroid(size(Data,1),1)=1;end;
        
        %Checks for stop conditions, including cycles (the latter shouldn't
        %happen)
        if isequal(TentCentroid, NewCentroid), break; end
        if isequal(BelongsToCentroid, PreviousBelongsToCentroid), break; end
        if isequal(BelongsToCentroid, PreviousPreviousBelongsToCentroid), break; end
        
        TentCentroid = NewCentroid;
        PreviousBelongsToCentroid = BelongsToCentroid;
        PreviousPreviousBelongsToCentroid = PreviousBelongsToCentroid ;
        
        TentW = GetNewW_iMWK(Data, BelongsToCentroid, NewCentroid, p, beta,N);
        LoopControl=LoopControl+1;
    end 
    if sum(BelongsToCentroid==1)> ikThreshold
        Centroids = [Centroids; NewCentroid]; %#ok<AGROW>
        Weights = [Weights; TentW]; %#ok<AGROW>    
        QtdInCluster = [QtdInCluster; sum(BelongsToCentroid)]; %#ok<AGROW>
        %NewCluster = sort(IData(BelongsToCentroid==1,1)) -1;
        Labels(IData(BelongsToCentroid==1,1)) = CurrentLabel;
        CurrentLabel = CurrentLabel + 1;
    end
    Data(BelongsToCentroid==1,:)=[];
    IData(BelongsToCentroid==1,:)=[];
end

if exist('MaxK','var')
    if size(Centroids,1)>MaxK
        [~,index] = sort(QtdInCluster,'descend');
        Centroids = Centroids(index(1:MaxK),:);
        Weights = Weights(index(1:MaxK),:);
    end
end

InitW=Weights;
InitZ=Centroids;
AnomalousLabels = Labels';

%Runs MWK-Means if the found initial values
[U, FinalW, FinalZ, UDistToZ, LoopCount, ] = MWKmeans(InitialData, size(Centroids,1), p, beta, Centroids, Weights);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% GetNewW calculates a new set of weights
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function W = GetNewW_iMWK(Data, U, Z, p, beta,N)
K=size(Z,1);
D = zeros(K,N);
W = D;
for l = 1 : K
    for j = 1 : N    
        D(l,j) = sum(abs(Data(U==l,j)- Z(l,j)).^p);
    end
end
D = D + 0.01;
%Calculate the actual Weight
%for each column
if beta~=1
    exp = 1/(beta-1);
    for l = 1 : K
        for j = 1 : N
            tmpD=D(l,j);
            W(l,j)= 1/sum((tmpD(1,ones(1,N))./D(l,:)).^exp);
        end
    end
else
    for l = 1 : K
        [~, MinIndex] = min(D(l,:));
        W(l,MinIndex)=1;
    end
end 
end

function [U, W, Z, UDistToZ, LoopCount] = MWKmeans(Data, K, p, beta, InitialCentroids, InitialW)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Minkowski Weighted K-Means
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%From:
%Amorim, R.C. and Mirkin, B., Minkowski Metric, Feature Weighting and Anomalous Cluster Initialisation in K-Means Clustering, 
%Pattern Recognition, vol. 45(3), pp. 1061-1075, 2012.
%
%Parameters:
%Data
%      Dataset, format: Entities x Features
%K
%      Total number of clusters in the dataset
%p
%      Minkowski and weight exponent 
%InitialCentroids (optional)
%      Initial centroids the algorithm should use, format: K x Features. 
%InitialW (Optional)
%      Initial set of weights the algorithm should use, format: K x
%      Features.
%
%Outputs
%
%U
%      Cluster Labels. Clearly they may not directly match the dataset
%      labels (you should use a confusion matrix).
%W
%      Final Weights
%Z
%      Final Centroids
%UDistToZ
%      The distance of each entity to its centroid.
%LoopCount
%      The number of loops the algorithm took to converge. The maximum is
%      hard-coded to 500 (variable MaxLoops)

%M Lines and N Columns
[M,N] = size(Data);
MaxLoops = 500; %just in case, shouldn't be necessary

%Binary Variable M x k, cluster label
U = zeros(M, 1);
OldU = U;

% Step 1
%Get Random Initial Centroids (VALUES) X Number of K
if exist('InitialCentroids','var')
    Z = InitialCentroids;
else
    rng(sum(100*clock));
    Z=datasample(Data,K, 'replace', false);
end

%Generate Initial set of weights
if exist('InitialW','var') 
    W = InitialW;
else
    W(1:K,1:N)=1/N;
end

LoopCount = 0;
while LoopCount<=MaxLoops
    %Step 2
    %Find Initial U that is minimized for the initials Z and W
    [NewUtp1, UDistToZ]= MWKGetNewU (Data, Z, W.^beta, p,M, K);
    %If there is no alteration in the labels stop
    if isequal(NewUtp1, U), break, end;
    
    %if the labes are equal to the previous-previous lables - stop (cycle)
    %This shouldn't happen
    if isequal(NewUtp1, OldU), break; end;
    
    %Step 3
    OldU = U;
    U = NewUtp1;
    %Get New Centroids
    Ztp1 = MWKGetNewZ(Data, U, K,p, Z);
    %If there is no alteration in the centroids stop
    if isequal(Ztp1,Z), break, end;
    Z = Ztp1;
    %Step 4
    %Update the Weights
    W = MWKGetNewW(Data, U, Z, p, beta,N, K);
    LoopCount = LoopCount + 1;
end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% GetNewU calculates the labels (clustering)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [U, UDistToZ]= MWKGetNewU (Data, Z, W, p, M, K)
temp_distances=zeros(M,K);
OnesIndex(1:M,1)=1;
%for each Centroid, gets the distance, line = entity, col = cluster
for c = 1 : K
    tmp_Z=Z(c,:);
    temp_distances(:,c) = MinkDist(Data, tmp_Z(OnesIndex,:), p, W(c,:),OnesIndex);
end
[UDistToZ, U]=min(temp_distances,[],2);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% GetNewZ calculates the centroids
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function Z = MWKGetNewZ(Data, U, K,p, OldZ)
Z = OldZ;
for l = 1 : K
    if sum(U==l)>1
        %if there isnt any entity in the cluster (shouldnt be the case!) = dont change the Z
        Z(l,:)=New_cmt(Data(U==l,:),p);
    end
end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%GetNewW calculates the new set of weights
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function W = MWKGetNewW(Data, U, Z, p, beta,N, K)
D = zeros(K,N);
W=D;
%Calculates the dispersion of each feature at each cluster
for l = 1 : K
    for j = 1 : N 
        D(l,j) = sum(abs(Data(U==l,j)- Z(l,j)).^p);
    end
end
D = D + mean(mean(D));
%Calculates the actual feature weights
if beta~=1
    exp = 1/(beta-1);
    for l = 1 : K
        for j = 1 : N
            tmpD=D(l,j);
            W(l,j)= 1/sum((tmpD(1,ones(N,1))./D(l,:)).^exp);
        end
    end
else
    for l = 1 : K
        [~, MinIndex] = min(D(l,:));
        W(l,MinIndex)=1;
    end
end 
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% MinkDist calculates the Minkowski distance between the data set x and y
% w contains the weights
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function r= MinkDist(x, y, p, w,OnesIndex)
%calculates the  Minkowski distance in between x and y
r = sum((abs(x - y).^p).*w(OnesIndex,:),2).^(1/p);
end