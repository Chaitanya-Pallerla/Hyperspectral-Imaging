clc
clear
close all

%% ================= PATHS =================
base_path   = "\path";
output_root = "\path";
%% ================= OUTPUT FOLDERS =================
bw_dir        = output_root + "BW_masks\";
mean_data_dir = output_root + "Mean_Data\";
mean_plot_dir = output_root + "Mean_Plots\";
white_plot_dir= output_root + "White_Ref_Plots\";
dark_plot_dir = output_root + "Dark_Ref_Plots\";

mkdir(output_root)
mkdir(bw_dir)
mkdir(mean_data_dir)
mkdir(mean_plot_dir)
mkdir(white_plot_dir)
mkdir(dark_plot_dir)

%% ================= DATASET LIST =================
dir_info = dir(base_path);
is_valid = [dir_info.isdir] & ~ismember({dir_info.name},{'.','..'});
dataset_list = string({dir_info(is_valid).name});

fprintf("Datasets found (%d):\n",numel(dataset_list))
disp(dataset_list')

%% ================= PARAMETERS =================
min_object_area       = 10000;
thin_bar_height_ratio = 0.08;
margin_ratio          = 0.05;
epsilon               = 1e-6;

%% ================= LOOP =================
for d = 1:numel(dataset_list)

    dataset_name = dataset_list(d);
    fprintf("\nProcessing: %s\n",dataset_name)

    %% ---------- READ RGB & BW ----------
    img = imread(base_path + dataset_name + "\" + dataset_name + ".png");
    grayImage = im2gray(img);

    BW = imbinarize(grayImage);
    BW = imfill(BW,"holes");
    BW = bwareaopen(BW,min_object_area);
    BW = imclearborder(BW);

    % Remove thin horizontal bars
    cc = bwconncomp(BW);
    stats = regionprops(cc,'Area','BoundingBox');
    [H,W] = size(BW);
    BW_valid = false(size(BW));

    for k = 1:cc.NumObjects
        if stats(k).BoundingBox(4) > thin_bar_height_ratio * H
            BW_valid(cc.PixelIdxList{k}) = true;
        end
    end
    BW = BW_valid;

    % Keep largest component
    cc = bwconncomp(BW);
    stats = regionprops(cc,'Area','BoundingBox');
    [~,idx] = max([stats.Area]);

    BW_clean = false(size(BW));
    BW_clean(cc.PixelIdxList{idx}) = true;
    BW = BW_clean;

    imwrite(BW,bw_dir + dataset_name + "_BW.png");

    %% ---------- ADAPTIVE CROP ----------
    bbox = stats(idx).BoundingBox;
    x1 = max(1,floor(bbox(1)));
    y1 = max(1,floor(bbox(2)));
    bw_w = ceil(bbox(3));
    bw_h = ceil(bbox(4));

    margin_x = round(margin_ratio*bw_w);
    margin_y = round(margin_ratio*bw_h);

    x2 = min(W,x1+bw_w+2*margin_x);
    y2 = min(H,y1+bw_h+2*margin_y);

    fprintf("Crop -> x1:%d y1:%d x2:%d y2:%d | size: %dx%d\n",...
        x1,y1,x2,y2,x2-x1+1,y2-y1+1)

    %% ---------- READ ENVI ----------
    raw_hdr   = base_path + dataset_name + "\capture\" + dataset_name + ".hdr";
    raw_raw   = base_path + dataset_name + "\capture\" + dataset_name + ".raw";
    dark_hdr  = base_path + dataset_name + "\capture\DARKREF_"  + dataset_name + ".hdr";
    dark_raw  = base_path + dataset_name + "\capture\DARKREF_"  + dataset_name + ".raw";
    white_hdr = base_path + dataset_name + "\capture\WHITEREF_" + dataset_name + ".hdr";
    white_raw = base_path + dataset_name + "\capture\WHITEREF_" + dataset_name + ".raw";

    raw_info = enviinfo(raw_hdr);
    raw_data = multibandread(raw_raw,[raw_info.Height raw_info.Width raw_info.Bands],...
        raw_info.DataType,raw_info.HeaderOffset,raw_info.Interleave,raw_info.ByteOrder);

    dark_info = enviinfo(dark_hdr);
    dark_data = multibandread(dark_raw,[dark_info.Height dark_info.Width dark_info.Bands],...
        dark_info.DataType,dark_info.HeaderOffset,dark_info.Interleave,dark_info.ByteOrder);

    white_info = enviinfo(white_hdr);
    white_data = multibandread(white_raw,[white_info.Height white_info.Width white_info.Bands],...
        white_info.DataType,white_info.HeaderOffset,white_info.Interleave,white_info.ByteOrder);

    %% ---------- CROP RAW & BW ----------
    raw_crop = raw_data(y1:y2,x1:x2,:);
    BW_crop  = BW(y1:y2,x1:x2);

    %% ---------- CALIBRATION (UNCHANGED LOGIC) ----------
    dark_data_avg  = mean(dark_data,1);
    white_data_avg = mean(white_data,1);

    calibrated = (raw_crop - dark_data_avg(:,x1:x2,:)) ./ ...
                 (white_data_avg(:,x1:x2,:) - dark_data_avg(:,x1:x2,:) + epsilon);

    %% ---------- EXTRACTION (UNCHANGED LOGIC) ----------
    BW_vec = BW_crop(:);
    extracted = zeros(raw_info.Bands,sum(BW_vec));

    for b = 1:raw_info.Bands
        band_img = calibrated(:,:,b);
        band_img = band_img .* BW_crop;
        band_vec = band_img(:);
        extracted(b,:) = band_vec(BW_vec);
    end

    %% ---------- MEAN SPECTRUM ----------
    E = mean(extracted,2);
    E_smooth = sgolayfilt(E,2,41);

    %% ---------- SAVE DATA ----------
    T = table(raw_info.Wavelength(:),E(:),E_smooth(:),...
        'VariableNames',{'Wavelength_nm','Mean','Smoothed'});
    writetable(T,mean_data_dir + dataset_name + "_mean.csv");
    save(mean_data_dir + dataset_name + "_mean.mat","E","E_smooth","raw_info");

    % Save .m file
    fid = fopen(mean_data_dir + dataset_name + "_mean.m",'w');
    fprintf(fid,"%% Mean spectrum for %s\n",dataset_name);
    fprintf(fid,"wavelength = [%s];\n",num2str(raw_info.Wavelength(:)','%.6f '));
    fprintf(fid,"mean_reflectance = [%s];\n",num2str(E(:)','%.6f '));
    fprintf(fid,"mean_reflectance_smooth = [%s];\n",num2str(E_smooth(:)','%.6f '));
    fclose(fid);

    %% ---------- SAVE MEAN PLOT ----------
    fig = figure('Visible','off');
    plot(raw_info.Wavelength,E_smooth,'b','LineWidth',2)
    xlabel("Wavelength (nm)")
    ylabel("Reflectance")
    title("Mean Reflectance – "+dataset_name,'Interpreter','none')
    grid on
    saveas(fig,mean_plot_dir + dataset_name + "_mean.png")
    close(fig)

    %% ---------- SAVE WHITE & DARK REFERENCE PLOTS ----------
    white_plot = squeeze(mean(white_data_avg,2));
    dark_plot  = squeeze(mean(dark_data_avg,2));

    fig = figure('Visible','off');
    plot(raw_info.Wavelength,white_plot,'g','LineWidth',2)
    xlabel("Wavelength (nm)")
    ylabel("Intensity")
    title("White Reference – "+dataset_name,'Interpreter','none')
    grid on
    saveas(fig,white_plot_dir + dataset_name + "_white.png")
    close(fig)

    fig = figure('Visible','off');
    plot(raw_info.Wavelength,dark_plot,'r','LineWidth',2)
    xlabel("Wavelength (nm)")
    ylabel("Intensity")
    title("Dark Reference – "+dataset_name,'Interpreter','none')
    grid on
    saveas(fig,dark_plot_dir + dataset_name + "_dark.png")
    close(fig)

end
