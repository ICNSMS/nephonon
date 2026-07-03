function sqw_crystal
%% clean everythings
clear; clc; close all;

%% read data
data = importdata('sqw_crystal.dat',' ',1);

x = data.data(:, 1);
y = data.data(:, 2);
z = data.data(:, 3);

%% process x and y
unique_x = unique(x);
unique_y = unique(y);

%% plot
if length(unique_x) * length(unique_y) == length(z)
    % mesh
    fprintf('\nData suitable for grid processing...\n');
    [X, Y] = meshgrid(unique_x, unique_y);
    Z = reshape(z, length(unique_y), length(unique_x));
    pcolor(X, Y, Z);    
else
    fprintf('\nData not suitable for grid processing，Requires interpolation...\n');   

    xi = linspace(min(x), max(x), 100);
    yi = linspace(min(y), max(y), 100);
    [Xi, Yi] = meshgrid(xi, yi);
    
    % method: 'linear', 'cubic', 'v4'
    Zi = griddata(x, y, z, Xi, Yi, 'linear');
    pcolor(Xi, Yi, Zi);
end

shading interp;
colormap('jet');
caxis([0,0.5]);

xlabel(['[H,1,1](r.l.u.)'],'FontName','times new roman','FontWeight','Bold', 'FontSize', 8);
ylabel('E (meV)','FontName','times new roman','FontWeight','Bold', 'FontSize', 8);
set(gca,'FontName','times new roman','FontWeight','Bold','FontSize',8,'LineWidth',0.2);
box off;axis tight;
xlim([0, max(x)]);

hold on;
x = [1.5564571246, 3.1129142493, 4.63824];     
for i = 1:length(x)
    plot([x(i), x(i)], [0, 40], 'Color', [1, 1, 1, 0.2], 'LineWidth', 1);
end

xticks([0.0,1.5564571246, 3.1129142493, 4.63824, 6.194699350]);
xticklabels({'0','1', '2', '3',  '4'});

set(gcf,'unit','centimeters','Position',[5, 5, 8.0, 6.0]);
print(gcf, 'psf.png','-r600','-dpng');
end