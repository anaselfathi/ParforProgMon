   % Begin by creating a parallel pool.
   if isempty(gcp('nocreate'))
      parpool('local');
   end
   p = gcp('nocreate');

   % 'numIterations' is an integer with the total number of iterations in the loop.
   % Feel free to increase this even higher and see other progress monitors fail.
   numIterations = p.NumWorkers*100;
   complexity = 2000;
   res = zeros(numIterations, 1);

   % Then construct a ParforProgMon object and provide the total number of
   % iterations
   ppm = ParforProgressbar(numIterations); 
   % Or show the progress of each individual worker too
%    ppm = ParforProgressbar(numIterations,'showWorkerProgress',true); 
   % Or maybe update the progressbar only every 3 seconds to save some time
   % and give the total progress a fany name.
%    ppm = ParforProgressbar(numIterations,'showWorkerProgress',true,'progressBarUpdatePeriod',3,'title','my fancy parfor progress'); 

   pauseTime = 120*p.NumWorkers/numIterations;
   
   tic
   parfor i = 1:numIterations
      % do some parallel computation
%       res(i) = mean(rand(complexity),[1 2]);
      pause(pauseTime);
      % increment counter to track progress
      ppm.increment();
   end
   toc
   
  % Delete the progress handle when the parfor loop is done. 
  delete(ppm);