classdef IdentityImportSpy < handle
%IDENTITYIMPORTSPY Observable importer used by identity preflight tests.

    properties
        CallCount = 0
        Data = []
        OnRun = []
    end

    methods
        function obj = IdentityImportSpy(data)
            if nargin > 0
                obj.Data = data;
            end
        end

        function data = invoke(obj)
            obj.CallCount = obj.CallCount + 1;
            if ~isempty(obj.OnRun)
                obj.OnRun();
            end
            data = obj.Data;
        end
    end
end
