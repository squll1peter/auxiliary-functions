function varargout = spm_imbasics(varargin)
%__________________________________________________________________________
% Collection of tools for image calculation (gradient, suff stat, ...).
%
% FORMAT [V,W,C]    = spm_imbasics('hist',X,...)
% FORMAT div        = spm_imbasics('dive',Dx,Dy,Dz,vx)
% FORMAT [Dx,Dy,Dz] = spm_imbasics('grad',X,vx)
% FORMAT spm_imbasics('smooth_img_in_mem',img,fwhm) 
% FORMAT [mg,mn,vr] = spm_imbasics('fit_gmm2hist',c,x,K,verbose)
% FORMAT [a,m,b,n,W,mg,lb] = spm_imbasics('fit_vbgmm2hist',c,x,K,stop_early,tol,verbose)
% FORMAT nfname = spm_imbasics('decimate_inplane',fname,vx1)
%
% FORMAT help spm_imbasics>function
% Returns the help file of the selected function.
%__________________________________________________________________________
% Copyright (C) 2017 Wellcome Trust Centre for Neuroimaging
if nargin == 0
    help spm_imbasics
    error('Not enough argument. Type ''help spm_imcalc'' for help.');
end
id = varargin{1};
varargin = varargin(2:end);
switch lower(id)
    case 'dive'
        [varargout{1:nargout}] = dive(varargin{:});        
    case 'grad'
        [varargout{1:nargout}] = grad(varargin{:});
    case 'smooth_img_in_mem'
        [varargout{1:nargout}] = smooth_img_in_mem(varargin{:});           
    case 'hist'
        [varargout{1:nargout}] = hist(varargin{:});        
    case 'fit_gmm2hist'
        [varargout{1:nargout}] = fit_gmm2hist(varargin{:});                 
    case 'fit_vbgmm2hist'
        [varargout{1:nargout}] = fit_vbgmm2hist(varargin{:});                 
    case 'decimate_inplane'
        [varargout{1:nargout}] = decimate_inplane(varargin{:});                         
    otherwise
        help spm_imcalc
        error('Unknown function %s. Type ''help spm_imcalc'' for help.', id)
end
%==========================================================================

%==========================================================================
function div = dive(Dx,Dy,Dz,vx)  
% Computes the divergence of an image
% FORMAT div = dive(Dx,Dy,Dz,vx) 
% [Dx,Dy,Dz] - Gradients in x-,y- and z-direction
% vx         - Voxel size
% div        - Divergence
%__________________________________________________________________________
% Copyright (C) 2018 Wellcome Trust Centre for Neuroimaging
if nargin<4, vx = ones(3,1); end

if size(Dx,3) == 1
    Du = [-Dx(:,1), -diff(Dx(:,1:end-1),1,2), Dx(:,end-1)];
    Dv = [-Dy(1,:); -diff(Dy(1:end-1,:),1,1); Dy(end-1,:)];
    div = Du./vx(2) + Dv./vx(1);
else
    Du = cat(2, -Dx(:,1,:), -diff(Dx(:,1:end-1,:),1,2), Dx(:,end-1,:)); 
    Dv = cat(1, -Dy(1,:,:), -diff(Dy(1:end-1,:,:),1,1), Dy(end-1,:,:));
    Dw = cat(3, -Dz(:,:,1), -diff(Dz(:,:,1:end-1),1,3), Dz(:,:,end-1));
    div = Du./vx(2) + Dv./vx(1) + Dw./vx(3);
end
%==========================================================================

%==========================================================================
function [Dx,Dy,Dz] = grad(X,vx) 
% Calculate 2D or 3D gradient of an image
% FORMAT [Dx,Dy,Dz] = grad(X,vx)
% X          - Image
% vx         - voxel size
% [Dx,Dy,Dz] - Gradients in x-,y- and z-direction
%__________________________________________________________________________
% Copyright (C) 2018 Wellcome Trust Centre for Neuroimaging   
if nargin<2, vx = ones(3,1); end

precision = get_type(X);

if size(X,3)==1
    Dx = [diff(X,1,2),zeros(size(X,1),1,precision)]./vx(2);
    Dy = [diff(X,1,1);zeros(1,size(X,2),precision)]./vx(1);
    Dz = 0;
else
    Dx = cat(2,diff(X,1,2),zeros(size(X,1),1,size(X,3),precision))./vx(2);
    Dy = cat(1,diff(X,1,1),zeros(1,size(X,2),size(X,3),precision))./vx(1);
    Dz = cat(3,diff(X,1,3),zeros(size(X,1),size(X,2),1,precision))./vx(3);  
