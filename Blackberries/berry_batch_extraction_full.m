% =========================================================================
% berry_batch_extraction_full.m
%
% Description:
%   Batch per-berry spectral extraction where dark and white references
%   are loaded from the SAME Anthony folder as each sample (not a shared
%   fixed reference). Saves the most complete set of outputs per berry:
%   calibrated reflectance, raw intensity, dark reference, and white
%   reference — each as both MAT and CSV, plus PNG graphs.
%
%   Use this script when each dataset has its own dark/white references
%   captured alongside the sample.
%   Use berry_batch_extraction_optimized.m when references are shared.
%
% Output structure (inside each Anthony folder):
%   data/         → stack_<B#>.mat + 4 CSV stacks (reflectance/raw/dark/white)
%   graph/        → per-berry calibrated reflectance plots
%   raw_graphs/   → per-berry raw intensity plots
%   dark_graphs/  → per-berry dark reference plots
%   white_graphs/ → per-berry white reference plots
%   label/        → per-berry labeled mask images
%   data_raw/     → per-berry E_raw MAT + CSV
%   data_dark/    → per-berry E_dark MAT + CSV
%   data_white/   → per-berry E_white MAT + CSV
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

% Savitzky-Golay filter
window_size      = 41;   % must be odd
polynomial_order = 2;

% Small denominator guard
epsilon = 1e-6;

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
%  MAIN LOOP
% =========================================================================

