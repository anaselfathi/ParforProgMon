# Parfor progress monitor
<img align="right" src="https://github.com/fsaxen/ParforProgMon/raw/master/progress.png" />

A very ressource efficient Matlab class for progress monitoring during a `parfor` loop displaying the remaining time and optional progress display of each worker.
It supports distributed worker pools (i.e. doesn't only work on local pools).

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
   ppm.increment();
end

% Delete the progress handle when the parfor loop is done.
delete(ppm);
```

## Optional parameters
```matlab
ppm = ParforProgressbar(numIterations) constructs a ParforProgressbar object.
'numIterations' is an integer with the total number of
iterations in the parfor loop.

ppm = ParforProgressbar(___, 'showWorkerProgress', true) will display
the progress of all workers (default: false).

ppm = ParforProgressbar(___, 'progressBarUpdatePeriod', 1.5) will
update the progressbar every 1.5 second (default: 1.0 seconds).

ppm = ParforProgressbar(___, 'title', 'my fancy title') will
show 'my fancy title' on the progressbar).
```

## Difference to 60135-parfor-progress-monitor-progress-bar-v3:
1. Complete matlab implementation, no Java
2. Each increment, Dylan's java based implementation connects via tcp to the server and closes the connection immediately without sending any data.
The server increments the counter just based on an established connection.
This is quite fast but for very short loop cycles (like the above) it results in way too many connections.
The original ParforProgMonv3 solves this by letting the user choose a stepSize manually. However, this is combersome and non-intuitive.
This update calculates the stepsize automatically and thus maintains a very fast execution time even for very short loop cycles.
3. Instead of tcp socket we use a udp socket whick is established on construction and not opened/closed at each loop cycle.
4. To track each worker progress, each worker sends its own progress to the server via udp.
5. Small interface changes 
I don't really care about the window title of the progress bar. 
This is now an optional parameter and now also properly monitored by matlab's input parser.


### Credits
[Parfor Progress monitor](https://www.mathworks.com/matlabcentral/fileexchange/24594-parfor-progress-monitor)

[Parfor Progress monitor v2](https://www.mathworks.com/matlabcentral/fileexchange/31673-parfor-progress-monitor-v2)

[Parfor Progress monitor v3](https://de.mathworks.com/matlabcentral/fileexchange/60135-parfor-progress-monitor-progress-bar-v3)

[progressbar](https://de.mathworks.com/matlabcentral/fileexchange/6922-progressbar)
