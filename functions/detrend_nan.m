function y = detrend_nan(x,restoreMean)

if(nargin<2)
    restoreMean=true;
end

%  Reshape x if necessary, assuming the dimension to be 
%  detrended is the first

szx = size(x); ndimx = length(szx);
if ndimx > 2;
  x = reshape(x, szx(1), prod(szx(2:ndimx)));
end
 
n = size(x,1);
if n == 1,
  x = x(:);			% If a row, turn into column vector
end
[N, m] = size(x);
y = repmat(NaN, [N m]);

for i = 1:m;
  kp = find(~isnan(x(:,i)));
  a = [(kp-1)/(max(kp)-min(kp)) ones(length(kp), 1)];  %  Build regressor
  y(kp,i) = x(kp,i) - a*(a\x(kp,i));
  
  if(restoreMean)
    y(kp,i)=y(kp,i)+nanmean(x(kp,i));
  end
end

if n == 1
  y = y.';
end

%  Reshape output so it is the same dimension as input

if ndimx > 2;
  y = reshape(y, szx);
end
