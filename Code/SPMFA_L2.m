function [W,runTime]=SPMFA_L2(Einput,S,lambda,C,L,U,num,ID)
% solve max x^Tcov(E)x - \lambda \|Sx\|_2 
%such that, and L<=x <=U and
% \|x\|_1 <=C
%%
%Input:
% Einput= ReactionExpression Matrix : number of reaction x number of samples
% S=Stoichiometric Matrix : number of metabolites x number of reaction
% lambda= model parameter show how strong steadystate constraint will be
% L=lowaer bound of all reaction
% U=upper bound for all reaction
% C= sparsity parameter
% num = how many principal component need to find out. Default 1
% ID = if consider to analysis a subsystem then ID contains lidt pf index
% of target reactions.
%%
% Output:
% W: the PMF loadings
% runtime: total time taken

if( nargin < 6 ) 
    disp('Please gives all required inputs'); 
end; 

if( nargin < 7 ) 
    num=1;
end

if( nargin < 8) 
    ID=[1:1:length(L)];
end
% solve max x^TEx - \lambda \|Sx\|_2 such that, and L<=x <=U
% initialization W=[];

eps=1.0000e-10;
D=length(L); % number of reaction
N=size(Einput,2); % number of samples
Nmet= size(S,1);
Nr=length(ID); % number of active reaction
Rep=100;

% large matrix 
E=zeros(D,N);
E(ID,:)=CentralizedExpression(Einput);
% centralized
Ec=CentralizedExpression(E);
% covariance
CovE=Ec*Ec'/N;
% initialization of W
%[winit,~]=eigs(CovE,10,'LM');
%disp('eig complete');

covS=lambda*S'*S;
covS=0.5*(covS+covS');
Tcov = CovE-covS;
[winit,~]=eigs(Tcov,5,'LM');
[winit_Temp,~]=eig(Tcov);
winit=winit_Temp(:,[1:10]);
disp('eig complete');


W=[];
st=1;


disp('Starting component = ')
disp(st);
for t=st:1:num
    
    currCov=zeros(D);
    if numel(W)>0
    currCov(ID,ID)= Deflation(CovE(ID,ID),W(ID,:));
    else
    currCov=CovE;
    end

    Tcov = covS - currCov;
    [evec,v]=eig(Tcov);
    dv=diag(v);
    idp = find(dv >  0.00001);
    idn = find(dv < -0.00001);
    CovP=evec(:,idp)*v(idp,idp)*evec(:,idp)';
    CovN=-evec(:,idn)*v(idn,idn)*evec(:,idn)';
    clear evec
    clear v
    %[w1,o]=eigs(-Tcov,1,'LA');
    for r=1:1:Rep
	
    	st=tic;
            if r==1
            [w,o]=eigs(-0.5*(Tcov'+Tcov),1,'LA');

	    elseif r<=10 
        	w= winit(:,r-1);
    	else
		w=zeros(D,1)
        	w(ID)=2*(rand(Nr,1)-0.5); %(some values only rdxrxn)
    	end
	
    
        
         %obj_pca = w'*currCov*w;
         idL=find(w<L);
%         w(idL)=L(idL);
         w=projL1(w,C);
         idL=find(w<L);

         w(idL)=L(idL);

         obj = w'*(covS-currCov)*w;
         diff=1.0000e+12;
         fval_old = -diff;
         count=1;
         temp(count).w=w;
	 temp(count).objfunction=obj;
         count=2; 
         temp=[];
         while diff>eps
              w_old=w;
              obj_old = obj; 
		[tw,temp(count).obj,temp(count).flag]=quadprog(2*real(CovP),-2*real(CovN)*w_old,[],[],[],[],L,U);
		if norm(tw)>0.0001
			temp(count).w=projL1(w,C);
		else
			temp(count).w=tw;
		end
                idL=find(temp(count).w<L);         
                temp(count).w(idL)=L(idL);
             
                temp(count).objConstant= temp(count).obj+w_old'*CovN*w_old; 
                if temp(count).flag==1
         		w = temp(count).w;
         		obj=w'*(covS-currCov)*w;
			temp(count).objfunction=obj;
      		else
		        temp(count).objfunction=w'*(covS-currCov)*w;
         		w=w_old;
         		obj=obj_old;
                end
                if obj_old<obj
                        w=w_old;
                        obj=obj_old;

                end 
                   temp(count).diff=2*(obj_old - obj)/(abs(obj_old)+abs(obj));
     		if count>0
        		diff=2*(obj_old - obj)/(abs(obj_old)+abs(obj));
     		end
                
                   
     		count=count+1
                disp(['t=',num2str(t),', r=',num2str(r),', obj=',num2str(obj),', diff=', num2str(diff)]),
         end
        T(t,r).temp=temp;
      	allobj_pca(t,r) = w'*currCov*w;
      	e(t,r,:)=S*w;
        allW(t,r,:)=w;
        allobj(t,r)=obj;
        runTime(t,r)=toc(st);
     end
     [a,id]=min(allobj(t,:));
     W(:,t)=squeeze(allW(t,id(1),:));
     O(t)=allobj(t,id);
     obj_pca(t)=allobj_pca(t,id(1));
     allCov(:,:,t)=currCov;
end
end
