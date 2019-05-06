# Parfor meets progressbar
<img align="top" src="https://github.com/fsaxen/ParforProgMon/raw/master/progress.png" />

A very ressource efficient Matlab class for progress monitoring during a `parfor` loop displaying the remaining time and optional progress of each worker.
It supports distributed worker pools (i.e. doesn't only work on local pools).

Matlabs download page: [ParforProgressbar](https://de.mathworks.com/matlabcentral/fileexchange/71436-parfor-progress-monitor-progress-bar-v4)

## Usage:
```Matlab
% Begin by creating a parallel pool.
if isempty(gcp('nocreate'))
   parpool('local');
end

% 'numIterations' is an integer with the total number of iterations in the loop. 
# Feel free to increase this even higher and see other progress monitors fail.
numIterations = 100000;

% Then construct a ParforProgressbar object:
ppm = ParforProgressbar(numIterations);

parfor i = 1:numIterations
   % do some parallel computation
   pause(100/numIterations);
   % increment counter to track progress
   ppm.increment();
end

% Delete the progress handle when the parfor loop is done (otherwise the timer that keeps updating the progress might not stop).
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

## Benefits
1. It's the first parfor progress monitor that also displays the remaining time.
2. It's the first parfor progress monitor that also displays each workers progress.
3. It scales from very small number of iterations to arbitrarily high number of iterations with a very small footprint.

## Drawbacks
1. It does slow down the computation. How much? It depends on how often you update the progressbar (on default every 1.0 seconds - but this is a parameter you can adjust). 
Updating the progressbar on my computer takes 40ms on average. i.e. one of the x workers updates the progressbar (by default every second) and spends an additional 40ms every second = 4%.
But you have x-1 workers that don't get delayed at all (calling increment has a neglegible effect even for millions of iterations).


### Difference to 60135-parfor-progress-monitor-progress-bar-v3:
1. Using [progressbar](https://de.mathworks.com/matlabcentral/fileexchange/6922-progressbar) with it's nice drawing of the remaining time.
2. Complete matlab implementation, no Java. 
3. Each increment, Dylan's java based implementation connects via tcp to the server and closes the connection immediately without sending any data.
The server increments the counter just based on an established connection.
This is quite fast but for very short loop cycles (like the above) it results in way too many connections.
The original ParforProgMonv3 solves this by letting the user choose a stepSize manually. However, this is combersome and non-intuitive.
This update calculates the stepsize automatically and thus maintains a very fast execution time even for very short loop cycles.
4. Instead of tcp socket we use a udp socket whick is established on construction and not opened/closed at each loop cycle.
5. To track each worker progress, each worker sends its own progress to the server via udp.
6. Small interface changes: I don't really care about the window title of the progress bar. This is now an optional parameter and now also properly monitored by matlab's input parser.


### Credits
[Parfor Progress monitor](https://www.mathworks.com/matlabcentral/fileexchange/24594-parfor-progress-monitor)

[Parfor Progress monitor v2](https://www.mathworks.com/matlabcentral/fileexchange/31673-parfor-progress-monitor-v2)

[Parfor Progress monitor v3](https://de.mathworks.com/matlabcentral/fileexchange/60135-parfor-progress-monitor-progress-bar-v3)

[progressbar](https://de.mathworks.com/matlabcentral/fileexchange/6922-progressbar)
