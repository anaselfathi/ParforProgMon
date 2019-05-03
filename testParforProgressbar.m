   % Begin by creating a parallel pool.
   if isempty(gcp('nocreate'))
      parpool('local');
   end

   % 'numIterations' is an integer with the total number of iterations in the loop.
   numIterations = 10000;

   % Then construct a ParforProgMon object:
   ppm = ParforProgressbar(numIterations); 
%    ppm = ParforProgressbar(numIterations,'showWorkerProgress',true); 
%    ppm = ParforProgressbar(numIterations,'showWorkerProgress',true,'progressBarUpdatePeriod',3,'title','my fancy parfor progress'); 

   tic
   parfor i = 1:numIterations
      % do some parallel computation
      pause(300/numIterations);
      % increment counter to track progress
      ppm.increment();
   end
   toc
   
  % Delete the progress handle when the parfor loop is done. 
  delete(ppm);