function [varargout] = CSM_Assembler(output, MESH, DATA, FE_SPACE, U_h, t, subdomain)
%CSM_ASSEMBLER assembler for 2D/3D CSM models
%
%   [F_ext]       = CSM_ASSEMBLER('external_forces', MESH, DATA, FE_SPACE, U_h, t, subdomain)
%   [F_in]        = CSM_ASSEMBLER('internal_forces', MESH, DATA, FE_SPACE, U_h, t, subdomain)
%   [F_in, dF_in] = CSM_ASSEMBLER('internal_forces', MESH, DATA, FE_SPACE, U_h, t, subdomain)
%   [F, dF]       = CSM_ASSEMBLER('all',             MESH, DATA, FE_SPACE, U_h, t, subdomain)

%   This file is part of redbKIT.
%   Copyright (c) 2016, Ecole Polytechnique Federale de Lausanne (EPFL)
%   Author: Federico Negri <federico.negri@epfl.ch>

if nargin < 5 || isempty(U_h)
    U_h = zeros(MESH.dim*MESH.numNodes,1);
end

switch DATA.Material_Model
    case 'Linear'
        material_param = [DATA.Young DATA.Poisson];
        
    case 'StVenantKirchhoff'
        material_param = [DATA.Young DATA.Poisson];
        
    case 'Neohookean'
        material_param = [DATA.Shear DATA.Poisson];
end

if nargin < 6
    t = [];
end

if nargin < 7
    subdomain = [];
end

if ~isempty(subdomain)
    index_subd = [];
    for q = 1 : length(subdomain)
        index_subd = [index_subd find(MESH.elements(FE_SPACE.numElemDof+1,:) == subdomain(q))];
    end
    MESH.elements = MESH.elements(:,index_subd);
    MESH.numElem  = size(MESH.elements,2);
else
    index_subd = [1:MESH.numElem];
end

switch output
    
    case 'external_forces'
        
        varargout{1} = compute_external_forces(MESH, DATA, FE_SPACE, t, index_subd);
        
    case 'internal_forces'
        
        [F_in, dF_in] = compute_internal_forces(material_param, MESH, DATA, FE_SPACE, U_h, index_subd);
        
        varargout{1} = F_in;
        varargout{2} = dF_in;
        
    case 'all'
        
        F_ext         = compute_external_forces(MESH, DATA, FE_SPACE, t, index_subd);
        [F_in, dF_in] = compute_internal_forces(material_param, MESH, DATA, FE_SPACE, U_h, index_subd);
                
        varargout{1} = F_in - F_ext;
        varargout{2} = dF_in;
        
    otherwise
        error('output option not available')
end


end

%==========================================================================
function [F_ext] = compute_external_forces(MESH, DATA, FE_SPACE, t, index_subd)

% Computations of all quadrature nodes in the elements
coord_ref = MESH.chi;
switch MESH.dim
    
    case 2
        
        x = zeros(MESH.numElem,FE_SPACE.numQuadNodes); y = x;
        for j = 1 : 3
            i = MESH.elements(j,:);
            vtemp = MESH.vertices(1,i);
            x = x + vtemp'*coord_ref(j,:);
            vtemp = MESH.vertices(2,i);
            y = y + vtemp'*coord_ref(j,:);
        end
        
        % Evaluation of external forces in the quadrature nodes
        for k = 1 : MESH.dim
            f{k}  = DATA.force{k}(x,y,t,DATA.param);
        end
        
    case 3
        x = zeros(MESH.numElem,FE_SPACE.numQuadNodes); y = x; z = x;
        
        for j = 1 : 4
            i = MESH.elements(j,:);
            vtemp = MESH.vertices(1,i);
            x = x + vtemp'*coord_ref(j,:);
            vtemp = MESH.vertices(2,i);
            y = y + vtemp'*coord_ref(j,:);
            vtemp = MESH.vertices(3,i);
            z = z + vtemp'*coord_ref(j,:);
        end
        
        % Evaluation of external forces in the quadrature nodes
        for k = 1 : MESH.dim
            f{k}  = DATA.force{k}(x,y,z,t,DATA.param);
        end
        
end
% C_OMP assembly, returns matrices in sparse vector format

F_ext = [];
for k = 1 : MESH.dim
    
    [rowF, coefF] = CSM_assembler_ExtForces(f{k}, MESH.elements, FE_SPACE.numElemDof, ...
        FE_SPACE.quad_weights, MESH.jac(index_subd), FE_SPACE.phi);
    
    % Build sparse matrix and vector
    F_ext    = [F_ext; sparse(rowF, 1, coefF, MESH.numNodes, 1)];
    
end

end
%==========================================================================
function [F_in, dF_in] = compute_internal_forces(material_param, MESH, DATA, FE_SPACE, U_h, index_subd)

% C_OMP assembly, returns matrices in sparse vector format
[rowdG, coldG, coefdG, rowG, coefG] = ...
    CSM_assembler_C_omp(MESH.dim, DATA.Material_Model, material_param, U_h, MESH.elements, FE_SPACE.numElemDof, ...
    FE_SPACE.quad_weights, MESH.invjac(index_subd,:,:), MESH.jac(index_subd), FE_SPACE.phi, FE_SPACE.dphi_ref);

% Build sparse matrix and vector
F_in    = sparse(rowG, 1, coefG, MESH.numNodes*MESH.dim, 1);
dF_in   = sparse(rowdG, coldG, coefdG, MESH.numNodes*MESH.dim, MESH.numNodes*MESH.dim);

end
%==========================================================================