for i = 1:numel(anthony_folders)

    anthony_folder = fullfile(anthony_folders(i).folder, anthony_folders(i).name);
    folder_name    = anthony_folders(i).name;

    % Extract box ID and short name
    parts     = split(folder_name, "_");
    box_id    = parts{end-2};
    idx_box   = find(contains(parts, box_id), 1, 'last');
    short_name = strjoin(parts(1:idx_box), "_");

    if ~isKey(box_labels, box_id)
        fprintf('Skipping %s (unknown box ID)\n', folder_name); continue;
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

    % ----- Load binary mask -----
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
        n=floor(num/2);
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
    wl = [];

    % ----- Load HSI cubes (refs from SAME folder) -----
    capture_folder = fullfile(anthony_folder, 'capture');

    raw_info  = enviinfo(fullfile(capture_folder, folder_name + ".hdr"));
    dark_info = enviinfo(fullfile(capture_folder, "DARKREF_"  + folder_name + ".hdr"));
    white_info= enviinfo(fullfile(capture_folder, "WHITEREF_" + folder_name + ".hdr"));

    raw_data  = multibandread(fullfile(capture_folder, folder_name + ".raw"), ...
        [raw_info.Height, raw_info.Width, raw_info.Bands], raw_info.DataType, ...
        raw_info.HeaderOffset, raw_info.Interleave, raw_info.ByteOrder);
    dark_data = multibandread(fullfile(capture_folder, "DARKREF_"  + folder_name + ".raw"), ...
        [dark_info.Height, dark_info.Width, dark_info.Bands], dark_info.DataType, ...
        dark_info.HeaderOffset, dark_info.Interleave, dark_info.ByteOrder);
    white_data= multibandread(fullfile(capture_folder, "WHITEREF_" + folder_name + ".raw"), ...
        [white_info.Height, white_info.Width, white_info.Bands], white_info.DataType, ...
        white_info.HeaderOffset, white_info.Interleave, white_info.ByteOrder);

    dark_data_avg  = mean(dark_data,  1);
    white_data_avg = mean(white_data, 1);

    calibrated_data = (raw_data - dark_data_avg) ./ (white_data_avg - dark_data_avg + epsilon);

    wl = raw_info.Wavelength(:);

    % Preallocate stacks
    stack_all       = [];
    stack_raw_all   = [];
    stack_dark_all  = [];
    stack_white_all = [];

    % ----- Per-berry loop -----
    for k = 1:min(length(labels_order), num)
        label_num = labels_order(k);
        BW = (labeled == final_indices(k));

        % Preview mask
        mask_rgb = cat(3, uint8(BW)*255, uint8(BW)*255, uint8(BW)*255);
        figure; imshow(mask_rgb); hold on;
        c = ordered_centroids(k,:);
        text(c(1),c(2),sprintf('%d',label_num),'Color','red','FontSize',16,'FontWeight','bold');
        title(sprintf('Processing Berry %d — %s', label_num, short_name));
        drawnow; pause(0.5); close;

        % Extract per-berry spectra
        extracted_data     = zeros(size(calibrated_data,3), sum(BW(:)));
        raw_extracted_data = zeros(size(raw_data,3),        sum(BW(:)));

        for b = 1:size(calibrated_data,3)
            band_img     = calibrated_data(:,:,b);
            raw_band_img = raw_data(:,:,b);
            extracted_data(b,:)     = band_img(BW);
            raw_extracted_data(b,:) = raw_band_img(BW);
        end

        E       = mean(extracted_data,     2);
        E_raw   = mean(raw_extracted_data, 2);
        E_dark  = squeeze(mean(mean(dark_data,  1), 2));
        E_white = squeeze(mean(mean(white_data, 1), 2));

        E_filtered = sgolayfilt(E, polynomial_order, window_size);

        stack_all       = [stack_all,       E_filtered];  %#ok
        stack_raw_all   = [stack_raw_all,   E_raw];
        stack_dark_all  = [stack_dark_all,  E_dark];
        stack_white_all = [stack_white_all, E_white];

        safe_name = matlab.lang.makeValidName(short_name);
        var_name  = sprintf('E_%s_Berry_%d', safe_name, label_num);

        % ----- Graphs -----
        fig=figure('Visible','off'); plot(wl,E_filtered,'b','LineWidth',2);
        title(sprintf('Reflectance - %s Berry %d',short_name,label_num));
        xlabel('Wavelength (nm)'); ylabel('Reflectance'); grid on;
        saveas(fig,fullfile(graph_folder,[var_name '_graph.png'])); close(fig);

        fig=figure('Visible','off'); plot(wl,E_raw,'k','LineWidth',1.5);
        title(sprintf('Raw - %s Berry %d',short_name,label_num));
        xlabel('Wavelength (nm)'); ylabel('Intensity'); grid on;
        saveas(fig,fullfile(raw_graph_folder,[var_name '_raw.png'])); close(fig);

        fig=figure('Visible','off'); plot(wl,E_dark,'r','LineWidth',1.5);
        title(sprintf('Dark Ref - %s Berry %d',short_name,label_num));
        xlabel('Wavelength (nm)'); ylabel('Intensity'); grid on;
        saveas(fig,fullfile(dark_graph_folder,[var_name '_dark.png'])); close(fig);

        fig=figure('Visible','off'); plot(wl,E_white,'g','LineWidth',1.5);
        title(sprintf('White Ref - %s Berry %d',short_name,label_num));
        xlabel('Wavelength (nm)'); ylabel('Intensity'); grid on;
        saveas(fig,fullfile(white_graph_folder,[var_name '_white.png'])); close(fig);

        % ----- Per-berry data (raw/dark/white) -----
        S_raw  = table(wl,E_raw,  'VariableNames',{'Wavelength_nm','E_raw'});
        S_dark = table(wl,E_dark, 'VariableNames',{'Wavelength_nm','E_dark'});
        S_white= table(wl,E_white,'VariableNames',{'Wavelength_nm','E_white'});

        save(fullfile(data_raw_folder,  [var_name '_raw.mat']),  'E_raw',  'wl','raw_info');
        save(fullfile(data_dark_folder, [var_name '_dark.mat']), 'E_dark', 'wl','dark_info');
        save(fullfile(data_white_folder,[var_name '_white.mat']),'E_white','wl','white_info');

        writetable(S_raw,  fullfile(data_raw_folder,  [var_name '_raw.csv']));
        writetable(S_dark, fullfile(data_dark_folder, [var_name '_dark.csv']));
        writetable(S_white,fullfile(data_white_folder,[var_name '_white.csv']));

        % Labeled mask image
        fig=figure('Visible','off'); imshow(mask_rgb); hold on;
        text(c(1),c(2),sprintf('%d',label_num),'Color','red','FontSize',16,'FontWeight','bold');
        frame=getframe(gca);
        imwrite(frame.cdata,fullfile(label_folder,[var_name '_label.png']));
        close(fig);
    end

    % ----- Save stacks -----
    sf = fullfile(data_folder, sprintf('stack_%s', box_id));
    save([sf '.mat'],'stack_all','stack_raw_all','stack_dark_all','stack_white_all','wl');
    try
        writematrix(stack_all,       [sf '_reflectance.csv']);
        writematrix(stack_raw_all,   [sf '_raw.csv']);
        writematrix(stack_dark_all,  [sf '_dark.csv']);
        writematrix(stack_white_all, [sf '_white.csv']);
    catch
        csvwrite([sf '_reflectance.csv'], stack_all);  %#ok
        csvwrite([sf '_raw.csv'],         stack_raw_all);
        csvwrite([sf '_dark.csv'],        stack_dark_all);
        csvwrite([sf '_white.csv'],        stack_white_all);
    end

    fprintf('Finished: %s\n', short_name);
end

fprintf('\nAll processing complete.\n');
