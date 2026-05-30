% =========================================================================
% berry_batch_extraction_optimized.m
%
% Description:
%   Most optimized batch pipeline for per-berry spectral extraction.
%   Auto-detects all Anthony_* folders, assigns berry IDs using box layout,
%   calibrates with wavelength cropping (430–1000 nm), extracts per-berry
%   spectra using vectorized median, applies SG smoothing, saves stacks.
%
%   Key features vs other batch scripts:
%     - Wavelength cropping to reliable 430–1000 nm range
%     - Vectorized median extraction (robust to glare/outliers)
%     - Per-berry BW preview window (auto-closes)
%     - Saves 4 data types per box: reflectance, raw, dark, white stacks
%     - Saves 4 graph types per berry: reflectance, raw, dark, white
%     - Saves labeled mask image per berry
%
% Output structure (inside each Anthony folder):
%   data/         → stack_<B#>.mat + 4 CSV stacks
%   graph/        → per-berry reflectance plots
%   raw_graphs/   → per-berry raw intensity plots
%   dark_graphs/  → per-berry dark reference plots
%   white_graphs/ → per-berry white reference plots
%   label/        → per-berry labeled mask images
%   data_raw/     → (unused in this version — see berry_batch_extraction_full.m)
%
% Author:   Chaitanya Pallerla
% Lab:      SAFE Lab, University of Arkansas
% Updated:  2025
% =========================================================================

clc; clear; close all;

% =========================================================================
%  USER CONFIGURATION — Edit only this section
% =========================================================================

% Root folder containing all Anthony_* dataset folders
base_folder = 'O:\Blackberry_data';   % <-- CHANGE THIS

% Wavelength cropping range (nm) — trims noisy edges of sensor range
crop_min_nm = 430;    % <-- adjust if you need a wider/narrower range
crop_max_nm = 1000;

% Savitzky-Golay smoothing
use_smoothing = true;
sgolay_win    = 71;   % must be odd; static window for consistent outputs
sgolay_ord    = 2;

% Small denominator guard (prevents division by ~0 during calibration)
eps_den = 1e-6;

% Preview settings — shows binary mask for each berry while processing
show_roi_preview  = true;
preview_mode      = 'auto-close';   % 'auto-close' or 'hold'
preview_pause_sec = 0.75;

% Output toggles
save_plots  = true;
save_tables = true;
show_progress = true;

% =========================================================================
%  BOX LABEL MAPPING
% =========================================================================

box_labels = containers.Map;
box_labels('B1') = [1:6,   7:12,  13:18];
box_labels('B2') = [19:24, 25:30, 31:36];
box_labels('B3') = [37:42, 43:48, 49:54];
box_labels('B4') = [55:60, 61:66, 67:72];
box_labels('B5') = [73:78, 79:84, 85:90];
box_labels('B6') = [91:96, 97:102, 103:108];
box_labels('B7') = [109:114, 115:120];

% =========================================================================
%  AUTO-DETECT ANTHONY FOLDERS
% =========================================================================

anthony_folders = dir(fullfile(base_folder, '**', 'Anthony_*'));
anthony_folders = anthony_folders([anthony_folders.isdir]);
fprintf('Found %d Anthony folders.\n\n', numel(anthony_folders));

% =========================================================================
%  MAIN LOOP — one iteration per Anthony folder (one box)
% =========================================================================

