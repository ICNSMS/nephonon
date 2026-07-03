function band_plot
%% clean everythings
clear; clc; close all;

%% Read data
data = importdata('phononband.dat', ' ', 1);  % 自动跳过第一行（标题行），空格分隔

x = data.data(:, 1);   % 第一列：qpath
y = data.data(:, 2);   % 第二列：Energy (meV)

%% Plot
figure;
plot(x, y, 'o', 'MarkerSize', 2.0);
hold on;

xlim([0, max(x)]);
ylim([0, max(y)]);

line([x(200), x(200)], [0,max(y)], 'LineStyle', '-', 'LineWidth', 2.0);
line([x(300), x(300)], [0,max(y)], 'LineStyle', '-', 'LineWidth', 2.0);
line([x(400), x(400)], [0,max(y)], 'LineStyle', '-', 'LineWidth', 2.0);

set(gca, 'XTick', [0.0, x(200), x(300), x(400), max(x)]);
set(gca, 'XTickLabel', {'\Gamma', 'X', 'M', '\Gamma', 'Y'});

ylabel('Energy (meV)');
title('Band Structure of \alpha-phosphorene');
grid on;
grid minor;  % 可选，显示细网格

end