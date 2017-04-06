function [resid] = ballbar_objfun(p, qm, eepos, consts, var_ci, var_scaling)

  [dhp,flange,lbb,basepos]=unpackparams(p,consts,var_ci,var_scaling);
  [nd ndof]=size(qm);
  resid=zeros(nd,1);
  for i=1:nd,
    T =forkin(qm(i,:)',dhp,flange,eepos(i,:)');
    resid(i)=(norm(T(1:3,4)-basepos)-lbb);
  end
  
    
%------------------------------------------------------------------------------
%
% compute forward kinematics of robot with dh parameters given in
% dhp -- uses Craig convention 
%   T_i^i=1=Rx(alphai-1)*Dx(ai-1)*Rz(thetai)*Dz(di)
% angles (in radians) output, positions in meters
% output is a 4x4 homogenous matrix of the eecf position
% basepos is base position of interest in base frame of robot (3-col vector)
% eepos is point of interest on end effector relative to last frame
% of robot (3-col vector)
% also computes the jacobian using the method detailed in 
% spong/vidyasagar sec 5.1, this is the jacobian relative to the
% fixed base coordinate frame
%------------------------------------------------------------------------------
function [Tn] = forkin(theta,dhp,eecal,eepos)
n = size(dhp,1);
% throw out any extra denavit-hartenberg params
n=min(n,length(theta));
% initial transform at base position relative to base frame
Tn= eye(4) ;
% storage for z vectors--axes of rotation of each joint
z=zeros(3,n);
% storage for o vectors--distance from base origin to origin of
% each joint coordinate frame
for i=1:n,
  thoff=dhp(i,4);
  ct=cos(theta(i)+thoff);
  st=sin(theta(i)+thoff);
  a=dhp(i,1);
  ca=cos(dhp(i,2));
  sa=sin(dhp(i,2));
  d=dhp(i,3);
  % form dh matrix
  T  = [ct     -st   0    a;
	st*ca ct*ca -sa -sa*d;
	st*sa ct*sa  ca  ca*d;
	       0     0      0   1];
  Tn=Tn*T;
 % z(:,i)=T4(1:3,3);
 % o(:,i)=T4(1:3,4);
end
% add in 6 dof transform for end-effector calibration params
a=eecal(6);
ca=cos(a);
sa=sin(a);
b=eecal(5);
cb=cos(b);
sb=sin(b);
g=eecal(4);
sg=sin(g);
cg=cos(g);
% use xyz fixed angle rotation (craig p. 46)
Teecal = [ ca*cb ca*sb*sg - sa*cg  ca*sb*cg + sa*sg   eecal(1);
           sa*cb sa*sb*sg + ca*cg  sa*sb*cg - ca*sg   eecal(2);
           -sb           cb*sg          cb*cg         eecal(3);
             0             0              0            1];
% now do eecf transform 
Tn = Tn*Teecal*[ eye(3) eepos; 0 0 0 1];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% pack various parameters into a two vectors, one with vectors to
% be identified and the other with fixed parameters 
% also see sister function unpackparams*
% var_ci specifies indices of constants for each variable, and
% should have been a return value of packparams.m

function [varargout]=unpackparams(vars,consts,var_ci,var_scaling)
  nvars = length(var_ci);

  vi=1;
  ci=1;
  vars=vars./var_scaling;
  for nv=1:nvars,
    dat_ci=var_ci{nv};
    dat=zeros(size(dat_ci));
    [m n]=size(dat);
    for i=1:m,
      for j=1:n,
          if dat_ci(i,j)==1.0,
              dat(i,j)=consts(ci);
              ci=ci+1;
          else
              dat(i,j)=vars(vi);
              vi=vi+1;
          end
      end
    end
    varargout{nv} = dat;
  end
