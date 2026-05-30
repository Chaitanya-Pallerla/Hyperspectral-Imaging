% =========================================================================
% single_berry_extract_data.m
%
% Description:
%   Single-sample spectral extraction for one blackberry HSI scan.
%   Segments berries using adaptive histogram equalization + circularity
%   filtering, then extracts calibrated reflectance spectra from the
%   circular berry mask. Good for exploring a new dataset or spot-checking
%   results before running batch processing.
%
% Outputs (workspace variables):
%   - circular_mask  : binary mask (H x W), 1 = berry pixels
%   - calibrated_data: calibrated reflectance cube (H x W x Bands)
%   - extracted_data : per-pixel spectra (Bands x N_pixels)
%   - E              : raw mean spectrum (Bands x 1)
%   - E_smoothed     : SG-smoothed mean spectrum (Bands x 1)
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
DATA_ROOT = "O:\Blackberry_data\Caddo\Caddo_Row_06_2025-06-24\";  % <-- CHANGE THIS

% Dataset folder name (HSI cube + dark/white refs are inside this folder)
SAMPLE_NAME  = "Anthony_Caddo_2025_06_24_0741_06_B1_2025-06-24_18-00-28";   % <-- CHANGE THIS

% RGB preview image name (may differ from SAMPLE_NAME by a suffix)
IMG_NAME     = "Anthony_Caddo_2025_06_24_0741_06_B1_2025-06-24_18-00-28_1"; % <-- CHANGE THIS

% Segmentation parameters
MIN_AREA             = 1500;   % minimum berry blob area in pixels
CIRCULARITY_THRESHOLD = 0.5;   % circularity threshold (0–1); 0.5 suits round berries

% Savitzky-Golay filter parameters
window_size      = 41;   % must be odd
polynomial_order = 2;

% =========================================================================
%  PATHS — built automatically
% =========================================================================

img_path       = DATA_ROOT + SAMPLE_NAME + "\" + IMG_NAME + ".png";

raw_hdr        = DATA_ROOT + SAMPLE_NAME + "\capture\" + SAMPLE_NAME + ".hdr";
raw_raw        = DATA_ROOT + SAMPLE_NAME + "\capture\" + SAMPLE_NAME + ".raw";

dark_hdr       = DATA_ROOT + SAMPLE_NAME + "\capture\DARKREF_"  + SAMPLE_NAME + ".hdr";
dark_raw_file  = DATA_ROOT + SAMPLE_NAME + "\capture\DARKREF_"  + SAMPLE_NAME + ".raw";

white_hdr      = DATA_ROOT + SAMPLE_NAME + "\capture\WHITEREF_" + SAMPLE_NAME + ".hdr";
white_raw_file = DATA_ROOT + SAMPLE_NAME + "\capture\WHITEREF_" + SAMPLE_NAME + ".raw";

% =========================================================================
%  STEP 1: LOAD IMAGE AND SEGMENT BERRIES
% =========================================================================

fprintf('Loading image and segmenting berries...\n');
img = imread(img_path);

% Enhance contrast and binarize
grayImage = im2gray(img);
grayImage = adapthisteq(grayImage);
BW        = imbinarize(grayImage);
BW        = bwareaopen(BW, MIN_AREA);

% Keep only circular blobs (berry-shaped)
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

% Show segmentation result
figure; imshow(BW);           title('Binary Mask (all regions)');
figure; imshow(circular_mask); title('Circular Berry Mask');
fprintf('Berry pixels in mask: %d\n', sum(circular_mask(:)));

% =========================================================================
%  STEP 2: LOAD HYPERSPECTRAL CUBES
% =========================================================================

fprintf('\nLoading hyperspectral data...\n');

raw_info  = enviinfo(raw_hdr);
raw_data  = multibandread(raw_raw, [raw_info.Height, raw_info.Width, raw_info.Bands], ...
    raw_info.DataType, raw_info.HeaderOffset, raw_info.Interleave, raw_info.ByteOrder);

dark_info = enviinfo(dark_hdr);
dark_data = multibandread(dark_raw_file, [dark_info.Height, dark_info.Width, dark_info.Bands], ...
    dark_info.DataType, dark_info.HeaderOffset, dark_info.Interleave, dark_info.ByteOrder);
dark_data_avg = mean(dark_data, 1);

white_info = enviinfo(white_hdr);
white_data = multibandread(white_raw_file, [white_info.Height, white_info.Width, white_info.Bands], ...
    white_info.DataType, white_info.HeaderOffset, white_info.Interleave, white_info.ByteOrder);
white_data_avg = mean(white_data, 1);

fprintf('Raw:   %d x %d x %d\n', size(raw_data,1),   size(raw_data,2),   size(raw_data,3));
fprintf('Dark:  %d x %d x %d\n', size(dark_data,1),  size(dark_data,2),  size(dark_data,3));
fprintf('White: %d x %d x %d\n', size(white_data,1), size(white_data,2), size(white_data,3));

% =========================================================================
%  STEP 3: CALIBRATE
% =========================================================================

fprintf('\nCalibrating...\n');
epsilon        = 1e-6;
calibrated_data = (raw_data - dark_data_avg) ./ (white_data_avg - dark_data_avg + epsilon);

% =========================================================================
%  STEP 4: EXTRACT ROI SPECTRA
% =========================================================================

fprintf('Extracting spectra from berry mask...\n');

num_bands  = size(calibrated_data, 3);
BW_vector  = circular_mask(:);
roi_idx    = find(BW_vector);
num_pixels = numel(roi_idx);

extracted_data = zeros(num_bands, num_pixels);

for i = 1:num_bands
    image_wavelength        = calibrated_data(:,:,i);
    image_wavelength        = image_wavelength .* circular_mask;
    band_vector             = image_wavelength(:);
    extracted_data(i,:)     = band_vector(roi_idx);
end

% =========================================================================
%  STEP 5: MEAN SPECTRUM AND SG SMOOTHING
% =========================================================================

E        = mean(extracted_data, 2);
E_smoothed = sgolayfilt(E, polynomial_order, window_size);

% =========================================================================
%  STEP 6: PLOT
% =========================================================================

figure;
plot(raw_info.Wavelength, E_smoothed, 'b', 'LineWidth', 2);
title(['Calibrated Reflectance — ', strrep(SAMPLE_NAME, '_', '\_')]);
xlabel('Wavelength (nm)');
ylabel('Reflectance');
grid on;

fprintf('\nDone. Output: E_smoothed (%d x 1)\n', numel(E_smoothed));
