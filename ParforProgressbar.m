% ParforProgressbar   Progress monitor for `parfor` loops
%    ppm = ParforProgressbar(numIterations) constructs a ParforProgressbar object.
%    'numIterations' is an integer with the total number of
%    iterations in the parfor loop.
%
%    ppm = ParforProgressbar(___, 'showWorkerProgress', true) will display
%    the progress of all workers (default: false).
%    
%    ppm = ParforProgressbar(___, 'progressBarUpdatePeriod', 1.5) will
%    update the progressbar every 1.5 second (default: 1.0 seconds).
%
%    ppm = ParforProgressbar(___, 'title', 'my fancy title') will
%    show 'my fancy title' on the progressbar).
%
%
%    <strong>Usage:</strong>
%    % Begin by creating a parallel pool.
%    if isempty(gcp('nocreate'))
%       parpool('local');
%    end
%
%    % 'numIterations' is an integer with the total number of iterations in the loop.
%    numIterations = 100000;
%
%    % Then construct a ParforProgMon object:
%    ppm = ParforProgressbar(numIterations);
%
%    parfor i = 1:numIterations
%       % do some parallel computation
%       pause(100/numIterations);
%       % increment counter to track progress
%       ppm.increment(i);
%    end
%
%   % Delete the progress handle when the parfor loop is done.
%   delete(ppm);
%
%
% Based on <a href="https://de.mathworks.com/matlabcentral/fileexchange/60135-parfor-progress-monitor-progress-bar-v3">ParforProgMonv3</a>.
% Uses the progressbar from: <a href="https://de.mathworks.com/matlabcentral/fileexchange/6922-progressbar">progressbar</a>.
classdef ParforProgressbar < handle
   % These properties are the same for the server and worker and are not
   % subject to change 
   properties ( GetAccess = private, SetAccess = private )
      ServerPort % Port of the server connection
      ServerName % host name of the server connection
      totalIterations % Total number of iterations (entire parfor)
      numWorkersPossible % Total number of possible workers
      stepSize uint64 % Number of steps before update
   end
   
   % These properties are completely different between server and each
   % worker.
   properties (Transient, GetAccess = private, SetAccess = private)
       it uint64 % worker: iteration
       workerID uint64 % worker: unique id for each worker

       workerTable % server: total progress with ip and port of each worker 
       showWorkerProgress logical% server: show not only total progress but also the estimated progress of each worker
       timer % server: timer object

       isWorker logical % server/worker: This identifies a worker/server
       connection % server/worker: udp connection
   end

   methods ( Static )
      function o = loadobj( X )
         % loadobj - METHOD Reconstruct a ParforProgressbar object
         
         % Once we've been loaded, we need to reconstruct ourselves correctly as a
         % worker-side object.
         debug('LoadObj');
         o = ParforProgressbar( {X.ServerName, X.ServerPort, X.totalIterations, X.numWorkersPossible, X.stepSize} );
      end
   end
   
   methods
       function o = ParforProgressbar( numIterations, varargin )
           % ParforProgressbar - CONSTRUCTOR Create a ParforProgressbar object
           % 
           %    ppb = ParforProgressbar(numIterations)
           %    numIterations is an integer with the total number of
           %    iterations in the parfor loop.
           %
           %    ppm = ParforProgressbar(___, 'showWorkerProgress', true) will display
           %    the progress of all workers (default: false).
           %    
           %    ppm = ParforProgressbar(___, 'progressBarUpdatePeriod', 1.5) will
           %    update the progressbar every 1.5 second (default: 1.0 seconds).
           %
           %    ppm = ParforProgressbar(___, 'title', 'my fancy title') will
           %    show 'my fancy title' on the progressbar).
           %
           if iscell(numIterations) % worker
               debug('Start worker.');
               host = numIterations{1};
               port = numIterations{2};
               o.totalIterations = numIterations{3};
               o.numWorkersPossible = numIterations{4};
               o.stepSize = numIterations{5};
               o.ServerName = host;
               o.ServerPort = port;
               t = getCurrentTask(); 
               o.workerID = t.ID;
               % Connect the worker to the server, so that we can send the
               % progress to the server.
               o.connection = udp(o.ServerName, o.ServerPort); 
               fopen(o.connection);
               o.isWorker = true; 
               o.it = 0; % This is the number of iterations this worker is called.
               debug('Send login cmd');
               % Send a login request to the server, so that the ip and
               % port can be saved by the server. This is neccessary to
               % close each worker when the parfor loop is finished.
               fwrite(o.connection,[o.workerID, 0],'ulong'); % login to server
           else % server
               % - Server constructor
               p = inputParser;
               
               showWorkerProgressDefault = false;
               progressBarUpdatePeriodDefault = 1.0;
               titleDefault = '';
               
               validScalarPosNum = @(x) isnumeric(x) && isscalar(x) && (x > 0);
               addRequired(p,'numIterations', validScalarPosNum );
               addParameter(p,'showWorkerProgress', showWorkerProgressDefault, @isscalar);
               addParameter(p,'progressBarUpdatePeriod', progressBarUpdatePeriodDefault, validScalarPosNum);
               addParameter(p,'title',titleDefault,@ischar);
               parse(p,numIterations, varargin{:});               
               o.showWorkerProgress = p.Results.showWorkerProgress;
               o.totalIterations = p.Results.numIterations;
               
               debug('Start server.');
               pPool = gcp('nocreate');   
               if isempty(pPool)
                   error('ParforProgressbar:NeedPool', '*** ParforProgressbar: You must construct a pool before creating a ParforProgressbar object.');
               end
               o.numWorkersPossible = pPool.NumWorkers;
               
               % We don't send each progress step to the server because
               % this will slow down each worker. Insead, we send the
               % progress each stepSize iterations.
               if (o.totalIterations / o.numWorkersPossible) > 200
                   % We only need to resolve 1% gain in worker progress
                   % progressStepSize = worker workload/100
                   progressStepSize = floor(o.totalIterations/o.numWorkersPossible/100);
               else
                   % We will transmit the progress each step.
                   progressStepSize = 1;
               end
               o.stepSize = progressStepSize;
               pct = pctconfig;
               o.ServerName = pct.hostname;
               % Create server connection to receive the updates from each
               % worker via udp. receiver is called each time a data
               % package is received with this class object handle to keep
               % track of the progress.
               o.connection = udp(o.ServerName, 'DatagramReceivedFcn', {@receiver, o}, 'DatagramTerminateMode', 'on', 'EnablePortSharing', 'on');
               fopen(o.connection);
               
               % This new connection uses a free port, which we have to
               % provide to each worker to connect to.
               o.ServerPort = o.connection.LocalPort;
               o.workerTable = table('Size',[pPool.NumWorkers, 4],'VariableTypes',{'uint64','string','uint32','logical'},'VariableNames',{'progress','ip','port','connected'});
               o.isWorker = false;
               
               % Start an empty progressbar and the timer to update it
               % periodically
               if o.showWorkerProgress
                   titles = cell(pPool.NumWorkers + 1, 1);
                   if ~any(contains(p.UsingDefaults,'title'))
                       titles{1} = p.Results.title;
                   else
                       titles{1} = 'Total progress';
                   end
                   for i = 1 : pPool.NumWorkers
                       titles{i+1} = sprintf('Worker %d', i);
                   end
                   progressbar(titles{:});
               else
                   if ~any(contains(p.UsingDefaults,'title'))
                       progressbar(p.Results.title);
                   else
                       progressbar;
                   end
               end
               o.timer = timer('BusyMode','drop','ExecutionMode','fixedSpacing','StartDelay',p.Results.progressBarUpdatePeriod*2,'Period',p.Results.progressBarUpdatePeriod,'TimerFcn',{@draw_progress_bar, o});
               start(o.timer);
           end
       end
       
       function o = saveobj( X )
           debug('SaveObj');
           o.ServerPort = X.ServerPort;
           o.ServerName = X.ServerName;
           o.totalIterations = X.totalIterations;
           o.numWorkersPossible = X.numWorkersPossible;
           o.stepSize = X.stepSize;
       end
       
       function delete( o )
           debug('Delete object');
           o.close();
       end
       
       function increment( o )
           o.it = o.it + 1;
           if mod(o.it, o.stepSize) == 0
               debug('Send it=%d',o.it);
               fwrite(o.connection,[o.workerID, o.it], 'ulong');
           end
       end
       
       function close( o )
           % Close worker/server connection
           if isa(o.connection, 'udp')
               if strcmp(o.connection.Status, 'open')
                    debug('Close worker/server connection');
                    fclose(o.connection);
               end
               debug('Delete worker/server connection');
               delete(o.connection);
           end
           if ~o.isWorker
               if isa(o.timer,'timer') && isvalid(o.timer)
                    debug('Stop and delete timer');
                    stop(o.timer);
                    delete(o.timer);
               end
               % Let's close the progressbar after we are sure that no more
               % data will be collected
               progressbar(1.0);
           end
       end
   end
