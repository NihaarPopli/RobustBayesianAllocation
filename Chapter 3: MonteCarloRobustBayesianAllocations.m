clear; clc; close all

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% As cited in the main report, this simulation code takes some inspiration from Meucci, Attilio (2011). “Robust Bayesian Allocation”

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% inputs
J=10000; % number of simulations
T=52;   % number of observations in time series (52 is weekly)
N=20;   % number of assets in the market
r=.4;   % overall correlation
min_s=.1; % min volatility
max_s=.4; % max volatility
NumPortf=50;
p_m=.1;  % aversion to estimation risk for mu
p_s=.1;  % aversion to estimation risk for sigma

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% true market parameters
C=(1-r)*eye(N)+r*ones(N,N);
step_s=(max_s-min_s)/(N-1);
s=[min_s : step_s : max_s];
S=diag(s)*C*diag(s);
M=2.5*S*ones(N,1)/N;

for j=1:J %for each simulation
    j
    Rets = mvnrnd(M,S,T);  %simulate returns from mvnrnd(mu,Sigma,n) distribution
    
    % sample estimate
    m_hat=mean(Rets)'; 
    S_hat=cov(Rets);
    [de_hat,ds_hat,w_hat] = EfficientFrontier(NumPortf, S_hat, m_hat); 

    % Bayesian prior
    S0=diag(diag(S_hat));
    m0=.5*S0*ones(N,1)/N;
    T=size(Rets,1);
    T0=2*T;
    nu0=2*T;

    % Bayesian posterior parameters
    T1=T+T0;
    m1=1/T1*(m_hat*T+m0*T0);
    nu1=T+nu0;
    S1=1/nu1*(S_hat*T + S0*nu0 + (m_hat-m0)*(m_hat-m0)'/(1/T+1/T0));
    [d,d,w1] = EfficientFrontier(NumPortf, S1, m1);

    % robustness parameters
    q_m2=chi2inv(p_m,N);
    g_m=sqrt(q_m2/T1*nu1/(nu1-2));
    q_s2=chi2inv(p_s,N*(N+1)/2);
    PickVol=round(.8*NumPortf);
    v=(ds_hat(PickVol))^2;
    g_s=v/(nu1/(nu1+N+1)+sqrt(2*nu1*nu1*q_s2/((nu1+N+1)^3)));
    
    
    Store(j).e=[]; %sample allocation means
    Store(j).v=[]; %sample allocation vols
    Store(j).e1=[];%Bayesian allocation means
    Store(j).v1=[];%Bayesian allocation vols
    Target=[];
    for k=1:NumPortf-1
        % cycle through the weights vectors from MV optimal portfolios obtained from sample allocation
        wu=w_hat(k,:)';
        Store(j).e=[Store(j).e M'*wu]; 
        Store(j).v=[Store(j).v wu'*S*wu];
        
        % cycle through the weights vectors from Bayesian allocation
        wu=w1(k,:)';
        Store(j).e1=[Store(j).e1 M'*wu];
        Store(j).v1=[Store(j).v1 wu'*S*wu];
        
        % robustness
        NewTarget=-(10^10);
        if wu'*S1*wu <= g_s
            NewTarget = m1'*wu-g_m*sqrt(wu'*S1*wu); 
        end
        Target=[Target NewTarget]; %update target vector
    end
    
    % robust Bayesian allocation (one for each simulation)
    [Best,k]=max(Target);
    wu=w1(k,:)';
    Store(j).erB=[M'*wu]; 
    Store(j).vrB=[wu'*S*wu];

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% plot results

figure
set(gca,'FontSize',14)
xlabel('Volatility') 
ylabel('Return') 
%FontSize = 30;
for j=1:J
    hold on
    h1=plot(Store(j).v,Store(j).e,'.');
    set(h1,'color','b','markersize',3)
end
set(h1,'markersize',5)
for j=1:J
    hold on
    h2=plot(Store(j).v1,Store(j).e1,'.');
    set(h2,'color','g','markersize',3);
end
set(h2,'markersize',5)
for j=1:J
    hold on 
    h3=plot(Store(j).vrB,Store(j).erB,'.');
    set(h3,'color','r');
end
legend([h1 h2 h3],'sample allocations','Bayesian allocations','robust Bayesian allocations','location','best')
grid on
