function [resid] = accuracy_objfun(check_ball_wrt_base, EE_wrt_base, lbb)
  
numData = size(EE_wrt_base,2);
tmp = check_ball_wrt_base(:);
for i=1:numData,
  resid(i,1) = norm(EE_wrt_base(:,i) - check_ball_wrt_base(:)) - lbb;
end  

% --------- END OF FILE ----------