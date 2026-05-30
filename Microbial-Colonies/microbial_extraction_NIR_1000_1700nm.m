% =========================================================================
% microbial_extraction_NIR_1000_1700nm.m
%
% Description:
%   Batch pipeline for per-colony hyperspectral spectral extraction
%   from microbial agar plate images — NIR range (1000–1700 nm, 224 bands).
%
%   Auto-detects all Yang_* dataset folders under root_path, segments
%   individual colonies using CLAHE + inverted Otsu thresholding +
%   area filtering, calibrates the NIR cube, extracts and SG-smooths
%   per-colony spectra, and saves all outputs per dataset.
%
% Output structure (inside out_root/<dataset_name>/):
%   reference_graphs/     → dark_reference.png, white_reference.png
%   BW_Img/               → per-colony binary mask images
%   data/                 → per-colony .mat + .csv + wavelength files
%   Graph_of_each_colony/ → per-colony reflectance plots
%   stacked_data/         → stacked matrix (.mat, .csv, .png) + overall_BW.png
%
% Author:   Chaitanya Pallerla
% Lab:      SAFE Lab, University of Arkansas
% Updated:  2025
% =========================================================================

function microbial_extraction_NIR_1000_1700nm()

clc; clear; close all;

% =========================================================================
%  USER CONFIGURATION — Edit only this section
% =========================================================================

% Root folder containing all Yang_* dataset folders
% Example: "C:\Users\YourName\Data\Yang_1700\"
root_path = 'F:\Yang_Extra';           % <-- CHANGE THIS

% Root folder where all processed outputs will be saved
out_root  = fullfile(root_path, 'Processed_1000_1700nm');  % <-- CHANGE IF NEEDED

% Colony size filter (pixels) — adjust if colonies are being missed or noise included
MIN_COLONY_AREA = 5;      % <-- minimum colony area in pixels
MAX_COLONY_AREA = 5000;   % <-- maximum colony area in pixels

% Savitzky-Golay filter parameters
SG_WINDOW = 31;   % must be odd
SG_ORDER  = 2;

% Target number of bands after wavelength resampling
TARGET_BANDS = 224;

% =========================================================================
%  MAIN BATCH LOOP — processes every Yang_* folder automatically
% =========================================================================

if ~exist(out_root, 'dir'), mkdir(out_root); end

dsets = dir(fullfile(root_path, 'Yang_*'));
dsets = dsets([dsets.isdir]);
fprintf('Found %d Yang_* datasets.\n\n', numel(dsets));

