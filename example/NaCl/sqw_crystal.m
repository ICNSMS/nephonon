function cphonon_band
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
caxis([0,10]);
set(gca, 'XTickLabel', {});

title('Phonon Data', 'FontName','times new roman','FontSize', 12, 'FontWeight', 'bold');
xlabel(['Q (rlu)'],'FontName','times new roman','FontWeight','Bold', 'FontSize', 12);
ylabel('Energy (meV)','FontName','times new roman','FontWeight','Bold', 'FontSize', 12);
set(gca,'FontName','times new roman','FontWeight','Bold','FontSize',12,'LineWidth',0.2);
box off;hold off;axis tight;
xlim([0, max(x)]);

set(gcf,'unit','centimeters','Position',[5, 5, 15.0, 15.0]);
print(gcf, 'psf.png','-r600','-dpng');
end