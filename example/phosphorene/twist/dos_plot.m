function band_plot
%% clean everythings
clear; clc; close all;

%% Read data
data = importdata('phonondos.dat', ' ', 1);  % 自动跳过第一行（标题行），空格分隔

x = data.data(:, 1);   % 第一列：qpath
%% Plot
figure;
hold on;

for i = 2:11
y = data.data(:, i);   % 第二列：Energy (meV)
plot(x, y, '-', 'MarkerSize', 2.0);
end

xlim([0, max(x)]);
ylim([0, max(y)*2]);

xlabel('Energy (meV)');
title('DOS of twist phosphorene');
grid on;box on;
grid minor;  % 可选，显示细网格
end