for d = 1:numel(anthony_folders)

    anthony_folder = fullfile(anthony_folders(d).folder, anthony_folders(d).name);
    folder_name    = anthony_folders(d).name;

    % Extract box ID and short name from folder name
    parts     = split(folder_name, "_");
    box_id    = parts{end-2};
    idx_box   = find(contains(parts, box_id), 1, 'last');
    short_name = strjoin(parts(1:idx_box), "_");

    if ~isKey(box_labels, box_id)
        fprintf('Skipping %s (unknown box ID)\n', folder_name);
        continue;
    end

    % ----- Create output folders -----
    data_folder        = fullfile(anthony_folder, 'data');
    graph_folder       = fullfile(anthony_folder, 'graph');
    label_folder       = fullfile(anthony_folder, 'label');
    raw_graph_folder   = fullfile(anthony_folder, 'raw_graphs');
    dark_graph_folder  = fullfile(anthony_folder, 'dark_graphs');
    white_graph_folder = fullfile(anthony_folder, 'white_graphs');
    data_raw_folder    = fullfile(anthony_folder, 'data_raw');
    data_dark_folder   = fullfile(anthony_folder, 'data_dark');
    data_white_folder  = fullfile(anthony_folder, 'data_white');

    for f = {data_folder, graph_folder, label_folder, raw_graph_folder, ...
             dark_graph_folder, white_graph_folder, data_raw_folder, ...
             data_dark_folder, data_white_folder}
        if ~exist(f{1},'dir'), mkdir(f{1}); end
    end

    % ----- Load binary mask image -----
    img_files = dir(fullfile(anthony_folder, [folder_name '.*']));
    if isempty(img_files)
        fprintf('No mask image found in: %s\n', folder_name); continue;
    end
    fprintf('Processing: %s\n', folder_name);

    bw = imread(fullfile(img_files(1).folder, img_files(1).name));
    if size(bw,3)>1, bw = rgb2gray(bw); end
    if ~islogical(bw), bw = bw>0; end

    % ----- Label blobs and sort spatially -----
    [labeled, num] = bwlabel(bw);
    stats          = regionprops(labeled, 'Centroid');
    centroids      = cat(1, stats.Centroid);
    [~, sort_x]    = sort(centroids(:,1));
    sorted_centroids = centroids(sort_x,:);

    if strcmp(box_id,'B7')
        n = floor(num/2);
        iL=sort_x(1:n); iR=sort_x(n+1:end);
        cL=sorted_centroids(1:n,:); cR=sorted_centroids(n+1:end,:);
        [~,oL]=sort(cL(:,2)); [~,oR]=sort(cR(:,2));
        final_indices     = [iR(oR); iL(oL)];
        ordered_centroids = [cR(oR,:); cL(oL,:)];
    else
        n=floor(num/3);
        iL=sort_x(1:n); iM=sort_x(n+1:2*n); iR=sort_x(2*n+1:end);
        cL=sorted_centroids(1:n,:); cM=sorted_centroids(n+1:2*n,:); cR=sorted_centroids(2*n+1:end,:);
        [~,oL]=sort(cL(:,2)); [~,oM]=sort(cM(:,2)); [~,oR]=sort(cR(:,2));
        final_indices     = [iR(oR); iM(oM); iL(oL)];
        ordered_centroids = [cR(oR,:); cM(oM,:); cL(oL,:)];
    end

    labels_order = box_labels(box_id);
    max_berries  = min(length(labels_order), num);

    % ----- Load HSI cubes -----
    capture_folder = fullfile(anthony_folder, 'capture');
    raw_info  = enviinfo(fullfile(capture_folder, folder_name + ".hdr"));
    dark_info = enviinfo(fullfile(capture_folder, "DARKREF_"  + folder_name + ".hdr"));
    white_info= enviinfo(fullfile(capture_folder, "WHITEREF_" + folder_name + ".hdr"));

    raw_data   = double(multibandread(fullfile(capture_folder, folder_name + ".raw"), ...
        [raw_info.Height, raw_info.Width, raw_info.Bands], raw_info.DataType, ...
        raw_info.HeaderOffset, raw_info.Interleave, raw_info.ByteOrder));
    dark_data  = double(multibandread(fullfile(capture_folder, "DARKREF_"  + folder_name + ".raw"), ...
        [dark_info.Height, dark_info.Width, dark_info.Bands], dark_info.DataType, ...
        dark_info.HeaderOffset, dark_info.Interleave, dark_info.ByteOrder));
    white_data = double(multibandread(fullfile(capture_folder, "WHITEREF_" + folder_name + ".raw"), ...
        [white_info.Height, white_info.Width, white_info.Bands], white_info.DataType, ...
        white_info.HeaderOffset, white_info.Interleave, white_info.ByteOrder));

    % Per-band global means
    dark_band  = squeeze(mean(mean(dark_data,  1), 2));
    white_band = squeeze(mean(mean(white_data, 1), 2));
    den_band   = white_band - dark_band;

    % Wavelength cropping
    wl_all   = raw_info.Wavelength(:);
    keep_wl  = wl_all >= crop_min_nm & wl_all <= crop_max_nm;
    wl       = wl_all(keep_wl);
    B        = numel(wl);

    % Guard tiny denominators
    den_band(~(den_band > eps_den)) = NaN;

    % Vectorized calibration
    dark_img = reshape(dark_band, 1,1,[]);
    den_img  = reshape(den_band,  1,1,[]);
    calibrated_full = (raw_data - dark_img) ./ den_img;
    calibrated_full = max(calibrated_full, -0.01);
    calibrated_data = calibrated_full(:,:,keep_wl);
    raw_crop        = raw_data(:,:,keep_wl);
    dark_crop_band  = dark_band(keep_wl);
    white_crop_band = white_band(keep_wl);

    % Reshape for fast vectorized ROI ops
    [H,W,~] = size(calibrated_data);
    calib_2d = reshape(calibrated_data, H*W, B);
    raw_2d   = reshape(raw_crop,        H*W, B);

    % Preallocate stacks
    stack_all       = zeros(B, max_berries);
    stack_raw_all   = zeros(B, max_berries);
    stack_dark_all  = repmat(dark_crop_band,  1, max_berries);
    stack_white_all = repmat(white_crop_band, 1, max_berries);

    % ----- Per-berry loop -----
    t0 = tic;
    for k = 1:max_berries
        label_num = labels_order(k);
        BW = (labeled == final_indices(k));

        % Optional BW preview
        if show_roi_preview
            mask_rgb = cat(3, uint8(BW)*255, uint8(BW)*255, uint8(BW)*255);
            figPrev = figure('Visible','on','Name', ...
                sprintf('Berry %d — %s', label_num, short_name));
            imshow(mask_rgb); hold on;
            c = ordered_centroids(k,:);
            text(c(1),c(2),sprintf('%d',label_num),'Color','r','FontSize',16,'FontWeight','bold');
            title(sprintf('%s — Berry %d of %d', short_name, k, max_berries));
            drawnow;
            if strcmp(preview_mode,'auto-close')
                pause(preview_pause_sec); close(figPrev);
            end
        end

        % Vectorized median extraction (robust to glare)
        idx     = BW(:);
        E       = median(calib_2d(idx,:), 1).';
        E_raw   = mean(raw_2d(idx,:), 1, 'omitnan').';

        % SG smoothing
        if use_smoothing && B > sgolay_win
            E_filt = sgolayfilt(E, sgolay_ord, sgolay_win);
        else
            E_filt = E;
        end

        stack_all(:,k)     = E_filt;
        stack_raw_all(:,k) = E_raw;

        safe_name = matlab.lang.makeValidName(short_name);
        var_name  = sprintf('E_%s_Berry_%d', safe_name, label_num);

        % Save plots
        if save_plots
            for plt = {'reflectance','raw','dark','white'}
                fig = figure('Visible','off');
                switch plt{1}
                    case 'reflectance'
                        plot(wl, E_filt,          'b','LineWidth',2);
                        ylabel('Reflectance');
                        title(sprintf('Reflectance - %s Berry %d', short_name, label_num));
                        out = fullfile(graph_folder,       [var_name '_graph.png']);
                    case 'raw'
                        plot(wl, E_raw,            'k','LineWidth',1.5);
                        ylabel('Intensity');
                        title(sprintf('Raw - %s Berry %d', short_name, label_num));
                        out = fullfile(raw_graph_folder,   [var_name '_raw.png']);
                    case 'dark'
                        plot(wl, dark_crop_band,   'r','LineWidth',1.5);
                        ylabel('Intensity');
                        title(sprintf('Dark Ref - %s Berry %d', short_name, label_num));
                        out = fullfile(dark_graph_folder,  [var_name '_dark.png']);
                    case 'white'
                        plot(wl, white_crop_band,  'g','LineWidth',1.5);
                        ylabel('Intensity');
                        title(sprintf('White Ref - %s Berry %d', short_name, label_num));
                        out = fullfile(white_graph_folder, [var_name '_white.png']);
                end
                xlabel('Wavelength (nm)'); grid on;
                saveas(fig, out); close(fig);
            end

            % Save labeled mask image
            mask_rgb = cat(3, uint8(BW)*255, uint8(BW)*255, uint8(BW)*255);
            fig = figure('Visible','off');
            imshow(mask_rgb); hold on;
            c = ordered_centroids(k,:);
            text(c(1),c(2),sprintf('%d',label_num),'Color','r','FontSize',16,'FontWeight','bold');
            frame = getframe(gca);
            imwrite(frame.cdata, fullfile(label_folder,[var_name '_label.png']));
            close(fig);
        end

        if show_progress && (mod(k,5)==0 || k==1)
            fprintf('  Berry %d/%d\n', k, max_berries);
        end
    end
    fprintf('Finished %s (%d berries) in %.1fs\n', short_name, max_berries, toc(t0));

    % ----- Save stacks -----
    sf = fullfile(data_folder, sprintf('stack_%s', box_id));
    save([sf '.mat'], 'stack_all','stack_raw_all','stack_dark_all','stack_white_all','wl');
    if save_tables
        try
            writematrix(stack_all,       [sf '_reflectance.csv']);
            writematrix(stack_raw_all,   [sf '_raw.csv']);
            writematrix(stack_dark_all,  [sf '_dark.csv']);
            writematrix(stack_white_all, [sf '_white.csv']);
        catch
            csvwrite([sf '_reflectance.csv'], stack_all);  %#ok
            csvwrite([sf '_raw.csv'],         stack_raw_all);
            csvwrite([sf '_dark.csv'],         stack_dark_all);
            csvwrite([sf '_white.csv'],         stack_white_all);
        end
    end
end

fprintf('\nAll processing complete.\n');
