% PROBLEM = @DTLZ1;
% Ms = 2:2:10;
% Ns = 5:5:50;
% 
% for M = Ms
%     for N = Ns
%         platemo('problem', PROBLEM, 'N', N, 'M', M, ...
%             'maxFE', 10000, 'algorithm', {@SMS_WFG});
%     end
% end
% 
% % platemo('problem', PROBLEM, 'N', , ...
% %     'maxFE', 10000, 'algorithm', {@SMSEMOA_});
load('timing_log.mat');  % loads all_results

n_vals = all_results(:,1);
m_vals = all_results(:,2);
t_vals = all_results(:,3);

% Plot t vs n (log-scale on y-axis)
figure;
semilogy(n_vals, t_vals, 'o-');
xlabel('n');
ylabel('Time (s) [log scale]');
title('Execution Time vs n');
grid on;

% Plot t vs m (log-scale on y-axis)
figure;
semilogy(m_vals, t_vals, 's-');
xlabel('m');
ylabel('Time (s) [log scale]');
title('Execution Time vs m');
grid on;
