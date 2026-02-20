function [transformedCoords, T, matchInfo] = transformToMNI(coords, landmarks, varargin)
% TRANSFORMTOMNI Transform coordinates from subject space to MNI space
%
% Computes a rigid-body transformation from subject-specific coordinates
% (e.g., CapTrak) to MNI space by matching 10-20 electrode landmarks to
% standard MNI 10-20 positions. Uses Procrustes analysis to find the
% optimal rotation, translation, and optional scaling.
%
% This enables visualization of probe data from any coordinate system
% on a standard MNI brain template.
%
% Syntax:
%   transformedCoords = pf2.probe.transformToMNI(coords, landmarks)
%   transformedCoords = pf2.probe.transformToMNI(coords, fNIR)
%   [transformedCoords, T] = pf2.probe.transformToMNI(...)
%   [transformedCoords, T, matchInfo] = pf2.probe.transformToMNI(...)
%   [...] = pf2.probe.transformToMNI(..., Name, Value)
%
% Inputs:
%   coords    - [N x 3] coordinates to transform (in subject space, mm)
%   landmarks - Either:
%               - Table with columns: Label, X, Y, Z (landmark positions)
%               - fNIRS data struct with .device.Landmarks table
%               - pf2.Device object with .Landmarks table
%
% Name-Value Parameters:
%   'AllowScaling'  - Allow uniform scaling in transformation (default: false)
%                     Set to true if subject head size differs from template
%   'MinMatches'    - Minimum number of matched landmarks required (default: 4)
%   'Verbose'       - Print matching details (default: false)
%
% Outputs:
%   transformedCoords - [N x 3] coordinates in MNI space (mm)
%   T                 - Transformation struct with fields:
%                       .R      - 3x3 rotation matrix
%                       .t      - 1x3 translation vector
%                       .s      - Scalar scale factor (1 if no scaling)
%                       .error  - RMS registration error (mm)
%   matchInfo         - Struct with matching details:
%                       .matched - Cell array of matched landmark labels
%                       .nMatched - Number of matched landmarks
%                       .subjectCoords - [M x 3] subject landmark coords
%                       .mniCoords - [M x 3] corresponding MNI coords
%
% Example:
%   % Transform probe optode positions to MNI
%   data = pf2.import.importSNIRF('subject.snirf', false);
%   probeCoords = [data.device.Probe{1}.OptPos.x, ...
%                  data.device.Probe{1}.OptPos.y, ...
%                  data.device.Probe{1}.OptPos.z];
%   mniCoords = pf2.probe.transformToMNI(probeCoords, data);
%
%   % With scaling allowed
%   [mniCoords, T] = pf2.probe.transformToMNI(probeCoords, data, ...
%       'AllowScaling', true, 'Verbose', true);
%   fprintf('Registration error: %.2f mm\n', T.error);
%
% Notes:
%   - Requires landmarks to include 10-20 electrode positions
%   - Uses cerebro_1020 asset as MNI reference
%   - Fiducials (LPA, RPA, Nasion) can be used but 10-20 positions
%     provide better coverage for robust registration
%   - For CapTrak coordinates, ensure they are already in mm
%
% See also: pf2.probe.plot.interpolateValues3D, pf2.import.importSNIRF

% Parse inputs
p = inputParser;
p.addRequired('coords', @(x) isnumeric(x) && size(x, 2) == 3);
p.addRequired('landmarks');
p.addParameter('AllowScaling', false, @islogical);
p.addParameter('MinMatches', 4, @(x) isnumeric(x) && x >= 3);
p.addParameter('Verbose', false, @islogical);
p.parse(coords, landmarks, varargin{:});

allowScaling = p.Results.AllowScaling;
minMatches = p.Results.MinMatches;
verbose = p.Results.Verbose;

% Extract landmarks table from various input types
if istable(landmarks)
    landmarkTable = landmarks;
elseif isstruct(landmarks)
    % fNIRS data struct
    if isfield(landmarks, 'device')
        % Check if device is pf2.Device object or struct
        if isa(landmarks.device, 'pf2.Device')
            if ~isempty(landmarks.device.Landmarks)
                landmarkTable = landmarks.device.Landmarks;
            else
                error('pf2:probe:transformToMNI:noLandmarks', ...
                    'Device object does not contain Landmarks');
            end
        elseif isstruct(landmarks.device) && isfield(landmarks.device, 'Landmarks')
            landmarkTable = landmarks.device.Landmarks;
        else
            error('pf2:probe:transformToMNI:noLandmarks', ...
                'Device does not contain Landmarks table');
        end
    elseif isfield(landmarks, 'Landmarks')
        landmarkTable = landmarks.Landmarks;
    else
        error('pf2:probe:transformToMNI:noLandmarks', ...
            'Input struct does not contain Landmarks table');
    end
