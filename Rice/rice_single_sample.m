% =========================================================================
% rice_single_sample.m
%
% Description:
%   Single-sample hyperspectral pipeline for rice grain analysis.
%   Crops a defined ROI from the RGB preview, segments grains via binary
%   thresholding, calibrates with dark/white references, extracts and
%   normalises the mean reflectance spectrum, and plots results.
%
% Outputs (workspace + figures):
%   - BW              : binary grain mask (H x W)
%   - calibrated_data : calibrated reflectance cube (H x W x Bands)
%   - extracted_data  : per-pixel spectra (Bands x N_pixels)
%   - E_normalized    : normalised mean reflectance spectrum (Bands x 1)
%
% Author:   Chaitanya Pallerla
% Lab:      SAFE Lab, University of Arkansas
% Updated:  2025
% =========================================================================

clc
clear
close all

% =========================================================================
%  USER CONFIGURATION — Edit only this section
% =========================================================================

% Root folder containing the dataset
% Example: "C:\Users\YourName\Data\"
DATA_ROOT = "C:\Users\chinn\Downloads\";   % <-- CHANGE THIS

% Dataset name (folder and filename prefix)
SAMPLE_NAME = "chai_brown_rice_test_2025-01-31_16-36-25";   % <-- CHANGE THIS

% ROI crop coordinates (pixels) — adjust to frame the grain tray
% Use MATLAB's imtool or ginput to find the correct coordinates for your image
x1 = 419;  y1 = 447;   % top-left corner
x2 = 659;  y2 = 676;   % bottom-right corner

% =========================================================================
%  PATHS — built automatically
% =========================================================================

img_path       = DATA_ROOT + SAMPLE_NAME + "\" + SAMPLE_NAME + ".png";
raw_hdr        = DATA_ROOT + SAMPLE_NAME + "\capture\" + SAMPLE_NAME + ".hdr";
raw_raw        = DATA_ROOT + SAMPLE_NAME + "\capture\" + SAMPLE_NAME + ".raw";
dark_hdr       = DATA_ROOT + SAMPLE_NAME + "\capture\DARKREF_" + SAMPLE_NAME + ".hdr";
dark_raw_file  = DATA_ROOT + SAMPLE_NAME + "\capture\DARKREF_" + SAMPLE_NAME + ".raw";
white_hdr      = DATA_ROOT + SAMPLE_NAME + "\capture\WHITEREF_" + SAMPLE_NAME + ".hdr";
white_raw_file = DATA_ROOT + SAMPLE_NAME + "\capture\WHITEREF_" + SAMPLE_NAME + ".raw";

% =========================================================================
%  STEP 1: LOAD IMAGE AND CROP ROI
% =========================================================================

fprintf('Loading RGB preview and cropping ROI...\n');
img     = imread(img_path);
crp_img = img(y1:y2, x1:x2, :);

% =========================================================================
%  STEP 2: SEGMENT GRAINS (BINARY MASK)
% =========================================================================

fprintf('Segmenting grains...\n');
grayImage = im2gray(crp_img);
BW        = imbinarize(grayImage);
BW        = imfill(BW, "holes");
BW        = bwareaopen(BW, 1);

figure;
imshow(BW);
title('Binary Grain Mask');

%% =========================================================================
%  STEP 3: LOAD HYPERSPECTRAL CUBES
% =========================================================================

fprintf('Loading hyperspectral data...\n');

raw_info  = enviinfo(raw_hdr);
raw_data  = multibandread(raw_raw, [raw_info.Height, raw_info.Width, raw_info.Bands], ...
    raw_info.DataType, raw_info.HeaderOffset, raw_info.Interleave, raw_info.ByteOrder);

dark_info = enviinfo(dark_hdr);
dark_data = multibandread(dark_raw_file, [dark_info.Height, dark_info.Width, dark_info.Bands], ...
    dark_info.DataType, dark_info.HeaderOffset, dark_info.Interleave, dark_info.ByteOrder);

white_info = enviinfo(white_hdr);
white_data = multibandread(white_raw_file, [white_info.Height, white_info.Width, white_info.Bands], ...
    white_info.DataType, white_info.HeaderOffset, white_info.Interleave, white_info.ByteOrder);

% =========================================================================
%  STEP 4: CROP AND CALIBRATE
% =========================================================================

fprintf('Cropping and calibrating...\n');

cropped_raw_data   = raw_data(y1:y2, x1:x2, :);
cropped_dark_data  = dark_data(:, x1:x2, :);
cropped_white_data = white_data(:, x1:x2, :);

cropped_dark_avg  = mean(cropped_dark_data,  1);
cropped_white_avg = mean(cropped_white_data, 1);

calibrated_data = cropped_raw_data;
for i = 1:size(cropped_raw_data, 1)
    calibrated_data(i,:,:) = (calibrated_data(i,:,:) - cropped_dark_avg) ./ ...
                              (cropped_white_avg - cropped_dark_avg);
end

% =========================================================================
%  STEP 5: EXTRACT ROI SPECTRA
% =========================================================================

fprintf('Extracting spectra...\n');

find(BW == 1);
[m, n] = find(BW == 1);
pos = [m'; n'];

for i = 1:size(calibrated_data, 3)
    image_wavelenth              = calibrated_data(:,:,i);
    image_wavelenth              = image_wavelenth .* BW;
    image_vector                 = image_wavelenth(:);
    BW_vector                    = BW(:);
    extracted_data_wavelength    = image_vector(find(BW_vector));
    extracted_data(i,:)          = extracted_data_wavelength;
end

% =========================================================================
%  STEP 6: MEAN SPECTRUM AND NORMALISATION
% =========================================================================

E            = mean(extracted_data, 2);
E_normalized = (E - min(E)) / (max(E) - min(E));

% =========================================================================
%  STEP 7: PLOTS
% =========================================================================

% Calibrated reflectance
figure;
plot(raw_info.Wavelength, E_normalized, 'b', 'LineWidth', 2);
title(['Calibrated Reflectance — ', strrep(SAMPLE_NAME, '_', '\_')]);
xlabel('Wavelength (nm)');
ylabel('Normalised Reflectance');
grid on;

% Dark reference
dark_avg_spectrum  = squeeze(mean(cropped_dark_avg,  [1,2]));
white_avg_spectrum = squeeze(mean(cropped_white_avg, [1,2]));

figure;
plot(raw_info.Wavelength, dark_avg_spectrum, 'r', 'LineWidth', 2);
title('Dark Reference'); xlabel('Wavelength (nm)'); ylabel('Reflectance'); grid on;

figure;
plot(raw_info.Wavelength, white_avg_spectrum, 'g', 'LineWidth', 2);
title('White Reference'); xlabel('Wavelength (nm)'); ylabel('Reflectance'); grid on;

% Raw cropped spectrum
cropped_raw_spectrum = squeeze(mean(mean(cropped_raw_data, 1), 2));
figure;
plot(raw_info.Wavelength, cropped_raw_spectrum, 'k', 'LineWidth', 2);
title('Cropped Raw Spectrum'); xlabel('Wavelength (nm)'); ylabel('Intensity'); grid on;

fprintf('\nDone. Output: E_normalized (%d x 1)\n', numel(E_normalized));
