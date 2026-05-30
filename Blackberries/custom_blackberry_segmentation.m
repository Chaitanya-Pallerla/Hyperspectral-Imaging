% =========================================================================
% custom_blackberry_segmentation.m
%
% Description:
%   Interactive GUI tool for manual correction of blackberry segmentation masks.
%   Starts from an auto-generated circular mask (same as blackberry_segmentation.m),
%   then lets the user paint (add) or erase regions with an adjustable brush.
%
%   Use this when automatic segmentation misses berries or includes background.
%
% Controls (inside the brush window):
%   A key   — switch to ADD mode (paint berry regions)
%   E key   — switch to ERASE mode (remove non-berry regions)
%   Slider  — adjust brush size (1–50 pixels)
%   Drag    — paint over the image
%   Close   — finish editing and save
%
% Output (saved to input_folder/circular_masks/ and /circular_overlays/):
%   - <name>_circular.png   : corrected binary mask
%   - <name>_overlay.png    : green overlay showing final mask
%
% Author:   Chaitanya Pallerla
% Lab:      SAFE Lab, University of Arkansas
% Updated:  2025
% =========================================================================

function custom_blackberry_segmentation()

clc;
clear;
close all;

% =========================================================================
%  USER CONFIGURATION — Edit only this section
% =========================================================================

% Folder containing blackberry RGB images (.png)
input_folder = 'C:\Users\chinn\Downloads\RESEARCH\Current\BLACKBERRY\Blackberry_processed';  % <-- CHANGE THIS

% Minimum blob area and circularity for auto-segmentation starting point
MIN_AREA             = 1500;   % <-- adjust if small berries are missed
CIRCULARITY_THRESHOLD = 0.3;   % <-- lower if berries are missing from auto mask

% =========================================================================
%  PATHS — built automatically
% =========================================================================

mask_folder    = fullfile(input_folder, 'circular_masks');
overlay_folder = fullfile(input_folder, 'circular_overlays');

if ~exist(mask_folder,    'dir'), mkdir(mask_folder);    end
if ~exist(overlay_folder, 'dir'), mkdir(overlay_folder); end

image_files = dir(fullfile(input_folder, '*.png'));
fprintf('Found %d images.\n\n', length(image_files));

% =========================================================================
%  BATCH LOOP WITH INTERACTIVE CORRECTION
% =========================================================================

for i = 1:length(image_files)
    filename = image_files(i).name;
    filepath = fullfile(input_folder, filename);

    img = imread(filepath);

    % Auto-generate initial circular mask
    grayImage = im2gray(img);
    grayImage  = adapthisteq(grayImage);
    BW = imbinarize(grayImage);
    BW = bwareaopen(BW, MIN_AREA);

    [labeled_mask, num] = bwlabel(BW);
    stats = regionprops(labeled_mask, 'Area', 'Perimeter', 'PixelIdxList');
    circular_mask = false(size(BW));

    for k = 1:num
        A = stats(k).Area;
        P = stats(k).Perimeter;
        if P == 0, continue; end
        circularity = 4 * pi * A / (P^2);
        if circularity >= CIRCULARITY_THRESHOLD
            circular_mask(stats(k).PixelIdxList) = true;
        end
    end

    [~, name, ~] = fileparts(filename);

    % Interactive correction loop
    satisfied = false;
    while ~satisfied
        overlay = imoverlay(img, circular_mask, [0 1 0]);
        figure;
        imshow(overlay);
        title(['Review: ' filename ' — close when done inspecting']);

        reply = input('Is segmentation OK? (y/n): ', 's');
        close;

        if lower(reply) == 'n'
            circular_mask = brush_tool(img, circular_mask, 10);
        else
            satisfied = true;
        end
    end

    % Save corrected mask and overlay
    overlay = imoverlay(img, circular_mask, [0 1 0]);
    outMaskPath    = fullfile(mask_folder,    [name '_circular.png']);
    outOverlayPath = fullfile(overlay_folder, [name '_overlay.png']);

    try
        imwrite(circular_mask, outMaskPath);
        imwrite(overlay,       outOverlayPath);
        fprintf('Saved: %s\n', filename);
    catch ME
        fprintf('Error saving %s: %s\n', filename, ME.message);
    end
end

fprintf('\nDone. All corrected masks saved to: %s\n', mask_folder);
end

% =========================================================================
%  BRUSH TOOL — internal helper function
%  A=Add mode, E=Erase mode, Slider=brush size, Drag=paint, Close=done
% =========================================================================

function mask = brush_tool(img, mask, initBrushSize)

modeAdd   = true;
brushSize = initBrushSize;

f = figure('Name','Brush Tool — A=Add  E=Erase  Close=Done', ...
           'Units','normalized','Position',[0.1 0.1 0.7 0.8]);

panelHeight = 0.08;
panel = uipanel('Parent',f,'Units','normalized', ...
                'Position',[0 1-panelHeight 1 panelHeight]);
ax    = axes('Parent',f,'Position',[0 0 1 1-panelHeight]);

imshow(imoverlay(img, mask, [0 1 0]), 'Parent', ax);
title(ax, 'Brush Tool: Drag to paint.  A = Add  |  E = Erase  |  Close when done.');

% Brush size slider
uicontrol('Parent',panel,'Style','text','Units','normalized', ...
          'Position',[0.05 0.2 0.2 0.6],'String','Brush Size', ...
          'FontSize',10,'BackgroundColor',[0.8 0.8 0.8]);
sld = uicontrol('Parent',panel,'Style','slider','Units','normalized', ...
                'Min',1,'Max',50,'Value',initBrushSize, ...
                'Position',[0.3 0.3 0.6 0.4]);
addlistener(sld,'ContinuousValueChange',@(src,~) setBrushSize(src));

    function setBrushSize(src)
        brushSize = round(src.Value);
    end

painting = false;

set(f,'WindowButtonDownFcn',  @startPaint);
set(f,'WindowButtonUpFcn',    @stopPaint);
set(f,'WindowButtonMotionFcn',@doPaint);
set(f,'KeyPressFcn',          @switchMode);

    function switchMode(~, evt)
        if strcmpi(evt.Key,'a')
            modeAdd = true;  disp('Mode: ADD');
        elseif strcmpi(evt.Key,'e')
            modeAdd = false; disp('Mode: ERASE');
        end
    end

    function startPaint(~,~), painting = true;  doPaint(); end
    function stopPaint(~,~),  painting = false; end

    function doPaint(~,~)
        if ~painting, return; end
        cp = get(ax,'CurrentPoint');
        cx = round(cp(1,1)); cy = round(cp(1,2));
        if cx<1||cx>size(mask,2)||cy<1||cy>size(mask,1), return; end

        [X,Y]     = meshgrid(1:size(mask,2), 1:size(mask,1));
        circleMask = (X-cx).^2 + (Y-cy).^2 <= brushSize^2;

        if modeAdd
            mask(circleMask) = 1;
        else
            mask(circleMask) = 0;
        end

        modeStr = 'ADD'; if ~modeAdd, modeStr = 'ERASE'; end
        imshow(imoverlay(img, mask, [0 1 0]), 'Parent', ax);
        title(ax, sprintf('Brush %s (size %d) — A=Add  E=Erase  Close=Done', modeStr, brushSize));
    end

uiwait(f);
end