elseif isa(landmarks, 'pf2.Device')
    if ~isempty(landmarks.Landmarks)
        landmarkTable = landmarks.Landmarks;
    else
        error('pf2:probe:transformToMNI:noLandmarks', ...
            'Device object does not contain Landmarks');
    end
else
    error('pf2:probe:transformToMNI:invalidInput', ...
        'landmarks must be a table, fNIRS struct, or pf2.Device object');
end

% Verify landmarks table has required columns
if ~all(ismember({'Label', 'X', 'Y', 'Z'}, landmarkTable.Properties.VariableNames))
    error('pf2:probe:transformToMNI:invalidLandmarks', ...
        'Landmarks table must have columns: Label, X, Y, Z');
end

% Load MNI 10-20 reference positions
mni1020 = pf2_base.getAsset('cerebro_1020');

% Match landmarks to MNI reference
% Use case-insensitive matching
subjectLabels = upper(string(landmarkTable.Label));
mniLabels = upper(string(mni1020.Electrode));

[matchedSubject, matchedMNI] = deal([]);
matchedLabels = {};

for i = 1:length(subjectLabels)
    % Find matching MNI electrode
    mniIdx = find(strcmp(subjectLabels(i), mniLabels), 1);
    if ~isempty(mniIdx)
        matchedSubject(end+1, :) = [landmarkTable.X(i), landmarkTable.Y(i), landmarkTable.Z(i)];
        matchedMNI(end+1, :) = [mni1020.mx(mniIdx), mni1020.my(mniIdx), mni1020.mz(mniIdx)];
        matchedLabels{end+1} = char(landmarkTable.Label{i});
    end
end

nMatched = size(matchedSubject, 1);

if verbose
    fprintf('Matched %d / %d landmarks to MNI reference\n', nMatched, height(landmarkTable));
    if nMatched > 0
        fprintf('Matched: %s\n', strjoin(matchedLabels, ', '));
    end
end

if nMatched < minMatches
    error('pf2:probe:transformToMNI:insufficientMatches', ...
        'Only %d landmarks matched (minimum %d required). Cannot compute transformation.', ...
        nMatched, minMatches);
end

% Compute rigid-body transformation using Procrustes analysis
% Target: MNI positions, Source: subject positions
% Find transformation that maps subject → MNI

% Center both point sets
subjectCentroid = mean(matchedSubject, 1);
mniCentroid = mean(matchedMNI, 1);

subjectCentered = matchedSubject - subjectCentroid;
mniCentered = matchedMNI - mniCentroid;

% Compute optimal rotation using SVD
H = subjectCentered' * mniCentered;
[U, ~, V] = svd(H);
R = V * U';

% Handle reflection (ensure proper rotation, not reflection)
if det(R) < 0
    V(:, 3) = -V(:, 3);
    R = V * U';
end

% Compute scale factor if allowed
if allowScaling
    subjectNorm = sqrt(sum(subjectCentered.^2, 'all'));
    mniNorm = sqrt(sum(mniCentered.^2, 'all'));
    s = mniNorm / subjectNorm;
else
    s = 1;
end

% Compute translation
t = mniCentroid - s * (subjectCentroid * R);

% Apply transformation to input coordinates
transformedCoords = s * (coords * R) + t;

% Compute registration error
registeredLandmarks = s * (matchedSubject * R) + t;
errors = sqrt(sum((registeredLandmarks - matchedMNI).^2, 2));
rmsError = sqrt(mean(errors.^2));

if verbose
    fprintf('Registration RMS error: %.2f mm\n', rmsError);
    fprintf('Scale factor: %.4f\n', s);
    if rmsError > 10
        warning('pf2:probe:transformToMNI:highError', ...
            'Registration error is high (%.1f mm). Check landmark quality.', rmsError);
    end
end

% Build output structs
T = struct();
T.R = R;
T.t = t;
T.s = s;
T.error = rmsError;

matchInfo = struct();
matchInfo.matched = matchedLabels;
matchInfo.nMatched = nMatched;
matchInfo.subjectCoords = matchedSubject;
matchInfo.mniCoords = matchedMNI;
matchInfo.errors = errors;

end
