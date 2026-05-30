% =========================================================================
% grid_loop_horizontal_rice.m
%
% Description:
%   Per-grain hyperspectral extraction for rice trays arranged in a grid.
%   Segments individual grains from a cropped ROI, sorts them row-by-row
%   left-to-right, then extracts and saves the calibrated reflectance
%   spectrum for each grain individually. After all grains are processed,
%   stacks spectra into a matrix and saves as .mat and .csv.
%
%   Supports both rough rice and brown (dehusked) rice datasets.
%   Dark/white references can come from the same folder or a separate one.
%
% Output:
%   - Per-grain .mat files in output_folder_path
%   - Stacked matrix saved as .mat and .csv
%   - Per-grain reflectance figure (displayed during processing)
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

% Root folder containing the dataset
% Example: "C:\Users\YourName\Data\Rice_dehusked\"
DATA_ROOT = "C:\Users\chinn\Downloads\Retook_RICE_dehusked_400\";   % <-- CHANGE THIS

% Dataset name (folder and filename prefix)
SAMPLE_NAME = "chai_retook_rice_dehusked_201-300_2024-11-17_21-44-45";  % <-- CHANGE THIS

% If dark/white references come from a different folder, set a separate path.
% Set USE_SEPARATE_REF = false if references are in the same folder as the sample.
USE_SEPARATE_REF = false;                        % <-- CHANGE IF NEEDED
REF_ROOT         = "C:\Users\chinn\Downloads\";  % <-- CHANGE IF USE_SEPARATE_REF = true
REF_NAME         = "Chai_rice_LGP22_2024-02-10_00-31-55";  % <-- CHANGE IF USE_SEPARATE_REF = true

% ROI crop coordinates (pixels) — frame the grain tray
% Use MATLAB's imtool to find the correct values for your image
x1 = 243;  y1 = 118;   % top-left
x2 = 829;  y2 = 613;   % bottom-right

% Grain row grouping threshold (pixels)
% Grains within this y-distance are treated as the same row
ROW_THRESHOLD = 15;   % <-- increase if grains in the same row are being split

% Starting grain counter (set to 1 for first batch, 101 for second, etc.)
GRAIN_START = 1;   % <-- CHANGE for each batch (1, 101, 201, 301...)

% Output folder for per-grain .mat files
output_folder_path = DATA_ROOT + "ED_all_" + num2str(GRAIN_START) + "_" + ...
                     num2str(GRAIN_START+99) + "\";   % auto-named, or set manually

% Name for the final stacked output variable and file
STACK_VAR_NAME = "stacked_ED";   % <-- change to match your naming convention
STACK_SAVE_NAME = "stacked_E_" + num2str(GRAIN_START) + "_" + ...
                  num2str(GRAIN_START+99);

% =========================================================================
%  PATHS — built automatically
% =========================================================================

base_path = DATA_ROOT + SAMPLE_NAME + "\";
img_path  = base_path + SAMPLE_NAME + ".png";

raw_hdr   = base_path + "capture\" + SAMPLE_NAME + ".hdr";
raw_raw   = base_path + "capture\" + SAMPLE_NAME + ".raw";
dark_hdr  = base_path + "capture\DARKREF_"  + SAMPLE_NAME + ".hdr";
dark_raw_file = base_path + "capture\DARKREF_"  + SAMPLE_NAME + ".raw";

if USE_SEPARATE_REF
    white_hdr      = REF_ROOT + REF_NAME + "\capture\WHITEREF_" + REF_NAME + ".hdr";
    white_raw_file = REF_ROOT + REF_NAME + "\capture\WHITEREF_" + REF_NAME + ".raw";
else
    white_hdr      = base_path + "capture\WHITEREF_" + SAMPLE_NAME + ".hdr";
    white_raw_file = base_path + "capture\WHITEREF_" + SAMPLE_NAME + ".raw";
end

if ~exist(output_folder_path, 'dir'), mkdir(output_folder_path); end

% =========================================================================
%  STEP 1: LOAD AND CROP IMAGE
% =========================================================================

fprintf('Loading image...\n');
img     = imread(img_path);
crp_img = img(y1:y2, x1:x2, :);

% =========================================================================
%  STEP 2: SEGMENT AND LABEL GRAINS
% =========================================================================

fprintf('Segmenting grains...\n');
grayImage = im2gray(crp_img);
BW        = imbinarize(grayImage);
BW        = imfill(BW, "holes");
BW        = bwareaopen(BW, 10);

[labeledImage, numberOfGrains] = bwlabel(BW);
grainProps = regionprops(labeledImage, 'Centroid');
centroids  = cat(1, grainProps.Centroid);

fprintf('Grains detected: %d\n', numberOfGrains);

% =========================================================================
%  STEP 3: SORT GRAINS ROW-BY-ROW, LEFT-TO-RIGHT
% =========================================================================

[~, rowSortedIndices] = sortrows(centroids, 2);

rowNumber  = 1;
rows       = cell(1, 1);
currentRowY = centroids(rowSortedIndices(1), 2);
rows{rowNumber} = rowSortedIndices(1);

