function PreprocessProductionImage(column,height_ratio,scale)
    %% column: 1 single column
    %% height_ratio: 1:height_ratio (width:height)
    %% scale (双栏图)；单栏改为 8.8 cm, 双栏18.1cm
    %% Before drawing
     % The scale is to make the figure more clear
    w = 8.8*scale*column; % cm (双栏图)；单栏改为 8.8 cm, 双栏18.1cm
    h = w*height_ratio;   % cm
    set(groot, 'DefaultLineLineWidth', 1.2);                 % 线宽
    set(groot, 'DefaultAxesLineWidth',1.5);            % 坐标轴线宽
    fig = figure('Units','centimeters','Position',[0,0,w,h]);hold on;
    set(fig,'PaperUnits','centimeters','PaperSize',[w h]);
    set(fig,'PaperPosition',[0 0 w h]);
    set(fig,'PaperPositionMode','auto');
    set(fig,'Renderer','painters');   % 关键：确保矢量输出
    % set(gca,'FontName','Times New Roman', "FontSize",7.5*scale); hold on;
    % set(groot, 'DefaultAxesFontName', 'Times New Roman', 'DefaultAxesFontSize', 6.5*scale);
    set(gca,'FontName','Times New Roman', "FontSize",5*scale); hold on;
    set(groot, 'DefaultAxesFontName', 'Times New Roman', 'DefaultAxesFontSize', 4*scale);
end