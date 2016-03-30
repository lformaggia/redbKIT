function DATA = CSM_read_DataFile(data_file, dim)
%READ_DATAFILE data_file parser
%
%   DATA = READ_DATAFILE(DATA_FILE) read the file specified by the string
%   DATA_FILE and put the fields values into the struct DATA

%   This file is part of redbKIT.
%   Copyright (c) 2016, Ecole Polytechnique Federale de Lausanne (EPFL)
%   Author: Federico Negri <federico.negri at epfl.ch>

if nargin < 2 || isempty(dim)
    dim = 2;
end

%% Set Default values
DATA.flag_dirichlet = [];
DATA.flag_neumann   = [];
DATA.flag_pressure     = [];
        
switch dim
    
    case 2
        
        DATA.bcDir          = @(x,y,t,param)(0.*x.*y);
        DATA.bcNeu          = @(x,y,t,param)(0.*x.*y);
        DATA.bcPrex         = @(x,y,t,param)(0.*x.*y);
        DATA.force          = @(x,y,t,param)(0.*x.*y);
                            
    case 3
        
        DATA.bcDir          = @(x,y,z,t,param)(0.*x.*y);
        DATA.bcNeu          = @(x,y,z,t,param)(0.*x.*y);
        DATA.bcPrex         = @(x,y,z,t,param)(0.*x.*y);
        DATA.force          = @(x,y,z,t,param)(0.*x.*y);
end

DATA.Material_Model = 'Linear';
DATA.Young          = 1e+6;
DATA.Poisson        = 0.4;

%% Read data_file and put problem-data into the DATA struct

eval(data_file);
data_fields_name = fieldnames(data);

for i = 1 : length(data_fields_name)
    
    eval(['DATA.',data_fields_name{i}, '=', 'data.',data_fields_name{i},';']);
    
end

end