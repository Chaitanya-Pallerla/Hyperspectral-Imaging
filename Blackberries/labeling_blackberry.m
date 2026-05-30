% =========================================================================
% labeling_blackberry.m
%
% Description:
%   Assigns sequential berry ID numbers (1–120) to individual berry blobs
%   in binary mask images. Blobs are sorted spatially right→middle→left
%   and top→bottom within each column, matching the physical box layout
%   used during data collection (B1–B7, 18 berries per box except B7=12).
%
%   Saved labeled images show each berry's ID number overlaid in red,
%   which are used as ground truth for spectral extraction.
%
% Input:
%   - Binary mask images named identically to their Anthony_ folders
%     (e.g., Anthony_Caddo_2025_06_24_0741_06_B1_2025-06-24_18-00-28.png)
%
% Output:
%   - <folder_name>_labeled.png : RGB image with red berry ID numbers
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

% Root folder containing all Anthony_* subfolders
base_folder = 'O:\Blackberry_data';   % <-- CHANGE THIS

% =========================================================================
%  BOX LABEL MAPPING — matches physical box layout during collection
%  B1–B6 have 18 berries (3 columns × 6 rows), B7 has 12 (2 columns × 6)
% =========================================================================

box_labels = containers.Map;
box_labels('B1') = [1:6,   7:12,  13:18];
box_labels('B2') = [19:24, 25:30, 31:36];
box_labels('B3') = [37:42, 43:48, 49:54];
box_labels('B4') = [55:60, 61:66, 67:72];
box_labels('B5') = [73:78, 79:84, 85:90];
box_labels('B6') = [91:96, 97:102, 103:108];
box_labels('B7') = [109:114, 115:120];   % 2 columns only

% =========================================================================
%  AUTO-DETECT ALL ANTHONY FOLDERS AND LABEL BERRIES
% =========================================================================

anthony_folders = dir(fullfile(base_folder, '**', 'Anthony_*'));
anthony_folders = anthony_folders([anthony_folders.isdir]);
fprintf('Found %d Anthony folders.\n\n', length(anthony_folders));

for i = 1:length(anthony_folders)

    anthony_folder = fullfile(anthony_folders(i).folder, anthony_folders(i).name);
    folder_name    = anthony_folders(i).name;

    % Extract box ID (e.g., B1) from folder name
    parts  = split(folder_name, "_");
    box_id = parts{end-2};

    if ~isKey(box_labels, box_id)
        fprintf('Skipping %s (unknown box ID: %s)\n', folder_name, box_id);
        continue;
    end

    % Find the binary mask image (same name as folder)
    img_files = dir(fullfile(anthony_folder, [folder_name '.*']));
    if isempty(img_files)
        fprintf('No mask image found in: %s\n', folder_name);
        continue;
    end

    anthony_img_path = fullfile(img_files(1).folder, img_files(1).name);
    fprintf('Labeling: %s\n', folder_name);

    % Load binary mask
    bw = imread(anthony_img_path);
    if size(bw,3) > 1, bw = rgb2gray(bw); end
    if ~islogical(bw),  bw = bw > 0;       end

    % Label connected components (individual berries)
    [labeled, num] = bwlabel(bw);
    stats          = regionprops(labeled, 'Centroid');
    centroids      = cat(1, stats.Centroid);

    % Sort blobs left→right by X centroid
    [~, sort_x]       = sort(centroids(:,1));
    sorted_centroids   = centroids(sort_x,:);

    % Divide into columns and sort each column top→bottom
    % Final order: right → middle → left (matches box orientation)
    if strcmp(box_id, 'B7')
        % 2-column box
        n = floor(num/2);
        idx_L = sort_x(1:n);       idx_R = sort_x(n+1:end);
        cL    = sorted_centroids(1:n,:);   cR = sorted_centroids(n+1:end,:);
        [~,oL] = sort(cL(:,2)); [~,oR] = sort(cR(:,2));
        final_indices     = [idx_R(oR);  idx_L(oL)];
        ordered_centroids = [cR(oR,:);   cL(oL,:)];
    else
        % 3-column box
        n = floor(num/3);
        idx_L = sort_x(1:n);      idx_M = sort_x(n+1:2*n);     idx_R = sort_x(2*n+1:end);
        cL    = sorted_centroids(1:n,:);
        cM    = sorted_centroids(n+1:2*n,:);
        cR    = sorted_centroids(2*n+1:end,:);
        [~,oL]=sort(cL(:,2)); [~,oM]=sort(cM(:,2)); [~,oR]=sort(cR(:,2));
        final_indices     = [idx_R(oR);  idx_M(oM);  idx_L(oL)];
        ordered_centroids = [cR(oR,:);   cM(oM,:);   cL(oL,:)];
    end

    labels_order = box_labels(box_id);

    % Build RGB image and draw labels
    rgb_img = cat(3, uint8(bw)*255, uint8(bw)*255, uint8(bw)*255);

    fig = figure('Visible','off');
    imshow(rgb_img); hold on;

    for k = 1:min(length(labels_order), num)
        c = ordered_centroids(k,:);
        text(c(1), c(2), sprintf('%d', labels_order(k)), ...
            'Color','red','FontSize',16,'FontWeight','bold');
    end
    hold off;

    % Save labeled image
    save_path = fullfile(anthony_folder, [folder_name '_labeled.png']);
    frame = getframe(gca);
    imwrite(frame.cdata, save_path);
    close(fig);
end

fprintf('\nLabeling complete.\n');