end

% In this function we usually receive the progress of each worker
% This function belongs to the udp connection of the server/main thread and
% is called whenever data from a worker is received. 
% It is also used to log the ip address and port of each worker when they
% connect at the beginning of their execution.
function receiver(h, ~, o)
    [data,count,msg,ip,port] = fread(h, 1, 'ulong');
    if count ~= 2 % error
        debug('Unkown received data from %s:%d with count = %d and fread msg = %s', ip, port, count, msg);
    else
        id = data(1);
        if data(2) == 0 % log in request in worker constructor
            o.workerTable.progress(id) = 0;
            o.workerTable.ip(id) = ip;
            o.workerTable.port(id) = port;
            o.workerTable.connected(id) = true;
            debug('login worker id=%02d with ip:port=%s:%d',id,ip,port);
        else % from worker increment call
            o.workerTable.progress(id) = data(2);
            debug('Set progress for worker id=%02d to %d',id,data(2));
        end
    end
end

% This function is called by the main threads timer to calculate and draw
% the progress bar
% if showWorkerProgress was set to true then the estimated progress of each
% worker thread is displayed (assuming the workload is evenly split)
function draw_progress_bar(timer, ~, o)
    progressTotal = sum(o.workerTable.progress) / o.totalIterations;
    if(o.showWorkerProgress)
        numWorkers = sum(o.workerTable.connected);
        EstWorkPerWorker = o.totalIterations / numWorkers;
        progWorker = double(o.workerTable.progress) / EstWorkPerWorker;
        progWorkerC = mat2cell(progWorker,ones(1,length(progWorker)));
        progressbar(progressTotal, progWorkerC{:});
    else
        progressbar(progressTotal);
        if progressTotal == 1.0
            stop(timer);
        end
    end
end

% Workers within the parfor loop can sometimes display the commands using
% printf or disp. However, if you start a timer or udp connection and whant
% to display anything after an interrupt occured, it is simply impossible
% to print anything. Unfortunately error messages also don't get shown...
% I used this method to just print stuff to a file with the info about
% the current worker/server (main thread). 
function debug(varargin)
%     fid = fopen('E:/tmp/debugParforProgressbar.txt', 'a');
%     t = getCurrentTask(); 
%     if isempty(t)
%         fprintf(fid, 'Server: ');
%     else
%         fprintf(fid, 'Worker ID=%02d: ', t.ID);
%     end
%     fprintf(fid, varargin{:});
%     fprintf(fid, '\n');
%     fclose(fid);
end