   % Begin by creating a parallel pool.
   if isempty(gcp('nocreate'))
      parpool('local');
   end

   % 'numIterations' is an integer with the total number of iterations in the loop.
   numIterations = 100000;

   % Then construct a ParforProgMon object:
   ppm = ParforProgMon(numIterations);

   tic
   parfor i = 1:numIterations
      % do some parallel computation
      pause(100/numIterations);
      % increment counter to track progress
      ppm.increment(i);
   end
   toc
   
  % Delete the progress handle when the parfor loop is done. 
  delete(ppm);