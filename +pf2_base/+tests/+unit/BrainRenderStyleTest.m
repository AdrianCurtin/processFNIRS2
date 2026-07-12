classdef BrainRenderStyleTest < matlab.unittest.TestCase
% BRAINRENDERSTYLETEST Tests for the showcase/publication render styles
%
% Covers the new cortical-surface rendering helpers (vertex normals,
% curvature ambient occlusion, procedural matcap, brain colormaps), the
% RenderStyle preset registry, the 'Style' option on interpolateValues3D
% (publication vs showcase, including matcap and colormap-name resolution),
% and headless construction of the Explore3D GUI.

    properties
        proc
        vals
        tmpDir
    end

    methods (TestClassSetup)
        function loadData(tc)
            data = pf2.import.sampleData.fNIR2000();
            tc.proc = processFNIRS2(data);
            tc.vals = mean(tc.proc.HbO, 1, 'omitnan');
            tc.tmpDir = tempname; mkdir(tc.tmpDir);
        end
    end

    methods (TestClassTeardown)
        function cleanup(tc)
            if ~isempty(tc.tmpDir) && exist(tc.tmpDir, 'dir')
                rmdir(tc.tmpDir, 's');
            end
        end
    end

    methods (Test)

        function vertexNormalsOutward(tc)
            [sx, sy, sz] = sphere(30);
            fv = surf2patch(sx, sy, sz, 'triangles');
            N = pf2_base.plot.vertexNormals(fv.vertices, fv.faces);
            tc.verifyEqual(size(N), size(fv.vertices));
            radial = fv.vertices ./ max(sqrt(sum(fv.vertices.^2,2)), eps);
            tc.verifyGreaterThan(mean(sum(N .* radial, 2)), 0.9); % outward & radial
        end

        function curvatureAOInRange(tc)
            [sx, sy, sz] = sphere(30);
            fv = surf2patch(sx, sy, sz, 'triangles');
            N = pf2_base.plot.vertexNormals(fv.vertices, fv.faces);
            ao = pf2_base.plot.meshCurvature(fv.vertices, fv.faces, N, 'Strength', 0.5);
            tc.verifyEqual(numel(ao), size(fv.vertices,1));
            tc.verifyTrue(all(ao > 0 & ao <= 1.2));
        end

        function matcapMaterials(tc)
            for mat = ["clay","porcelain","matte","glossy","pewter","jade"]
                img = pf2_base.plot.matcapTexture(char(mat), 64);
                tc.verifyEqual(size(img), [64 64 3]);
                tc.verifyTrue(all(img(:) >= 0 & img(:) <= 1));
            end
        end

        function brainColormaps(tc)
            for nm = ["actc","warm","cool","hot","blue2red","bone","surface", ...
                      "rdbu","viridis","cividis"]
                [cm, al] = pf2_base.plot.brainColormap(char(nm), 64);
                tc.verifyEqual(size(cm), [64 3]);
                tc.verifyEqual(numel(al), 64);
                tc.verifyTrue(all(cm(:) >= 0 & cm(:) <= 1));
            end
        end

        function renderStylePresets(tc)
            sp = pf2_base.plot.RenderStyle.get('publication');
            ss = pf2_base.plot.RenderStyle.get('showcase');
            tc.verifyFalse(sp.useMatcap);
            tc.verifyTrue(ss.useMatcap);
            tc.verifyTrue(ss.grayCortex);
            tc.verifyEqual(ss.supersample, 2);
            % passthrough struct backfills missing fields
            partial = rmfield(ss, 'aoStrength');
            full = pf2_base.plot.RenderStyle.get(partial);
            tc.verifyTrue(isfield(full, 'aoStrength'));
        end

        function showcaseRender(tc)
            fp = fullfile(tc.tmpDir, 'showcase.png');
            fig = figure('Visible','off','Color','w','Position',[100 100 600 520]);
            c = onCleanup(@() close(fig));
            pf2.probe.plot.interpolateValues3D(tc.vals, tc.proc, 'ax', axes('Parent',fig), ...
                'Style', 'showcase', 'ChannelLabels', false, 'SDLabels', false, ...
                'ShowAxes', false, 'savePath', fp);
            info = dir(fp);
            tc.verifyGreaterThan(info.bytes, 5000);
        end

        function publicationRender(tc)
            fp = fullfile(tc.tmpDir, 'publication.png');
            fig = figure('Visible','off','Color','w','Position',[100 100 600 520]);
            c = onCleanup(@() close(fig));
            pf2.probe.plot.interpolateValues3D(tc.vals, tc.proc, 'ax', axes('Parent',fig), ...
                'Style', 'publication', 'ChannelLabels', false, 'SDLabels', false, ...
                'ShowAxes', false, 'savePath', fp);
            info = dir(fp);
            tc.verifyGreaterThan(info.bytes, 5000);
        end

        function colormapNameResolution(tc)
            % brainColormap names (not MATLAB functions) must resolve.
            for nm = ["rdbu","viridis","actc"]
                fp = fullfile(tc.tmpDir, sprintf('cmap_%s.png', nm));
                fig = figure('Visible','off','Color','w','Position',[100 100 500 450]);
                c = onCleanup(@() close(fig));
                pf2.probe.plot.interpolateValues3D(tc.vals, tc.proc, 'ax', axes('Parent',fig), ...
                    'cmap', char(nm), 'ChannelLabels', false, 'SDLabels', false, ...
                    'ShowAxes', false, 'savePath', fp);
                tc.verifyTrue(exist(fp, 'file') == 2);
            end
        end

        function styleStructOverride(tc)
            % A style struct with overridden AO/matcap should render.
            sty = pf2_base.plot.RenderStyle.get('showcase');
            sty.aoStrength = 0.6;
            sty.matcapMaterial = 'porcelain';
            fp = fullfile(tc.tmpDir, 'struct.png');
            fig = figure('Visible','off','Color','w','Position',[100 100 500 450]);
            c = onCleanup(@() close(fig));
            pf2.probe.plot.interpolateValues3D(tc.vals, tc.proc, 'ax', axes('Parent',fig), ...
                'Style', sty, 'ChannelLabels', false, 'SDLabels', false, ...
                'ShowAxes', false, 'savePath', fp);
            tc.verifyTrue(exist(fp, 'file') == 2);
        end

        function helperErrorsOnBadName(tc)
            tc.verifyError(@() pf2_base.plot.brainColormap('not_a_map'), ...
                'pf2_base:plot:brainColormap:badName');
            tc.verifyError(@() pf2_base.plot.matcapTexture('not_a_material'), ...
                'pf2_base:plot:matcapTexture:badName');
            % A typo'd colormap name must surface as a clear error at render.
            fig = figure('Visible','off'); c = onCleanup(@() close(fig));
            tc.verifyError(@() pf2.probe.plot.interpolateValues3D(tc.vals, tc.proc, ...
                'ax', axes('Parent',fig), 'cmap', 'virdis'), ...
                'pf2_base:plot:brainColormap:badName');
        end

        function showcaseDiffersFromPublication(tc)
            % The two styles must produce visibly different surface coloring
            % (matcap on vs off), guarding against the presets collapsing.
            getC = @(ax) get(findall(ax,'Type','Patch','Tag','Brain'), 'FaceVertexCData');
            f1 = figure('Visible','off'); c1 = onCleanup(@() close(f1));
            pf2.probe.plot.interpolateValues3D(tc.vals, tc.proc, 'ax', axes('Parent',f1), ...
                'Style','showcase','initCamPosition','front','ChannelLabels',false,'SDLabels',false);
            cShow = getC(gca);
            f2 = figure('Visible','off'); c2 = onCleanup(@() close(f2));
            pf2.probe.plot.interpolateValues3D(tc.vals, tc.proc, 'ax', axes('Parent',f2), ...
                'Style','publication','initCamPosition','front','ChannelLabels',false,'SDLabels',false);
            cPub = getC(gca);
            tc.verifyNotEqual(cShow, cPub);
        end

        function numericColormapRenders(tc)
            % A raw [N x 3] colormap matrix must resolve and render.
            fp = fullfile(tc.tmpDir, 'numericmap.png');
            fig = figure('Visible','off','Color','w','Position',[100 100 500 450]);
            c = onCleanup(@() close(fig));
            pf2.probe.plot.interpolateValues3D(tc.vals, tc.proc, 'ax', axes('Parent',fig), ...
                'cmap', parula(128), 'ChannelLabels', false, 'SDLabels', false, ...
                'ShowAxes', false, 'savePath', fp);
            tc.verifyTrue(exist(fp, 'file') == 2);
        end

        function explore3DConstructs(tc)
            app = pf2.probe.plot.Explore3D(tc.proc, 'Visible', 'off');
            cl = onCleanup(@() delete(app.Fig));
            tc.verifyTrue(isgraphics(app.Fig));
            tc.verifyNotEmpty(findall(app.Ax, 'Type', 'Patch', 'Tag', 'Brain'));
            tc.verifyNotEmpty(app.Ctrl.cmd.String);
        end

        function explore3DTimePointMode(tc)
            % The fragile time-point path: toggle off time-average, move the
            % time slider, re-render via the callback, and check the command.
            app = pf2.probe.plot.Explore3D(tc.proc, 'Visible', 'off');
            cl = onCleanup(@() delete(app.Fig));
            app.Ctrl.timeMean.Value = 0;
            app.Ctrl.time.Value = min(20, app.Ctrl.time.Max);
            app.Ctrl.timeMean.Callback([], []);   % triggers onChange -> render
            tc.verifyEqual(app.Ctrl.time.Enable, 'on');
            cmd = strjoin(cellstr(app.Ctrl.cmd.String), newline);
            % In time-point mode the command indexes the biomarker by sample.
            tc.verifySubstring(cmd, 'data.HbO(');
        end

    end
end
