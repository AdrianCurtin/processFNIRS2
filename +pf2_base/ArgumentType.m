classdef ArgumentType
    % ARGUMENTTYPE Constants for function argument types in method configuration
    %
    % Provides named constants for argument types used when defining processing
    % functions. These replace magic numbers in the GUI code and make method
    % definitions more readable.
    %
    % Usage:
    %   argType = pf2_base.ArgumentType.INPUT;
    %   if argType == pf2_base.ArgumentType.SAMPLING_RATE
    %       % handle sampling rate argument
    %   end
    %
    % Available Types:
    %   NUMERIC          (1)  - Numeric or logical value
    %   STRING           (2)  - String/char value
    %   INPUT            (3)  - The input data (x)
    %   SAMPLING_RATE    (4)  - Sampling frequency (fs)
    %   TIME             (5)  - Time vector
    %   CHANNEL_MASK     (6)  - Channel quality mask (fchMask)
    %   TIME_CHANNEL_MASK(7)  - Time x Channel mask
    %   CHANNEL_NUMBERS  (8)  - Channel number array
    %   SD_DISTANCE      (9)  - Source-detector distances
    %   MARKERS          (10) - Event markers
    %   AUX_DATA         (11) - Auxiliary data
    %   AMBIENT_CHANNELS (12) - Ambient/dark channels
    %   FNIR_STRUCT      (13) - Full fNIRS data structure
    %
    % Example:
    %   % Define a function argument as sampling rate type
    %   arg.type = pf2_base.ArgumentType.SAMPLING_RATE;
    %   arg.name = 'fs';
    %
    % See also: pf2.methods.raw.create, pf2.methods.raw.addFunction

    properties (Constant)
        % User-specified values
        NUMERIC = 1
        STRING = 2

        % Data from fNIRS structure
        INPUT = 3              % x - the input data matrix
        SAMPLING_RATE = 4      % fs - sampling frequency
        TIME = 5               % fTime - time vector
        CHANNEL_MASK = 6       % fchMask - channel quality mask
        TIME_CHANNEL_MASK = 7  % ftimeChMask - time x channel mask
        CHANNEL_NUMBERS = 8    % fChannelNumbers - channel indices
        SD_DISTANCE = 9        % fChannelSD - source-detector distances
        MARKERS = 10           % fMarkers - event markers
        AUX_DATA = 11          % fAux - auxiliary data
        AMBIENT_CHANNELS = 12  % fAmbient - ambient/dark channels
        FNIR_STRUCT = 13       % fNIRstruct - full structure
    end

    properties (Constant, Access = private)
        % Display names for each type
        Names = {'Num/Logical', 'String', 'Input', 'Fs', 'Time', ...
                 'ChannelMask', 'TimeChannelMask', 'ChannelNumbers', ...
                 'SD Dist', 'Markers', 'Aux', 'AmbientChannels', 'Full fNIR struct'}

        % Reserved argument names that map to fNIRS struct fields
        ReservedNames = {'', '', 'x', 'fs', 'fTime', 'fchMask', ...
                        'ftimeChMask', 'fChannelNumbers', 'fChannelSD', ...
                        'fMarkers', 'fAux', 'fAmbient', 'fNIRstruct'}
    end

    methods (Static)
        function name = getName(typeId)
            % GETNAME Get display name for argument type
            %
            % Syntax:
            %   name = pf2_base.ArgumentType.getName(typeId)
            %
            % Example:
            %   name = pf2_base.ArgumentType.getName(4)  % Returns 'Fs'

            if typeId >= 1 && typeId <= 13
                name = pf2_base.ArgumentType.Names{typeId};
            else
                name = 'Unknown';
            end
        end

        function reserved = getReservedName(typeId)
            % GETRESERVEDNAME Get reserved argument name for type
            %
            % Returns the reserved variable name used internally for this
            % argument type, or empty string if not reserved.
            %
            % Syntax:
            %   reserved = pf2_base.ArgumentType.getReservedName(typeId)
            %
            % Example:
            %   reserved = pf2_base.ArgumentType.getReservedName(4)  % Returns 'fs'

            if typeId >= 1 && typeId <= 13
                reserved = pf2_base.ArgumentType.ReservedNames{typeId};
            else
                reserved = '';
            end
        end

        function typeId = fromName(name)
            % FROMNAME Get type ID from display name
            %
            % Syntax:
            %   typeId = pf2_base.ArgumentType.fromName('Fs')  % Returns 4

            idx = find(strcmpi(pf2_base.ArgumentType.Names, name), 1);
            if isempty(idx)
                typeId = 0;
            else
                typeId = idx;
            end
        end

        function typeId = fromReservedName(reservedName)
            % FROMRESERVEDNAME Get type ID from reserved argument name
            %
            % Syntax:
            %   typeId = pf2_base.ArgumentType.fromReservedName('fs')  % Returns 4

            idx = find(strcmpi(pf2_base.ArgumentType.ReservedNames, reservedName), 1);
            if isempty(idx)
                typeId = 0;
            else
                typeId = idx;
            end
        end

        function names = getAllNames()
            % GETALLNAMES Get cell array of all type display names
            %
            % Syntax:
            %   names = pf2_base.ArgumentType.getAllNames()

            names = pf2_base.ArgumentType.Names;
        end

        function tf = isReserved(typeId)
            % ISRESERVED Check if argument type uses reserved name
            %
            % Reserved types (3-13) are automatically populated from the
            % fNIRS structure. Non-reserved types (1-2) require user values.
            %
            % Syntax:
            %   tf = pf2_base.ArgumentType.isReserved(typeId)

            tf = typeId >= 3 && typeId <= 13;
        end
    end
end
