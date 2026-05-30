% =========================================================================
% blackberry_segmentation.m
%
% Description:
%   Batch processes all blackberry RGB images in a folder.
%   Uses adaptive histogram equalization + circularity filtering to isolate
%   individual berry blobs. Saves binary circular masks and green overlays.
%
% Output (saved to input_folder/circular_masks/ and /circular_overlays/):
%   - <name>_circular.png   : binary mask (1 = berry pixel)
%   - <name>_overlay.png    : green overlay on original image
%
% Author:   Chaitanya Pallerla
% Lab:      SAFE Lab, University of Arkansas
% Updated:  2025
% =========================================================================

clc;
clear;
close all;

% =========================================================================
%  USER CONFIGURATION — Edit only this section
% =========================================================================

% Folder containing all blackberry RGB images (.png)
% Example: "C:\Users\YourName\Data\Blackberry_processed\"
input_folder = 'C:\Users\chinn\Downloads\RESEARCH\Current\BLACKBERRY\Blackberry_processed';  % <-- CHANGE THIS

% Minimum blob area in pixels — smaller regions are discarded as noise
MIN_AREA = 1500;   % <-- adjust if small berries are being missed

% Circularity threshold (0 = any shape, 1 = perfect circle)
% Blackberries are roughly circular — 0.3 works well for drupelets
CIRCULARITY_THRESHOLD = 0.3;   % <-- lower if berries are being missed

% =========================================================================
%  PATHS — built automatically, no need to edit below
% =========================================================================

mask_folder    = fullfile(input_folder, 'circular_masks');
overlay_folder = fullfile(input_folder, 'circular_overlays');

if ~exist(mask_folder,    'dir'), mkdir(mask_folder);    end
if ~exist(overlay_folder, 'dir'), mkdir(overlay_folder); end

image_files = dir(fullfile(input_folder, '*.png'));
fprintf('Found %d images to process.\n\n', length(image_files));

% =========================================================================
%  BATCH PROCESSING LOOP
% =========================================================================

for i = 1:length(image_files)
    filename = image_files(i).name;
    filepath = fullfile(input_folder, filename);

    img = imread(filepath);

    % Enhance contrast and binarize
    grayImage = im2gray(img);
    grayImage = adapthisteq(grayImage);
    BW = imbinarize(grayImage);
    BW = bwareaopen(BW, MIN_AREA);

    % Keep only circular blobs (berry-shaped regions)
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

    % Create green overlay
    overlay = imoverlay(img, circular_mask, [0 1 0]);

    % Save outputs
    [~, name, ~] = fileparts(filename);
    imwrite(circular_mask, fullfile(mask_folder,    [name '_circular.png']));
    imwrite(overlay,       fullfile(overlay_folder, [name '_overlay.png']));

    fprintf('Processed: %s\n', filename);
end

fprintf('\nDone. Masks saved to: %s\n', mask_folder);