for k = 1:numel(dsets)
    dataset_name = dsets(k).name;
    fprintf('=== Processing: %s ===\n', dataset_name);

    % Per-dataset output subfolders
    ds_root    = fullfile(out_root, dataset_name);
    ref_dir    = fullfile(ds_root, 'reference_graphs');
    bw_dir     = fullfile(ds_root, 'BW_Img');
    data_dir   = fullfile(ds_root, 'data');
    colony_dir = fullfile(ds_root, 'Graph_of_each_colony');
    stack_dir  = fullfile(ds_root, 'stacked_data');

    for d = {ds_root, ref_dir, bw_dir, data_dir, colony_dir, stack_dir}
        if ~exist(d{1}, 'dir'), mkdir(d{1}); end
    end

    % File paths — built from dataset_name
    png_file  = fullfile(root_path, dataset_name, [dataset_name '.png']);
    raw_hdr   = fullfile(root_path, dataset_name, 'capture', [dataset_name '.hdr']);
    raw_raw   = fullfile(root_path, dataset_name, 'capture', [dataset_name '.raw']);
    dark_hdr  = fullfile(root_path, dataset_name, 'capture', ['DARKREF_'  dataset_name '.hdr']);
    dark_raw  = fullfile(root_path, dataset_name, 'capture', ['DARKREF_'  dataset_name '.raw']);
    white_hdr = fullfile(root_path, dataset_name, 'capture', ['WHITEREF_' dataset_name '.hdr']);
    white_raw = fullfile(root_path, dataset_name, 'capture', ['WHITEREF_' dataset_name '.raw']);

    % =====================================================================
    %  STEP 1: COLONY SEGMENTATION
    % =====================================================================

    img = imread(png_file);
    if size(img,3) == 3
        gray_img = rgb2gray(img);
    else
        gray_img = img;
    end

    % CLAHE + inverted Otsu — isolates dark colonies on bright agar
    clahe_img = adapthisteq(gray_img);
    thr = graythresh(clahe_img);
    BW  = ~imbinarize(clahe_img, thr);
    BW  = bwareaopen(BW, 50);

    % Fill small holes inside colony blobs
    filled = imfill(BW, 'holes');
    holes  = filled & ~BW;
    st     = regionprops(holes, 'Area');
    if ~isempty(st)
        small_holes = ismember(bwlabel(holes), find([st.Area] <= 50));
        BW = BW | small_holes;
    end

    % Keep only regions within colony size range
    CC_all    = bwconncomp(~BW);
    stats_all = regionprops(CC_all, 'Area');
    valid_idx = find([stats_all.Area] >= MIN_COLONY_AREA & ...
                     [stats_all.Area] <= MAX_COLONY_AREA);
    filtered_mask        = ismember(labelmatrix(CC_all), valid_idx);
    final_binary_mask_u8 = uint8(filtered_mask) * 255;

    imwrite(final_binary_mask_u8, fullfile(stack_dir, 'overall_BW.png'));

    BW          = logical(final_binary_mask_u8);
    CC          = bwconncomp(BW);
    numColonies = CC.NumObjects;
    fprintf('  Colonies detected: %d\n', numColonies);

    % =====================================================================
    %  STEP 2: LOAD AND CALIBRATE HSI CUBE
    % =====================================================================

    raw_info   = enviinfo(raw_hdr);
    dark_info  = enviinfo(dark_hdr);
    white_info = enviinfo(white_hdr);

    raw_data   = multibandread(raw_raw,   [raw_info.Height,   raw_info.Width,   raw_info.Bands], ...
        raw_info.DataType,   raw_info.HeaderOffset,   raw_info.Interleave,  raw_info.ByteOrder);
    dark_data  = multibandread(dark_raw,  [dark_info.Height,  dark_info.Width,  dark_info.Bands], ...
        dark_info.DataType,  dark_info.HeaderOffset,  dark_info.Interleave, raw_info.ByteOrder);
    white_data = multibandread(white_raw, [white_info.Height, white_info.Width, white_info.Bands], ...
        white_info.DataType, white_info.HeaderOffset, white_info.Interleave, raw_info.ByteOrder);

    dark_avg   = mean(dark_data,  1);
    white_avg  = mean(white_data, 1);
    dark_avg1  = squeeze(mean(dark_data,  [1 2]));
    white_avg1 = squeeze(mean(white_data, [1 2]));

    epsilon    = 1e-6;
    calibrated = (raw_data - dark_avg) ./ (white_avg - dark_avg + epsilon);

    % Save reference plots
    fig = figure('Visible','off');
    plot(raw_info.Wavelength, dark_avg1, 'LineWidth', 1.5);
    xlabel('Wavelength (nm)'); ylabel('Signal'); title('Dark Reference','Interpreter','none');
    saveas(fig, fullfile(ref_dir, 'dark_reference.png')); close(fig);

    fig = figure('Visible','off');
    plot(raw_info.Wavelength, white_avg1, 'LineWidth', 1.5);
    xlabel('Wavelength (nm)'); ylabel('Signal'); title('White Reference','Interpreter','none');
    saveas(fig, fullfile(ref_dir, 'white_reference.png')); close(fig);

    % =====================================================================
    %  STEP 3: CROP TO 1000–1700 nm AND RESAMPLE TO 224 BANDS
    % =====================================================================

    wl      = raw_info.Wavelength(:);
    wl_mask = wl >= 1000 & wl <= 1700;
    [H, W, B] = size(calibrated);
    idx     = find(wl_mask);

    if numel(idx) == TARGET_BANDS
        wl_sel   = wl(idx);
        cube_sel = calibrated(:,:,idx);
    else
        if ~any(wl_mask)
            warning('No wavelengths within 1000-1700 nm for %s — skipping.', dataset_name);
            continue;
        end
        wl_sel   = linspace(max(1000, min(wl(wl_mask))), ...
                            min(1700, max(wl(wl_mask))), TARGET_BANDS).';
        D        = reshape(calibrated, [], B);
        D_interp = interp1(wl, D.', wl_sel, 'linear', 'extrap');
        cube_sel = reshape(D_interp.', H, W, TARGET_BANDS);
    end

    % Save wavelength vector
    writematrix(wl_sel, fullfile(data_dir, ...
        sprintf('wavelengths_%s_1000_1700nm_224b.csv', dataset_name)));
    save(fullfile(data_dir, ...
        sprintf('wavelengths_%s_1000_1700nm_224b.mat', dataset_name)), 'wl_sel');

    % =====================================================================
    %  STEP 4: PER-COLONY EXTRACTION
    % =====================================================================

    stacked_data = [];

    for i = 1:numColonies
        colony_mask = false(size(BW));
        colony_mask(CC.PixelIdxList{i}) = true;

        imwrite(uint8(colony_mask)*255, ...
            fullfile(bw_dir, sprintf('BW_colony_%03d.png', i)));

        % Extract mean spectrum
        pix_idx  = find(colony_mask);
        spectra  = reshape(cube_sel, [], size(cube_sel,3));
        E_col    = mean(spectra(pix_idx,:), 1).';
        E_col_f  = sgolayfilt(E_col, SG_ORDER, SG_WINDOW);
        stacked_data = [stacked_data, E_col_f];  %#ok

        raw_var  = sprintf('E_%s_colony_%d_1000_1700nm_224b', dataset_name, i);
        safe_var = safe_fieldname(raw_var);

        S.(safe_var) = E_col_f;
        save(fullfile(data_dir, [raw_var '.mat']), '-struct', 'S', safe_var);
        writematrix(E_col_f, fullfile(data_dir, [raw_var '.csv']));

        fig = figure('Visible','off');
        plot(wl_sel, E_col_f, 'LineWidth', 1.5);
        title(sprintf('Colony %d — %s', i, dataset_name), 'Interpreter','none');
        xlabel('Wavelength (nm)'); ylabel('Reflectance');
        saveas(fig, fullfile(colony_dir, [raw_var '.png'])); close(fig);
    end

    % =====================================================================
    %  STEP 5: SAVE STACKED OUTPUTS
    % =====================================================================

    csv_file = fullfile(data_dir, sprintf('stacked_%s_1000_1700nm_224b.csv', dataset_name));
    mat_file = fullfile(data_dir, sprintf('stacked_%s_1000_1700nm_224b.mat', dataset_name));
    writematrix(stacked_data.', csv_file);
    save(mat_file, 'stacked_data', 'wl_sel');

    copyfile(csv_file, fullfile(stack_dir, sprintf('stacked_%s_1000_1700nm_224b.csv', dataset_name)));
    copyfile(mat_file, fullfile(stack_dir, sprintf('stacked_%s_1000_1700nm_224b.mat', dataset_name)));

    fig = figure('Visible','off');
    plot(wl_sel, stacked_data, 'LineWidth', 1.0);
    title(sprintf('Stacked Spectra — %s (1000-1700 nm)', dataset_name), 'Interpreter','none');
    xlabel('Wavelength (nm)'); ylabel('Reflectance');
    saveas(fig, fullfile(stack_dir, sprintf('stacked_%s_1000_1700nm_224b.png', dataset_name)));
    close(fig);

    fprintf('  Done: %s\n', ds_root);
end

fprintf('\nAll datasets processed.\n');
end

% -------------------------------------------------------------------------
%  Helper: safe struct field name from any string
% -------------------------------------------------------------------------
function s = safe_fieldname(name_in)
s = name_in;
try
    s = matlab.lang.makeValidName(name_in, 'ReplacementStyle', 'underscore');
catch
    s = regexprep(s, '\W', '_');
    if ~isempty(s) && isstrprop(s(1), 'digit')
        s = ['x' s];
    end
end
end
