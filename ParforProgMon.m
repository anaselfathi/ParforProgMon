% PARFORPROGMON   Progress monitor for `parfor` loops
%    ppm = PARFORPROGMON(numIterations) constructs a ParforProgMon object.
%    'numIterations' is an integer with the total number of
%    iterations in the parfor loop.
%
%    ppm = PARFORPROGMON(numIterations, strWindowTitle) will additionally
%    show 'strWindowTitle' in the title of the progressbar.
%    
%    ppm = PARFORPROGMON(numIterations, strWindowTitle, width, height) will
%    change the window size of the progressbar with respect to width and
%    height.
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
%    ppm = ParforProgMon(numIterations);
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
% Modified from <a href="https://de.mathworks.com/matlabcentral/fileexchange/60135-parfor-progress-monitor-progress-bar-v3">ParforProgMonv3</a>.

classdef ParforProgMon < handle
   
   properties ( GetAccess = private, SetAccess = private )
      Port
      HostName
      strAttachedFilesFolder
      stepSize
      totalSteps
   end
   
   properties (Transient, GetAccess = private, SetAccess = private)
      JavaBit
      isWorker
   end
   
   methods ( Static )
      function o = loadobj( X )
         % loadobj - METHOD REconstruct a ParforProgMon object
         
         % Once we've been loaded, we need to reconstruct ourselves correctly as a
         % worker-side object.
         % fprintf('Worker: Starting with {%s, %f, %s}\n', X.HostName, X.Port, X.strAttachedFilesFolder);
         o = ParforProgMon( {X.HostName, X.Port, X.strAttachedFilesFolder, X.stepSize, X.totalSteps} );
      end
   end
   
   methods
      function o = ParforProgMon( numIterations, varargin )
         % ParforProgMon - CONSTRUCTOR Create a ParforProgMon object
         % 
         %    ppm = ParforProgMon(numIterations) constructs a progress
         %    monitor for a parfor loop with 'numIterations' iterations.
         %
         %    Optional arguments:
         %    ppm = ParforProgMon(numIterations, strWindowTitle) will show
         %    the string in the progress bar during execution.
         %
         %    ppm = ParforProgMon(numIterations, strWindowTitle, width, height) 
         %    changes the width and height of the progress bar appearance.
         % 
         
         % - Are we a worker or a server?
         if nargin == 1 && iscell(numIterations)
            % - Worker constructor
            % Get attached files
            o.strAttachedFilesFolder = getAttachedFilesFolder(numIterations{3});
            o.stepSize = numIterations{4};
            o.totalSteps = numIterations{5};
            % fprintf('Worker: Attached files folder on worker is [%s]\n', o.strAttachedFilesFolder);
                        
            % Add to java path
            w = warning('off', 'MATLAB:Java:DuplicateClass');
            javaaddpath(o.strAttachedFilesFolder);
            warning(w);
            
            % "Private" constructor used on the workers
            o.JavaBit   = ParforProgressMonitor.createWorker(numIterations{1}, numIterations{2});
            o.Port      = [];
%             o.it = 0;
         else 
            % - Server constructor
            defaultWindowTitle = '';
            defaultHeight = 80;
            defaultWidth = defaultHeight * 8;

            p = inputParser;
            validScalarPosNum = @(x) isnumeric(x) && isscalar(x) && (x > 0);
            addRequired(p,'numIterations', validScalarPosNum );
            addOptional(p,'strWindowTitle',defaultWindowTitle,@(x) ischar(x));
            addOptional(p,'width',defaultWidth,validScalarPosNum);
            addOptional(p,'height',defaultHeight,validScalarPosNum);
 
            parse(p,numIterations,varargin{:});

            % Check for an existing pool
            pPool = gcp('nocreate');
            if (isempty(pPool))
               error('ParforProgMon:NeedPool', ...
                     '*** ParforProgMon: You must construct a pool before creating a ParforProgMon object.');
            end
            
            % Amend java path
            strPath = fileparts(which('ParforProgMon'));
            o.strAttachedFilesFolder = fullfile(strPath, 'java');
            % fprintf('Server: JAVA class folder is [%s]\n', o.strAttachedFilesFolder);
            w = warning('off', 'MATLAB:Java:DuplicateClass');
            javaaddpath(o.strAttachedFilesFolder);
            warning(w);
            
            % Distribute class to pool
            if (ismember(pPool.AttachedFiles, o.strAttachedFilesFolder))
               pPool.updateAttachedFiles();
            else
               pPool.addAttachedFiles(o.strAttachedFilesFolder);
            end
            
            if p.Results.numIterations > 200
                progressStepSize = floor(p.Results.numIterations/100);
            else
                progressStepSize = 1;
            end
            o.stepSize = progressStepSize;
            o.totalSteps = p.Results.numIterations;
            % Normal construction
            o.JavaBit   = ParforProgressMonitor.createServer( p.Results.strWindowTitle, p.Results.numIterations, progressStepSize, p.Results.width, p.Results.height );
            o.Port      = double( o.JavaBit.getPort() );
            % Get the client host name from pctconfig
            cfg         = pctconfig;
            o.HostName  = cfg.hostname;
         end
      end
      
      function X = saveobj( o )
         % saveobj - METHOD Save a ParforProgMon object for serialisations
         
         % Only keep the Port, HostName and strAttachedFilesFolder
         X.Port     = o.Port;
         X.HostName = o.HostName;
         X.strAttachedFilesFolder = o.strAttachedFilesFolder;
         X.stepSize = o.stepSize;
         X.totalSteps = o.totalSteps;
      end
      
      function increment( o, i )
         % increment - METHOD Indicate that a single loop execution has finished
         if  ~isempty(o.JavaBit) && (mod(i, o.stepSize) == 0 || i == o.totalSteps)
            % Update the UI
            o.JavaBit.increment();
         end
      end
      
      function delete( o )
         % delete - METHOD Delete a ParforProgMon object
         % - Make sure that any other threads that may have closed 
         %   the UI down have a chance to do it first
         pause(.01);
         
         % Close the UI
         if (~isempty(o.JavaBit))
            o.JavaBit.done();
         end
      end
   end
end
