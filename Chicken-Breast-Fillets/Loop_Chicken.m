clc;
clear;
close all;

%% ================= USER SETTINGS =================
base_path   = "\path\";
output_root = "\path\";

window_size = 41;
poly_order  = 2;
min_object_area = 10000;
%% =================================================

%% ================= CREATE OUTPUT FOLDERS =================
mean_data_dir  = output_root + "mean_extracted_data\";
mean_plot_dir  = output_root + "mean_graph\";
white_plot_dir = output_root + "white_reference_graph\";
dark_plot_dir  = output_root + "dark_reference_graph\";
bw_dir         = output_root + "bw_mask\";

mkdir(output_root);
mkdir(mean_data_dir);
mkdir(mean_plot_dir);
mkdir(white_plot_dir);
mkdir(dark_plot_dir);
mkdir(bw_dir);

%% ================= AUTO DETECT DATASETS =================
dir_info = dir(base_path);
is_valid = [dir_info.isdir] & ~ismember({dir_info.name},{'.','..'});
dataset_list = string({dir_info(is_valid).name});

fprintf("\nDatasets found:\n");
for i = 1:length(dataset_list)
    fprintf("%d. %s\n", i, dataset_list(i));
end
fprintf("Total datasets: %d\n\n", length(dataset_list));

%% ================= PROCESS EACH DATASET =================
for d = 1:length(dataset_list)

    dataset_name = dataset_list(d);
    fprintf("Processing: %s\n", dataset_name);

    dataset_path = base_path + dataset_name + "\";

    %% ================= READ RGB IMAGE =================
    img = imread(dataset_path + dataset_name + ".png");

    grayImage = im2gray(img);
    BW = imbinarize(grayImage);
    BW = imfill(BW,"holes");
    BW = bwareaopen(BW, min_object_area);

    %% ================= SAVE BW IMAGE =================
    imwrite(BW, bw_dir + dataset_name + "_BW.png");

    %% ================= READ ENVI FILES =================
    raw_hdr   = dataset_path + "capture\" + dataset_name + ".hdr";
    raw_raw   = dataset_path + "capture\" + dataset_name + ".raw";

    dark_hdr  = dataset_path + "capture\DARKREF_" + dataset_name + ".hdr";
    dark_raw  = dataset_path + "capture\DARKREF_" + dataset_name + ".raw";

    white_hdr = dataset_path + "capture\WHITEREF_" + dataset_name + ".hdr";
    white_raw = dataset_path + "capture\WHITEREF_" + dataset_name + ".raw";

    raw_info   = enviinfo(raw_hdr);
    dark_info  = enviinfo(dark_hdr);
    white_info = enviinfo(white_hdr);

    raw_data = multibandread(raw_raw, ...
        [raw_info.Height raw_info.Width raw_info.Bands], ...
        raw_info.DataType, raw_info.HeaderOffset, ...
        raw_info.Interleave, raw_info.ByteOrder);

    dark_data = multibandread(dark_raw, ...
        [dark_info.Height dark_info.Width dark_info.Bands], ...
        dark_info.DataType, dark_info.HeaderOffset, ...
        dark_info.Interleave, dark_info.ByteOrder);

    white_data = multibandread(white_raw, ...
        [white_info.Height white_info.Width white_info.Bands], ...
        white_info.DataType, white_info.HeaderOffset, ...
        white_info.Interleave, white_info.ByteOrder);

    %% ================= MEAN DARK & WHITE =================
    dark_avg  = squeeze(mean(mean(dark_data,1),2));
    white_avg = squeeze(mean(mean(white_data,1),2));

    %% ================= CALIBRATION =================
    dark_avg_img  = mean(dark_data,1);
    white_avg_img = mean(white_data,1);

    calibrated_data = (raw_data - dark_avg_img) ./ (white_avg_img - dark_avg_img);
    calibrated_data = min(max(calibrated_data,0),1);

    %% ================= SPECTRAL EXTRACTION =================
    BW_idx = find(BW(:));
    extracted_data = zeros(raw_info.Bands, numel(BW_idx));

    for b = 1:raw_info.Bands
        band = calibrated_data(:,:,b);
        extracted_data(b,:) = band(BW_idx);
    end

    %% ================= MEAN SPECTRUM =================
    E = mean(extracted_data,2);
    E_smooth = sgolayfilt(E, poly_order, window_size);

    %% ================= EXPORT TO WORKSPACE =================
    safe_name = matlab.lang.makeValidName(dataset_name);
    assignin('base',"E_"+safe_name,E);
    assignin('base',"E_smooth_"+safe_name,E_smooth);
    assignin('base',"Wavelength_"+safe_name,raw_info.Wavelength);

    %% ================= SAVE MEAN DATA =================
    save(mean_data_dir + dataset_name + "_mean_spectrum.mat", ...
        "E","E_smooth","raw_info");

    T = table(raw_info.Wavelength(:), E(:), E_smooth(:), ...
        'VariableNames',{'Wavelength_nm','MeanReflectance','SmoothedReflectance'});

    writetable(T, mean_data_dir + dataset_name + "_mean_spectrum.csv");

    %% ================= MEAN REFLECTANCE GRAPH =================
    fig = figure('Visible','off');
    plot(raw_info.Wavelength,E_smooth,'b','LineWidth',2);
    xlabel("Wavelength (nm)");
    ylabel("Reflectance");
    title("Mean Reflectance - "+dataset_name,'Interpreter','none');
    grid on;
    saveas(fig, mean_plot_dir + dataset_name + "_mean.png");
    close(fig);

    %% ================= WHITE REFERENCE GRAPH =================
    fig = figure('Visible','off');
    plot(raw_info.Wavelength,white_avg,'g','LineWidth',2);
    xlabel("Wavelength (nm)");
    ylabel("Intensity");
    title("White Reference - "+dataset_name,'Interpreter','none');
    grid on;
    saveas(fig, white_plot_dir + dataset_name + "_white.png");
    close(fig);

    %% ================= DARK REFERENCE GRAPH =================
    fig = figure('Visible','off');
    plot(raw_info.Wavelength,dark_avg,'r','LineWidth',2);
    xlabel("Wavelength (nm)");
    ylabel("Intensity");
    title("Dark Reference - "+dataset_name,'Interpreter','none');
    grid on;
    saveas(fig, dark_plot_dir + dataset_name + "_dark.png");
    close(fig);

end
