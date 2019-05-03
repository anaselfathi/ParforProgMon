# Parfor progress monitor
<img align="right" src="https://github.com/fsaxen/ParforProgMon/raw/master/progress_bar.png" />

## A Java-based `Matlab` class for progress monitoring during a `parfor` loop

## Usage:
```Matlab
% Begin by creating a parallel pool.
if isempty(gcp('nocreate'))
   parpool('local');
end

% 'numIterations' is an integer with the total number of iterations in the loop.
numIterations = 100000;

% Then construct a ParforProgMon object:
ppm = ParforProgMon(numIterations);

parfor i = 1:numIterations
   % do some parallel computation
   pause(100/numIterations);
   % increment counter to track progress
   ppm.increment(i);
end

% Delete the progress handle when the parfor loop is done.
delete(ppm);
```

## Optional parameters
```matlab
ppm = ParforProgMon(numIterations) constructs a ParforProgMon object.
'numIterations' is an integer with the total number of
iterations in the parfor loop.

ppm = ParforProgMon(numIterations, strWindowTitle) will additionally
show 'strWindowTitle' in the title of the progressbar.

ppm = ParforProgMon(numIterations, strWindowTitle, width, height) will
change the window size of the progressbar with respect to width and
height.
```

## Changes to 60135-parfor-progress-monitor-progress-bar-v3:
1. Automatic step size computation for very long parfor loops:
When increment in the original ParforProgMonv3 is called. The worker connects to the server and immediately closes the connection.
This is quite fast but for very short loop cycles (like the above) it results in way too many connections.
The original ParforProgMonv3 solves this by letting the user choose a stepSize manually. However, this is combersome and non-intuitive.
This small update calculates the stepsize automatically and thus maintains a very fast execution time even for very short loop cycles.

2. Small interface changes 
I don't really care about the window title of the progress bar. 
This is now an optional parameter and also properly monitored by matlab's input parser.


### Credits
[Parfor Progress monitor](https://www.mathworks.com/matlabcentral/fileexchange/24594-parfor-progress-monitor)

[Parfor Progress monitor v2](https://www.mathworks.com/matlabcentral/fileexchange/31673-parfor-progress-monitor-v2)

[Parfor Progress monitor v3](https://de.mathworks.com/matlabcentral/fileexchange/60135-parfor-progress-monitor-progress-bar-v3)