end
%==========================================================================

%==========================================================================
function smooth_img_in_mem(img,fwhm) 
% Smooth an image with a Gaussian kernel
% FORMAT smooth_img_in_mem(img,fwhm) 
% img          - Image
% fwhm         - Full-width at half maximum
%__________________________________________________________________________
% Copyright (C) 2018 Wellcome Trust Centre for Neuroimaging   
if nargin<2, fwhm = 10; end

if numel(fwhm)==1
    fwhm = fwhm*ones(1,3);
end

lim = ceil(2*fwhm);
x   = -lim(1):lim(1); x = spm_smoothkern(fwhm(1),x); x = x/sum(x);
y   = -lim(2):lim(2); y = spm_smoothkern(fwhm(2),y); y = y/sum(y);
z   = -lim(3):lim(3); z = spm_smoothkern(fwhm(3),z); z = z/sum(z);
i   = (length(x) - 1)/2;
j   = (length(y) - 1)/2;
k   = (length(z) - 1)/2;
spm_conv_vol(img,img,x,y,z,-[i j k]);
%==========================================================================

%==========================================================================
function [mg,mn,vr] = fit_gmm2hist(c,x,K,verbose)
% Fit a GMM to image histogram
% FORMAT [mg,mn,vr] = fit_gmm2hist(c,x,K,verbose)
% c - Histogram counts
% x - Intensity values
% K - Clusters
% verbose - Output level [0]
% mg - Mixing weights
% mn - Means
% vr - Variances
%__________________________________________________________________________
% Copyright (C) 2018 Wellcome Trust Centre for Neuroimaging   
if nargin<4, verbose = 0; end

mg = ones(K,1)/K;
mn = linspace(min(x),max(x),K)'./K;
sd = ones(K,1)*(max(x) - min(x))./(K);  
vr = zeros(size(sd));

m0    = zeros(K,1);
m1    = zeros(K,1);
m2    = zeros(K,1);
ll(1) = -Inf;
for iter=1:10000
    p  = zeros(numel(x),K);
    for k=1:K
        % Product Rule
        % p(class=k, intensity | mg, nu, sig) = p(class=k|mg) p(intensity | nu, sig, class=k)
        p(:,k) = mg(k)*normpdf(x(:),mn(k),sd(k));
    end

    % Sum Rule
    % p(intensity | mg, nu, sig) = \sum_k p(class=k, intensity | mg, nu, sig)
    sp         = sum(p,2)+eps;
    ll(iter+1) = sum(log(sp).*c(:));
    if ll(iter+1) - ll(iter) < 1e-8*sum(c)
        if verbose==2
            figure(4001);
            md = mean(diff(x));
            plot(x(:),(c/sum(c))/md,'b-',x(:),sp,'r-'); hold on
            plot(x(:),p,'--');        
            set(gca,'TickLabelInterpreter','latex');  
            xlabel('Image intensity','Interpreter','latex')
            ylabel('Probability','Interpreter','latex')
            legend({'Empirical','Fit','Air','Tissue'},'Interpreter','latex');
            drawnow;
        end
        break; 
    end

    if verbose == 3
        figure(4001);
        subplot(121); plot(0:numel(ll)-2,ll(2:end))  
        md = mean(diff(x));
        subplot(122); plot(x(:),p,'--',x(:),c/sum(c)/md,'b.',x(:),sp,'r'); 
        drawnow
    end

    % Bayes Rule
    % p(class=k | intensity, mg, nu, sig) = p(class=k, intensity | mg, nu, sig) / p(intensity | mg, nu, sig)
    p = bsxfun(@rdivide,p,sp);

    % Compute moments from the histograms, weighted by the responsibilities (p).
    for k=1:K
        m0(k) = sum(p(:,k).*c(:));             % Number of voxels in class k
        m1(k) = sum(p(:,k).*c(:).*x(:));       % Sum of the intensities in class k
        m2(k) = sum(p(:,k).*c(:).*x(:).*x(:)); % Sum of squares of intensities in class k
    end
    mg = m0/sum(m0);
    for k=1:K
        mn(k) = m1(k)./m0(k);                                % Mean
        vr(k) = (m2(k)-m1(k)*m1(k)/m0(k)+1e-6)/(m0(k)+1e-6); % Variance
    end
    sd = sqrt(vr);
end
%==========================================================================

