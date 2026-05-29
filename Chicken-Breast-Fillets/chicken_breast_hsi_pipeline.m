clc
clear
close all

% =========================================================================
%  USER CONFIGURATION — Edit only this section
%  All paths and parameters are defined here and used automatically below.
% =========================================================================

% Root folder containing all your hyperspectral datasets
% Windows example : "C:\Users\YourName\Data\woody_breast_400-1000nm\"
% Mac/Linux example: "/home/yourname/data/woody_breast_400-1000nm/"
DATA_ROOT = "O:\woody_breast_400-1000nm\";        % <-- CHANGE THIS

% Sample dataset name to process
SAMPLE_NAME = "chai_WB_08_2025-02-20_23-04-36";   % <-- CHANGE THIS

% Dataset name whose dark/white references will be used for calibration
% (can be the same as SAMPLE_NAME, or a different session's references)
REF_NAME = "Yang_ST_1_2025-02-28_20-10-22";       % <-- CHANGE THIS

% Savitzky-Golay filter parameters
window_size = 41;       % must be odd; larger = smoother
polynomial_order = 2;   % polynomial order for the fit

% Minimum foreground region size in pixels (noise removal)
MIN_AREA = 10000;

% =========================================================================
%  PATHS — built automatically from above, no need to edit below this line
% =========================================================================

img_path        = DATA_ROOT + SAMPLE_NAME + "\" + SAMPLE_NAME + ".png";

raw_data_headfile  = DATA_ROOT + SAMPLE_NAME + "\capture\" + SAMPLE_NAME + ".hdr";
raw_data_datafile  = DATA_ROOT + SAMPLE_NAME + "\capture\" + SAMPLE_NAME + ".raw";

dark_ref_headfile  = DATA_ROOT + REF_NAME + "\capture\DARKREF_"  + REF_NAME + ".hdr";
dark_ref_datafile  = DATA_ROOT + REF_NAME + "\capture\DARKREF_"  + REF_NAME + ".raw";

white_ref_headfile = DATA_ROOT + REF_NAME + "\capture\WHITEREF_" + REF_NAME + ".hdr";
white_ref_datafile = DATA_ROOT + REF_NAME + "\capture\WHITEREF_" + REF_NAME + ".raw";

% =========================================================================
%  SEGMENTATION
% =========================================================================

img = imread(img_path);

% Convert the image to binary
grayImage = im2gray(img);
BW = imbinarize(grayImage);

% Fill holes and remove small objects
BW = imfill(BW,"holes");
BW = bwareaopen(BW, MIN_AREA);
imshow(BW)

%% 

raw_info = enviinfo(raw_data_headfile);
raw_data = multibandread(raw_data_datafile,[raw_info.Height, raw_info.Width, raw_info.Bands],...
       raw_info.DataType, raw_info.HeaderOffset, raw_info.Interleave, raw_info.ByteOrder);

dark_info = enviinfo(dark_ref_headfile);
dark_data = multibandread(dark_ref_datafile, [dark_info.Height, dark_info.Width, dark_info.Bands],...
       dark_info.DataType, dark_info.HeaderOffset, dark_info.Interleave, dark_info.ByteOrder);

dark_data_avg = mean(dark_data, 1);

white_info = enviinfo(white_ref_headfile);
white_data = multibandread(white_ref_datafile, [white_info.Height, white_info.Width, white_info.Bands],...
       white_info.DataType, white_info.HeaderOffset, white_info.Interleave, white_info.ByteOrder);
white_data_avg = mean(white_data, 1);

% Get and display the sizes of raw, dark, and white data
[size_raw_y, size_raw_x, size_raw_bands] = size(raw_data);
disp(['Raw Data Size: ', num2str(size_raw_y), ' x ', num2str(size_raw_x), ' x ', num2str(size_raw_bands)]);

[size_dark_y, size_dark_x, size_dark_bands] = size(dark_data);
disp(['Dark Data Size: ', num2str(size_dark_y), ' x ', num2str(size_dark_x), ' x ', num2str(size_dark_bands)]);

[size_white_y, size_white_x, size_white_bands] = size(white_data);
disp(['White Data Size: ', num2str(size_white_y), ' x ', num2str(size_white_x), ' x ', num2str(size_white_bands)]);

epsilon = 1e-6;

% Apply the calibration directly without loop (more efficient)
calibrated_data = (raw_data - dark_data_avg) ./ (white_data_avg - dark_data_avg + epsilon);

%% 

find (BW==1);
[m,n]= find (BW==1);
pos = [m';n'];

for i=1:size(calibrated_data, 3)
    image_wavelenth = calibrated_data(:,:,i);
    image_wavelenth= image_wavelenth.*BW;
    image_vector= image_wavelenth(:);
    BW_vector=BW(:);
    extracted_data_wavelength = image_vector(find(BW_vector));
    extracted_data(i,:)=extracted_data_wavelength;

end

%% 
E = mean(extracted_data, 2);

% Apply the Savitzky-Golay filter
E_smoothed = sgolayfilt(E, polynomial_order, window_size);

%% 
figure;

% Plot Calibrated Reflectance
plot(raw_info.Wavelength, E_smoothed, 'b', 'LineWidth', 2);
title(['Calibrated Reflectance — ', strrep(SAMPLE_NAME, '_', '\_')]);
xlabel('Wavelength (nm)');
ylabel('Reflectance');
grid on;
