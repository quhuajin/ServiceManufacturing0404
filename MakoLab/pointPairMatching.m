function [transform, rmsFitError] = pointPairMatching(pointSetA, pointSetB)

% pointPairMatching Simple SVD based point pair matching
%
% Simple point pair matching of 2 point clouds for identifying the
% transfroms that describe pointSetA wrt pointSetB
%
% Syntax:
%   [transform, rmsFitError] = pointPairMatching(pointSetA, pointSetB)
%       pointSetA, pointSetB
%           Point pairs to be matched.   
%

% $Author: dmoses $
% $Revision: 2250 $
% $Date: 2010-08-24 14:46:52 -0400 (Tue, 24 Aug 2010) $
% Copyright: MAKO Surgical corp (2007)
%


% Compute the centroids of each of the point set
centroidA = mean(pointSetA);
centroidB = mean(pointSetB);

% Compute centered vectors
centerVectorA = pointSetA - centroidA(ones(length(pointSetA),1),:);
centerVectorB = pointSetB - centroidB(ones(length(pointSetB),1),:);

% compute the covariance matrix
covMatrix = centerVectorA'*centerVectorB;

% use SVD
[U,~, V] = svd(covMatrix);

% compute rotation and translation
Rot = V*U';
T = centroidB' - Rot*centroidA';
transform = [ Rot T; 0 0 0 1];

% calculate the fit error
fitError = [pointSetB ones(length(pointSetB),1)] - (transform*([pointSetA ones(length(pointSetA),1)]'))';
fitError = fitError(:,1:3);
fitErrorDist = sqrt(sum(fitError.^2,2));
rmsFitError = rms(fitErrorDist);