%==========================================================================
function [a,m,b,n,W,mg,lb] = fit_vbgmm2hist(c,x,K,stop_early,tol,ard,verbose)
% Fit a VB-GMM to image histogram
% FORMAT [a,m,b,n,W,mg,lb] = fit_vbgmm2hist(c,x,K,stop_early,tol,ard,verbose)
%__________________________________________________________________________
% Copyright (C) 2018 Wellcome Trust Centre for Neuroimaging   
if nargin<4, stop_early = true; end
if nargin<5, tol        = 1e-8; end
if nargin<6, ard        = false; end
if nargin<7, verbose    = false; end
    
% Define priors
a0 = ones(1,K)/K;
m0 = linspace(min(x),max(x),K)/K;
b0 = 1e-4*ones(1,K);
n0 = ones(1,K);

vr = (ones(1,K)*(max(x) - min(x))./(K)).^2;
W0 = 1./(n0.*vr);

% Define posteriors
a = a0;
m = m0;
b = b0;
n = n0;
W = W0;

mg = 1/K*ones(K,1);

tiny = eps('single');

I = numel(x);
x = reshape(x,[I 1]);
c = reshape(c,[I 1]);

% Start algorithm
%--------------------------------------------------------------------------
niter = 1000;
lb    = -Inf;
for iter=1:niter
    olb = lb;
    
    if any(mg<tiny) && ard
        % Prune via ARD
        %------------------------------------------------------------------        
        [~,ix] = find(mg<tiny);
        
        K      = K - numel(ix);
        mg(ix) = [];
        m(ix)  = [];
        b(ix)  = [];
        n(ix)  = [];
        W(ix)  = [];
        m0(ix) = [];
        b0(ix) = [];
        n0(ix) = [];
        W0(ix) = [];
    end
    
    % Compute responsibilities
    %----------------------------------------------------------------------
    lnR = zeros(I,K);    
    for k=1:K
       Elnpi  = log(mg(k));%psi(a(k)) - psi(sum(a));
       ElnLam = psi(0.5*n(k)) + log(2) + log(W(k));
       ElnPx  = 0.5*ElnLam - 0.5*log(2*pi) - 0.5*(1/b(k) + n(k)*W(k)*(x - m(k)).^2);                   
              
       lnR1(:,k) = Elnpi + ElnPx;
    end    
    
    % Log-sum-exp to get responsibilities
    lnsmR = spm_matcomp('logsumexp',lnR1,2);
    lnR   = bsxfun(@minus,lnR1,lnsmR);
    R     = exp(lnR); 
    
    % Compute moments
    %----------------------------------------------------------------------
    s0 = zeros(1,K);
    s1 = zeros(1,K);
    S2 = zeros(1,K);
    for k=1:K
       s0(k) = sum(R(:,k).*c);
       s1(k) = 1/s0(k)*sum(R(:,k).*c.*x);
       S2(k) = 1/s0(k)*sum(R(:,k).*c.*(x - s1(k)).^2);
    end
    
    % Update posteriors
    %----------------------------------------------------------------------
    for k=1:K
       a(k) = a0(k) + s0(k); 
       b(k) = b0(k) + s0(k);
       n(k) = n0(k) + s0(k);
       m(k) = 1/b(k)*(b0(k)*m0(k) + s0(k)*s1(k));
       
       invW = 1/W0(k) + s0(k)*S2(k) + (b0(k)*s0(k))/(b0(k) + s0(k))*(s1(k) - m0(k))^2;
       W(k) = 1/invW;
    end    
    
    % Update mixing weights
    %----------------------------------------------------------------------
    mg = s0/sum(s0) + eps*eps;
    
    % Compute lower bound
    %----------------------------------------------------------------------
    lnpi  = log(mg);%bsxfun(@minus,psi(a),psi(sum(a)));
    lnLam = psi(0.5*n) + log(2) + log(W);
    
    lnB = @(n,W) -0.5*n.*log(W) - (0.5*n*log(2) + gammaln(0.5*n));
    lnC = @(a) gammaln(sum(a)) - (sum(gammaln(a)));
    H   = -lnB(n,W) - 0.5*n.*lnLam + 0.5*n;
    
    ElnPX     = 0.5*sum(s0.*(lnLam - 1./b - n.*S2.*W - n.*W.*(s1 - m).^2 - log(2*pi)));
    ElnPz     = sum(sum(bsxfun(@times,bsxfun(@times,R,lnpi),c)));
    ElnPpi    = 0;%lnC(a0) + sum((a0 - 1).*lnpi);
    ElnPmuLam = 0.5*sum(log(0.5*b0./pi) + lnLam - b0./b - b0.*n.*W.*(m - m0).^2) ...
                + sum(lnB(n0,W0)) + sum(0.5*n0.*lnLam) - 0.5*sum(n.*(1./W0).*W);
    ElnQZ     = sum(sum(bsxfun(@times,R.*lnR,c)));
    ElnQpi    = 0;%sum((a - 1).*lnpi) + lnC(a);
    ElnQmuLam = sum(0.5*lnLam + 0.5*log(b./(2*pi)) - 0.5 - H);
    
    lb = ElnPX + ElnPz + ElnPpi + ElnPmuLam - ElnQZ - ElnQpi - ElnQmuLam;
    
    d = abs((olb*(1 + 10*eps) - lb)/lb);   
    if verbose
        fprintf('%i\t%i\t%6.6f\t%6.6f\t%6.6f\t%6.6f\t%6.6f\t%6.6f\t%6.6f\t%6.6f\t%6.6f\n',iter,K,lb,d,ElnPX,ElnPz,ElnPpi,ElnPmuLam,ElnQZ,ElnQpi,ElnQmuLam);        
    end
            
    if d<tol && stop_early   
        % Finished
        break
    end
