%--------------------------------------------------------------------------
% Internal function to open be used by kincal procedure
%--------------------------------------------------------------------------
function  [xm,info,perf,B] = sec_LM(fun, x0, opts, B0, varargin)
%SEC_L_M  Secant version of Levenberg-Marquardt's method for least 
% squares: Find  xm = argmin{fun(x)} , where  x0 = [x_1, ..., x_n]  and
% F(x) = .5 * sum(f_i(x)^2) .

% Check parameters and function call
F = NaN;  ng = NaN;
info = zeros(1,7);
if  nargin < 2,  stop = -1;
else
  [stop x n] = checkx(x0);   
  if  ~stop
    [stop F f] = checkfJ(fun,x0,varargin{:});  info(7) = 1;
    if  ~stop
      %  Finish initialization
      if  nargin < 3
        opts = [];
      end
      opts = checkopts(opts, [1e-3 1e-7 1e-9 1000 1e-6]); 
      % Jacobian
      if  nargin > 3  && ~isempty(B0)  % B0 is given
        sB = size(B0);  m = length(f);
        if  sum(sB) == 0  % placeholder
          [stop B] = numericJacobian(fun,x,opts(5),f,varargin{:});  
          info(7) = info(7) + n;
        elseif  any(sB ~= [m n])
          stop = -4;
        else
          B = B0;
        end
      else
        [stop B] = numericJacobian(fun,x,opts(5),f,varargin{:});  
        info(7) = info(7) + n;
      end
      % Check gradient and J'*J
      if  ~stop
        g = B'*f;   ng = norm(g,inf);  A = B'*B;
        if  isinf(ng) || isinf(norm(A(:),inf))
          stop = -5; 
        end 
      end
    end
  end
end
if  stop
  xm = x0;  perf = [];  info(1:6) = [F ng  0  opts(1)  0  stop];
  return
end

% Finish initialization
mu = opts(1) * max(diag(A));    kmax = opts(4);
Trace = nargout > 2;
if  Trace
  xm = repmat(x,1,kmax+1);
  perf = repmat([F; ng; mu],1,kmax+1);
end 


% Iterate
k = 1;   nu = 2;   nh = 0;
ng0 = ng; %#ok<NASGU>
ku = 0;  % direction of last update

while  ~stop
  if  ng <= opts(2),  stop = 1; 
  else
    [h mu] = geth(A,g,mu);
    nh = norm(h);   nx = opts(3) + norm(x);
    if  nh <= opts(3)*nx 
      stop = 2; 
    end 
  end 
  if  ~stop
    xnew = x + h;    h = xnew - x;  
    [stop Fn fn] = checkfJ(fun,xnew,varargin{:});  info(7) = info(7)+1;
    if  ~stop
      % Update  B
      ku = mod(ku,n) + 1; 
      if  abs(h(ku)) < .8*norm(h)  % extra step
        xu = x;
        if  x(ku) == 0,  xu(ku) = opts(5)^2;
        else
          xu(ku) = x(ku) + opts(5)*abs(x(ku)); 
        end
        [stop Fu fu] = checkfJ(fun,xu,varargin{:});  info(7) = info(7)+1;
        if  ~stop
          hu = xu - x;
          B = B + ((fu - f - B*hu)/norm(hu)^2) * hu';
        end
      end
      B = B + ((fn - f - B*h)/norm(h)^2) * h'; 
      k = k + 1;
      if  Trace
        xm(:,k) = xnew;
        perf(:,k) = [Fn norm(B'*fn,inf) mu]';
      end
      dL = (h'*(mu*h - g))/2;  dF = F - Fn;
      if  (dL > 0) && (dF > 0)               % Update x and modify mu
        x = xnew;   F = Fn;  f = fn;
        mu = mu * max(1/3, 1 - (2*dF/dL - 1)^3);   nu = 2;
      else  % Same  x, increase  mu
        mu = mu*nu;  nu = 2*nu; 
      end 
      if  k > kmax,  stop = 3; 
      else
        g = B'*f;  ng = norm(g,inf);      A = B'*B;
        if  isinf(ng) || isinf(norm(A(:),inf))
          stop = -5; 
        end
      end
    end  
  end
end
%  Set return values
if  Trace
  xm = xm(:,1:k);   
  perf = perf(:,1:k);
else
  xm = x;
end
if  stop < 0
  tau = NaN;  
else
  tau = mu/max(diag(A)); 
end
info(1:6) = [F  ng  nh  tau  k-1  stop];
function  [err, J] = numericJacobian(fun,x,d,f,varargin)
% Approximate Jacobian by forward differences
J = zeros(length(f),length(x));
xx = x;
for  j = 1 : length(x)
  if  x(j) == 0
    xp = d^2;
  else
    xp = x(j) + d*abs(x(j)); 
  end
  xx(j) = xp;  fp = feval(fun,xx,varargin{:});
  J(:,j) = (fp - f)/(xp - x(j));
  xx(j) = x(j);
end
% Check J
if  ~isreal(J) || any(isnan(J(:))) || any(isinf(J(:)))
  err = -6;  
else
  err = 0;  
end
%keyboard
function  [err, F,f,J] = checkfJ(fun,x,varargin)
%CHECKFJ  Check Matlab function which is called by a 
% nonlinear least squares solver.

err = 0;   F = NaN;  n = length(x);
if  nargout > 3    % Check  f  and  J
  [f J] = feval(fun,x,varargin{:});
  sf = size(f);   sJ = size(J);
  if  sf(2) ~= 1 || ~isreal(f) || any(isnan(f(:))) || any(isinf(f(:)))
    err = -2; 
    return;
  end
  if  ~isreal(J) || any(isnan(J(:))) || any(isinf(J(:)))
    err = -3;  
    return;
  end
  if  sJ(1) ~= sf(1) || sJ(2) ~= n
    err = -4;  
    return
  end
  
else  % only check  f
  f = feval(fun,x,varargin{:});
  sf = size(f);   
  if  sf(2) ~= 1 || ~isreal(f) || any(isnan(f(:))) || any(isinf(f(:)))
    err = -2;  
    return;
  end
end

% Objective function
F = (f'*f)/2;
if  isinf(F),  err = -5; end

function  [err, x,n] = checkx(x0)
%CHECKX  Check vector

err = 0;  sx = size(x0);   n = max(sx);
if  (min(sx) ~= 1) || ~isreal(x0) || any(isnan(x0(:))) || isinf(norm(x0(:))) 
  err = -1;   x = []; 
else
  x = x0(:); 
end
function  opts = checkopts(opts, default)
%CHECKOPTS  Replace illegal values by default values.

a = default;  la = length(a);  lo = length(opts);
for  i = 1 : min(la,lo)
  oi = opts(i);
  if  isreal(oi) && ~isinf(oi) && ~isnan(oi) && oi > 0
    a(i) = opts(i); 
  end
end
if  lo > la
  a = [a 1];
end % for linesearch purpose
opts = a;

function  [h, mu] = geth(A,g,mu)
% Solve  (Ah + mu*I)h = -g  with possible adjustment of  mu

% Factorize with check of pos. def.
n = size(A,1);  chp = 1;
while  chp
  [R chp] = chol(A + mu*eye(n));
  if  chp == 0  % check for near singularity
    chp = rcond(R) < 1e-15;
  end
  if  chp
    mu = 10*mu;
  end
end

% Solve  (R'*R)h = -g
h = R \ (R' \ (-g));   