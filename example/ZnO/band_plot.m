function band_plot
%% clean everythings
clear; clc; close all;

%% Read data
data = importdata('phononband.dat', ' ', 1);  % 自动跳过第一行（标题行），空格分隔

x = data.data(:, 1);   % 第一列：qpath
y = data.data(:, 2);   % 第二列：Energy (meV)

%% Plot
figure;
plot(x, y, 'ro', 'MarkerSize', 2.0);
hold on;

%%
xlim([0, max(x)]);
ylim([0, max(y)]);

line([x(50),   x(50)], [0,max(y)], 'LineStyle', '-', 'LineWidth', 2.0, 'Color', 'k');
line([x(100), x(100)], [0,max(y)], 'LineStyle', '-', 'LineWidth', 2.0, 'Color', 'k');
line([x(150), x(150)], [0,max(y)], 'LineStyle', '-', 'LineWidth', 2.0, 'Color', 'k');
line([x(200), x(200)], [0,max(y)], 'LineStyle', '-', 'LineWidth', 2.0, 'Color', 'k');
line([x(250), x(250)], [0,max(y)], 'LineStyle', '-', 'LineWidth', 2.0, 'Color', 'k');
line([x(300), x(300)], [0,max(y)], 'LineStyle', '-', 'LineWidth', 2.0, 'Color', 'k');

set(gca, 'XTick', [0.0, x(50), x(100), x(150), x(200), x(250), x(300), max(x)]);
set(gca, 'XTickLabel', {'\Gamma', 'M', 'K', '\Gamma', 'A', 'L', 'H', 'A'});

ylabel('Energy (meV)');
title('Phonon Band Structure of Wurtzite ZnO with the Non-analytic Correction');
grid on; grid minor;
end