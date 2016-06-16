function [u, FE_SPACE, MESH, DATA, errorL2, errorH1] = Elliptic_Solver(dim, elements, vertices, boundaries, fem, data_file, param)
%ELLIPTIC_SOLVER diffusion-transport-reaction finite element solver
%
%   [U, FE_SPACE, MESH, DATA, ERRORL2, ERRORH1] = ...
%    ELLIPTIC2D_SOLVER(ELEMENTS, VERTICES, BOUNDARIES, FEM, DATA_FILE, PARAM)
%
%   Inputs:
%     ELEMENTS, VERTICES, BOUNDARIES: mesh information
%     FEM: string 'P1' or 'P2'
%     DATA_FILE: name of the file defining the problem data and
%          boundary conditions.
%     PARAM: vector of parameters possibly used in the data_file; 
%         if not provided, the PARAM vector is set to the empty vector.
%
%   Outputs:
%     U: problem solution
%     ERRORL2: L2-error between the numerical solution and the exact one 
%        (provided by the user in the data_file)
%     ERRORH1: H1-error between the numerical solution and the exact one 
%        (provided by the user in the data_file)
%     FE_SPACE: struct containing Finite Element Space information
%     MESH: struct containing mesh information
%     DATA: struct containing problem data

%   This file is part of redbKIT.
%   Copyright (c) 2015, Ecole Polytechnique Federale de Lausanne (EPFL)
%   Author: Federico Negri <federico.negri at epfl.ch> 

if nargin < 6
    error('Missing input arguments. Please type help Elliptic_Solver')
end

if isempty(data_file)
    error('Missing data_file')
end

if nargin < 7
    param = [];
end

%% Read problem parameters and BCs from data_file
DATA   = read_DataFile(data_file, dim, param);
DATA.param = param;

%% Set quad_order
if dim == 2
    quad_order       = 4;
elseif dim == 3
    quad_order       = 5;
end

%% Create and fill the MESH data structure
[ MESH ] = buildMESH( dim, elements, vertices, boundaries, fem, quad_order, DATA );

%% Create and fill the FE_SPACE data structure
[ FE_SPACE ] = buildFESpace( MESH, fem, 1, quad_order );

fprintf('\n **** PROBLEM''S SIZE INFO ****\n');
fprintf(' * Number of Vertices  = %d \n',MESH.numVertices);
fprintf(' * Number of Elements  = %d \n',MESH.numElem);
fprintf(' * Number of Nodes     = %d \n',MESH.numNodes);
fprintf('-------------------------------------------\n');

%% Generate Domain Decomposition (if required)
PreconFactory = PreconditionerFactory( );
Precon        = PreconFactory.CreatePrecon(DATA.Preconditioner.type, DATA);

if isfield(DATA.Preconditioner, 'type') && strcmp( DATA.Preconditioner.type, 'AdditiveSchwarz')
    R      = ADR_overlapping_DD(MESH, DATA.Preconditioner.num_subdomains,  DATA.Preconditioner.overlap_level);
    Precon.SetRestrictions( R );
end

%% Assemble matrix and right-hand side
fprintf('\n Assembling ... ');
t_assembly = tic;
[A, F]  =  ADR_Assembler(MESH, DATA, FE_SPACE);
t_assembly = toc(t_assembly);
fprintf('done in %3.3f s', t_assembly);


%% Apply boundary conditions
fprintf('\n Apply boundary conditions ');
[A_in, F_in, u_D]   =  ADR_ApplyBC(A, F, FE_SPACE, MESH, DATA);

%% Solve
LinSolver = LinearSolver( DATA.LinearSolver );
u                         = zeros(MESH.numNodes,1);

fprintf('\n Solve Au = f ... ');
Precon.Build( A_in );
fprintf('\n       **  time to build the preconditioner %3.3f s \n', Precon.GetBuildTime());
LinSolver.SetPreconditioner( Precon );
u(MESH.internal_dof)      = LinSolver.Solve( A_in, F_in );
fprintf('\n       ** time to solve the linear system in %3.3f s \n\n', LinSolver.GetSolveTime());

u(MESH.Dirichlet_dof)     = u_D;


%% Compute L2 and H1 errors
errorL2 = [];
errorH1 = [];

if nargout == 5
    [errorL2] = FEM_error(u, MESH, DATA, FE_SPACE);
    fprintf(' L2-error : %1.3e\n', errorL2);
elseif nargout == 6
    [errorL2,errorH1] = FEM_error(u, MESH, DATA, FE_SPACE);
    fprintf(' L2-error : %1.3e H1-error : %1.3e\n',errorL2, errorH1);
end

%% Store matrix and rhs into FE_SPACE struct
FE_SPACE.A_in = A_in;
FE_SPACE.F_in = F_in;

return