for i = 2:numberOfGrains
    grainY = centroids(rowSortedIndices(i), 2);
    if abs(grainY - currentRowY) < ROW_THRESHOLD
        rows{rowNumber} = [rows{rowNumber}, rowSortedIndices(i)];
    else
        rowNumber   = rowNumber + 1;
        currentRowY = grainY;
        rows{rowNumber} = rowSortedIndices(i);
    end
end

% Sort each row left-to-right by x-coordinate
for rowIdx = 1:length(rows)
    currentRowIndices = rows{rowIdx};
    [~, sortedRowIndices] = sort(centroids(currentRowIndices, 1));
    rows{rowIdx} = currentRowIndices(sortedRowIndices);
end

% =========================================================================
%  STEP 4: LOAD HYPERSPECTRAL CUBES ONCE (shared across all grains)
% =========================================================================

fprintf('Loading hyperspectral cubes...\n');

raw_info  = enviinfo(raw_hdr);
dark_info = enviinfo(dark_hdr);
white_info = enviinfo(white_hdr);

raw_data  = multibandread(raw_raw, [raw_info.Height, raw_info.Width, raw_info.Bands], ...
    raw_info.DataType, raw_info.HeaderOffset, raw_info.Interleave, raw_info.ByteOrder);
dark_data = multibandread(dark_raw_file, [dark_info.Height, dark_info.Width, dark_info.Bands], ...
    dark_info.DataType, dark_info.HeaderOffset, dark_info.Interleave, dark_info.ByteOrder);
white_data = multibandread(white_raw_file, [white_info.Height, white_info.Width, white_info.Bands], ...
    white_info.DataType, white_info.HeaderOffset, white_info.Interleave, white_info.ByteOrder);

% Crop raw/dark/white to the same ROI
cropped_raw_data   = raw_data(y1:y2, x1:x2, :);
cropped_dark_data  = dark_data(:, x1:x2, :);
cropped_white_data = white_data(:, x1:x2, :);

cropped_dark_avg  = mean(cropped_dark_data,  1);
cropped_white_avg = mean(cropped_white_data, 1);

% Calibrate the full cropped cube once
calibrated_data = cropped_raw_data;
for i = 1:size(cropped_raw_data, 1)
    calibrated_data(i,:,:) = (calibrated_data(i,:,:) - cropped_dark_avg) ./ ...
                              (cropped_white_avg - cropped_dark_avg);
end

% =========================================================================
%  STEP 5: PER-GRAIN EXTRACTION LOOP
% =========================================================================

grainCounter = GRAIN_START;

for rowIdx = 1:length(rows)
    currentRowIndices = rows{rowIdx};

    for k = 1:length(currentRowIndices)

        grainIdx   = currentRowIndices(k);
        binaryMask = (labeledImage == grainIdx);

        % Preview current grain mask
        figure;
        imshow(binaryMask);
        title(['Grain ' num2str(grainCounter)]);
        pause(0.5);
        close;

        % Extract per-band spectra for this grain
        extracted_data = zeros(size(calibrated_data, 3), sum(binaryMask(:)));
        BW_vector      = binaryMask(:);
        roi_idx        = find(BW_vector);

        for b = 1:size(calibrated_data, 3)
            image_wavelength    = calibrated_data(:,:,b);
            image_wavelength    = image_wavelength .* binaryMask;
            band_vector         = image_wavelength(:);
            extracted_data(b,:) = band_vector(roi_idx);
        end

        % Mean spectrum for this grain
        ED_all = mean(extracted_data, 2);

        % Plot
        figure;
        plot(raw_info.Wavelength, ED_all);
        title(['Grain ' num2str(grainCounter) ' — Mean Reflectance']);
        xlabel('Wavelength (nm)'); ylabel('Reflectance'); grid on;
        pause(0.3); close;

        % Save to workspace and .mat file
        assignin('base', ['ED_all' num2str(grainCounter)], ED_all);
        output_filename = fullfile(output_folder_path, ['ED_all' num2str(grainCounter) '.mat']);
        save(output_filename, 'ED_all');

        fprintf('  Grain %d saved.\n', grainCounter);
        grainCounter = grainCounter + 1;
    end
end

% =========================================================================
%  STEP 6: STACK ALL GRAIN SPECTRA AND SAVE
% =========================================================================

fprintf('\nStacking grain spectra...\n');
stacked = [];

for i = GRAIN_START:(grainCounter-1)
    var_name = sprintf('ED_all%d', i);
    if evalin('base', sprintf('exist(''%s'', ''var'')', var_name))
        data = evalin('base', var_name);
        if size(data, 1) == raw_info.Bands
            stacked = [stacked, data];  %#ok
        else
            warning('%s has unexpected size — skipping.', var_name);
        end
    else
        warning('%s not found in workspace — skipping.', var_name);
    end
end

assignin('base', STACK_VAR_NAME, stacked);
fprintf('Stacked matrix size: %d x %d\n', size(stacked,1), size(stacked,2));

save(STACK_SAVE_NAME + ".mat", 'stacked');
writematrix(stacked, STACK_SAVE_NAME + ".csv");

fprintf('\nDone. Stacked data saved to %s\n', STACK_SAVE_NAME);

% =========================================================================
%  STEP 7: PLOT STACKED SPECTRA
% =========================================================================

figure;
plot(raw_info.Wavelength, stacked);
title('All Grain Spectra — Stacked');
xlabel('Wavelength (nm)'); ylabel('Reflectance'); grid on;