end

if verbose        
    figure(4001);
    md = mean(diff(x));        
    sp = exp(lnR1);
    plot(x(:),(c/sum(c))/md,'b-',x(:),sp,'r-');
    drawnow;        
end
    
% mg = exp(lnpi); % Expected mixing coefficients
return
%==========================================================================

%==========================================================================
function [V,W,C] = hist(X,varargin)
% _________________________________________________________________________
%
% Compute the (joint) histogram of a (multidimensional) dataset
%
% FORMAT [V,W,C] = spm_misc('hist',X,B..)
% FORMAT [V,W]   = spm_misc('hist',X,C..)
%
% MANDATORY
% ---------
% X - NxP matrix of observed values
% 
% OPTIONAL
% --------
% B - 1x1 or 1xP number of bins [64]
%   or
% C - Bx1 ordered bin centres (or 1xP cell of bin centres)
%
% KEYWORD
% -------
% KeepZero - Keep bins with zero observations [true]
% Missing  - Keep rows with missing data [false]
%            Additional bins are created for missing values.
% Reshape  - Reshape W and V so that their lattice is B1xB2x... [false]
% Smooth   - FWHM of the smoothing kernel (in bins) [0]
% Verbose  - Verbosity level [0]
%
% OUTPUT
% ------
% V - prod(Bp) x P matrix of multidimensional values (bin centres)
% W - prod(Bp) x 1 vector of weights (bin counts)
% C - 1xP cell of Bx1 bin centres
%
% (B can be smaller that the specified number of bins if KeepZero = false)
%__________________________________________________________________________
% Copyright (C) 2018 Wellcome Centre for Human Neuroimaging
    
% -------------------------------------------------------------------------
% Parse inputs
p = inputParser;
p.FunctionName = 'spm_misc(''hist'')';
p.addRequired('X',                  @isnumeric);
p.addOptional('B',           64,    @isnumeric);
p.addParameter('KeepZero',   true,  @isscalar);
p.addParameter('Missing',    false, @isscalar);
p.addParameter('Reshape',    false, @isscalar);
p.addParameter('Smooth',     0,     @isnumeric);
p.addParameter('Verbose',    0,     @isscalar);
p.parse(X, varargin{:});
B = p.Results.B;


% -------------------------------------------------------------------------
% Discard missing values
if ~p.Results.Missing
    missing = any(isnan(X),2);
    X       = X(~missing,:);
end

% -------------------------------------------------------------------------
% Compute bin centres
P      = size(X,2); % Number of channels
N      = size(X,1); % Number of observations
minval = min(X, [], 1, 'omitnan'); % Min value / channel
maxval = max(X, [], 1, 'omitnan'); % Max value / channel
if ~iscell(B) && size(B,1) == 1
% Number of bins provided
    E = B;
    if numel(B) < P
        E = padarray(E, P-numel(B), 'replicate', 'post');
    end
    E = num2cell(E);
else
% Bin centres provided
    if ~iscell(B)
        if size(B,2) == 1
            B = repmat(B(:), P);
        end
        B = num2cell(B, 1);
    end
        
    E = cell(1,P);
    for c=1:P
        E{c} = (B{c}(2:end) + B{c}(1:end-1))/2;
        E{c} = [minval(c); E{c}; maxval(c)];
    end
end
clear B

% -------------------------------------------------------------------------
% Discretize data
I = cell(1,P);
V = cell(1,P);
dim = zeros(1,P);
hasnan = zeros(1,P,'logical');
for c=1:P
    [I{c},V{c}]       = discretize(X(:,c),E{c});
    I{c}(isnan(I{c})) = numel(V{c});
    V{c} = (V{c}(2:end) + V{c}(1:end-1))/2;
    hasnan(c) = any(isnan(X(:,c)));
    dim(c) = numel(V{c}) + hasnan(c);
    if hasnan(c)
        V{c}(end+1) = NaN;
    end
