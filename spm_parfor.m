function varargout = spm_parfor(varargin)
%__________________________________________________________________________
% Collection of tools for parallel/distributed processing.
%
% FORMAT out = spm_parfor(('name'), input)
%
% FORMAT help spm_parfor>function
% Returns the help file of the selected function.
%__________________________________________________________________________
% Copyright (C) 2017 Wellcome Trust Centre for Neuroimaging

    if nargin == 0
        help spm_parfor
        error('Not enough argument. Type ''help spm_parfor'' for help.');
    end
    id = varargin{1};
    varargin = varargin(2:end);
    switch lower(id)
        case 'foo'
            [varargout{1:nargout}] = foo(varargin{:});
        otherwise
            help spm_parfor
            error('Unknown function %s. Type ''help spm_parfor'' for help.', id)
    end
end