end
clear E
clear X

% -------------------------------------------------------------------------
% Count
linI = sub2ind(dim, I{:}); clear I
W    = histcounts(linI, 1:prod(dim)+1); clear linI
C    = V;
V    = combvec(V{:});
V    = V.';
W    = W.';

if p.Results.Reshape && ~p.Results.KeepZero
    error('spm_imbasics::hist - Cannot Reshape and not KeepZero')
end


% -------------------------------------------------------------------------
% Smooth
if p.Results.Smooth
    W = reshape(W, dim);
    lim = ceil(4/2.355*p.Results.Smooth);
    ker = spm_smoothkern(p.Results.Smooth, -lim:lim, 0);
    ker = ker(ker~=0);
    for c=1:P
        if hasnan(c)
            W1        = W;
            subs      = cell(1,P);
            [subs{:}] = deal(':');
            subs{c}   = 1:size(W,c)-1;
            W = subsref(W1, struct('type', '()', 'subs', {subs}));
        end
        W = convn(W, reshape(ker, [ones(1,c-1) numel(ker) 1]), 'same');
        if hasnan(c)
            [W1,W] = deal(W,W1);
            W = subsasgn(W, struct('type', '()', 'subs', {subs}), W1);
            clear W1
        end
        
    end
    W = W(:);
end

% -------------------------------------------------------------------------
% Reshape
if p.Results.Reshape
    W = reshape(W, dim);
    V = reshape(V, [dim P]);
end

% -------------------------------------------------------------------------
% Remove empty bins
if ~p.Results.KeepZero
    empty = W == 0;
    W     = W(~empty);
    V     = V(~empty,:);
end
%==========================================================================

%==========================================================================
function nfname = decimate_inplane(fname,vx1)
% Down-sample a NIfTI image in the high-resolution plane
% FORMAT nfname = decimate_inplane(fname,vx1)
%__________________________________________________________________________
% Copyright (C) 2018 Wellcome Trust Centre for Neuroimaging  
if nargin<2, vx1 = 1; end

if numel(vx1)==1
    vx1 = [vx1(1) vx1(1) vx1(1)];
end

Nii  = nifti(fname);
mat0 = Nii.mat;             

% Get down-sampling factor
vx0       = spm_misc('vxsize',mat0);   
d         = ((vx0 < vx1).*vx0)./vx1;
d(d == 0) = 1;   

if sum(d)==3
    % Do not downsample if in-plane res Xhat equals in-plane res Y
    warning('do_dsinp::false')
    return
end

% Smooth and resample in-plane                
D      = diag([d, 1]);          
mat_ds = mat0/D;
vx_ds  = spm_misc('vxsize',mat_ds);

X   = Nii.dat(:,:,:);     
dm0 = size(X);    

fwhm = max(vx_ds./vx0 - 1,0.01);        
spm_imbasics('smooth_img_in_mem',X,fwhm);                                                 

% Resample using 1st order b-splines             
C               = spm_bsplinc(X,[1 1 1 0 0 0]);            
[x1,y1,z1]      = get_downsampling_grid(D,dm0);                  
X               = spm_bsplins(C,x1,y1,z1,[1 1 1 0 0 0]);
X(~isfinite(X)) = 0;

fname         = Nii.dat.fname;
[pth,nam,ext] = fileparts(fname);
nfname        = fullfile(pth,['ds_' nam ext]);

spm_misc('create_nii',nfname,X,mat_ds,Nii.dat.dtype,Nii.descrip);
delete(fname);
%==========================================================================

%==========================================================================
% HELPER FUNCTIONS
%==========================================================================

%==========================================================================
function [x1,y1,z1] = get_downsampling_grid(M,dm)
T          = eye(4)/M;   
dm         = floor(M(1:3,1:3)*dm')';
[x0,y0,z0] = ndgrid(1:dm(1),...
                    1:dm(2),...
                    1:dm(3));

x1 = T(1,1)*x0 + T(1,2)*y0 + T(1,3)*z0 + T(1,4);
y1 = T(2,1)*x0 + T(2,2)*y0 + T(2,3)*z0 + T(2,4);
z1 = T(3,1)*x0 + T(3,2)*y0 + T(3,3)*z0 + T(3,4);  
%==========================================================================

%==========================================================================
function out = get_type(var)
tmp = whos('var');
out = tmp.class;
%==========================================================================