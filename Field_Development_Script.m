clearvars; close all; clc; warning('off');
%% Upload Pre Input Data
addpath(genpath('C:\Users\Demon\Desktop\AMPL\'));
foler_path='C:\Users\Demon\Desktop\AMPL\AMPL_Install';
Pre_Input_Data_Excel='FDP.xlsx';
Pre_Input_Data_File=fullfile(foler_path,Pre_Input_Data_Excel);

[~,Sheet_Names] = xlsfinfo(Pre_Input_Data_File ); Param=[];
Pre_Input_Data.Param_Table = readtable(Pre_Input_Data_File,'Sheet','Param_Table');

for i = 1:height(Pre_Input_Data.Param_Table)
    Param.(Pre_Input_Data.Param_Table.Abbrev{i}) = Pre_Input_Data.Param_Table.Param(i);
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Expected Value Solution without Long-Term Agreement Discount
FDP_Input_Data(1,Param.Initial_Price, Param.ReversionLevel);

[Prices_Table NGP] = FDP_Input_Data(Param.Price_Paths,...
    Param.Initial_Price, Param.ReversionLevel);

%% Write Parallelized Code for Optimizations

n=1;
for mid = [1 37]
    for up = 1:6:43
        tic;
        parfor masterIDX = 1:Param.Price_Paths
            
            setUp_ampl(); ampl_SS5=AMPL;
            ampl_SS5.read(['FDP_V8.mod']);
            
            ampl_SS5.readData([strcat('Input_Data_',num2str(1),'_',...
            num2str(Param.Initial_Price),'_', num2str(Param.ReversionLevel),'.dat')]);
            
            ampl_SS5.eval('option presolve_eps 1e-3;');
            ampl_SS5.eval('option solver gurobi;');
            %    ampl_SS5.setOption('gurobi_options','outlev=1 multiobj=1 mipgap=1.0e-4');
            ampl_SS5.setOption('gurobi_options','outlev=1 mipgap=1.0e-2');
            
            %ampl_SS5.eval(strcat('let WD_Configuration_Selection :=',num2str(1+mod(masterIDX*6,36)),';'));
            %ampl_SS5.eval(strcat('let GT_Configuration_Selection :=',num2str(1+36*floor(masterIDX/8)),';'));
            
            ampl_SS5.eval(strcat('let WD_Configuration_Selection :=',num2str(min(up,37)),';'));
            ampl_SS5.eval(strcat('let GT_Configuration_Selection :=',num2str(mid),';'));
            
            ampl_SS5.eval(strcat('let SR_UP := ',num2str(Param.SR_Up),';'));
            ampl_SS5.eval(strcat('let SR_MID := ',num2str(Param.SR_Mid),';'));
            
            ind =  Prices_Table.Price_Scenario == masterIDX; Temp_PT = Prices_Table(ind,:);
            Temp_PT.Price_Scenario(:) = 1; NGP_Dataframe = table2dataframe(Temp_PT, 2);
            ampl_SS5.setData(NGP_Dataframe)
            
            for k = 0:Param.Optimization_Horizon - Param.Min_Horizon
                ampl_SS5.eval(strcat('let Final_Month :=',num2str(k+Param.Min_Horizon),';'));
                ampl_SS5.eval(strcat('let Present_Month :=',num2str(k),';'));
                
                if up~=43 || k == 0
                    %s ampl_SS5.solve();
                    solve_ampl(ampl_SS5);
                end
                
                if k==0
                    NPV_temp=dataframe2table(ampl_SS5,'NPV_CM',{'Price_Scenario'});
                    NPR_temp=dataframe2table(ampl_SS5,'NPR',{'Price_Scenario'});
                    NPC_temp=dataframe2table(ampl_SS5,'NPC',{'Price_Scenario'});
                    
                    On_Demand_WD_temp=dataframe2table(ampl_SS5,'On_Demand_WD',{'Horizon','Price_Scenario'});
                    On_Demand_WD_p_temp=dataframe2table(ampl_SS5,'On_Demand_WD_p',{'Horizon','Price_Scenario'});
                    
                    Flexible_MS_v_temp=dataframe2table(ampl_SS5,'Flexible_MS_v',{'Horizon','Price_Scenario'});
                    Flexible_MS_p_temp=dataframe2table(ampl_SS5,'Flexible_MS_p',{'Horizon','Price_Scenario'});
                    
                    Long_Term_WD_Usage_temp=dataframe2table(ampl_SS5,'Long_Term_WD_Usage',{'Horizon','Price_Scenario'});
                    Long_Term_WD_Usage_p_temp=dataframe2table(ampl_SS5,'Long_Term_WD_Usage_p',{'Horizon','Price_Scenario'});
                    NG_Realized_temp=dataframe2table(ampl_SS5,'NG_Realized',{'Horizon','Price_Scenario'});
                    NG_Future_temp=dataframe2table(ampl_SS5,'NG_Future',{'Horizon','Price_Scenario'});
                    GP_v_temp=dataframe2table(ampl_SS5,'GP_v',{'Horizon','Price_Scenario'});
                    x_temp=dataframe2table(ampl_SS5,'x',{'Horizon','Price_Scenario'});
                    
                    NPV_temp.Price_Scenario(:) = masterIDX;
                    NPC_temp.Price_Scenario(:) = masterIDX;
                    
                    On_Demand_WD_temp.Price_Scenario(:) = masterIDX;
                    On_Demand_WD_p_temp.Price_Scenario(:) = masterIDX;
                    
                    Flexible_MS_v_temp.Price_Scenario(:) = masterIDX;
                    Flexible_MS_p_temp.Price_Scenario(:) = masterIDX;
                    
                    Long_Term_WD_Usage_temp.Price_Scenario(:) = masterIDX;
                    Long_Term_WD_Usage_p_temp.Price_Scenario(:) = masterIDX;
                    NG_Realized_temp.Price_Scenario(:) = masterIDX;
                    NG_Future_temp.Price_Scenario(:) = masterIDX;
                    GP_v_temp.Price_Scenario(:) = masterIDX;
                    x_temp.Price_Scenario(:) = masterIDX;
                    
                    NPV_temp.month(:) = k*ones(size(NPV_temp.Price_Scenario));
                    NPR_temp.month(:) = k*ones(size(NPR_temp.Price_Scenario));
                    NPC_temp.month(:) = k*ones(size(NPC_temp.Price_Scenario));
                    
                    On_Demand_WD_temp.month(:) = k*ones(size(On_Demand_WD_temp.Price_Scenario));
                    On_Demand_WD_p_temp.month(:) = k*ones(size(On_Demand_WD_p_temp.Price_Scenario));
                    
                    Flexible_MS_v_temp.month(:) = k*ones(size(Flexible_MS_v_temp.Price_Scenario));
                    Flexible_MS_p_temp.month(:) = k*ones(size(Flexible_MS_p_temp.Price_Scenario));
                    
                    Long_Term_WD_Usage_temp.month(:) = k*ones(size(Long_Term_WD_Usage_temp.Price_Scenario));
                    Long_Term_WD_Usage_p_temp.month(:) = k*ones(size(Long_Term_WD_Usage_p_temp.Price_Scenario));
                    NG_Realized_temp.month(:) = k*ones(size(NG_Realized_temp.Price_Scenario));
                    NG_Future_temp.month(:) = k*ones(size(NG_Future_temp.Price_Scenario));
                    GP_v_temp.month(:) = k*ones(size(GP_v_temp.Price_Scenario));
                    x_temp.month(:) = k*ones(size(x_temp.Price_Scenario));
                    
                    NPR = NPR_temp;
                    NPV = NPV_temp;
                    NPC = NPC_temp;
                    
                    On_Demand_WD = On_Demand_WD_temp;
                    On_Demand_WD_p = On_Demand_WD_p_temp;
                    
                    Flexible_MS_v = Flexible_MS_v_temp;
                    Flexible_MS_p = Flexible_MS_p_temp;
                    
                    Long_Term_WD_Usage = Long_Term_WD_Usage_temp;
                    Long_Term_WD_Usage_p = Long_Term_WD_Usage_p_temp;
                    NG_Realized = NG_Realized_temp;
                    NG_Future = NG_Future_temp;
                    GP_v = GP_v_temp;
                    x = x_temp;
                    
                elseif mod(k,12)==0
                    
                    NPV_temp=dataframe2table(ampl_SS5,'NPV_CM',{'Price_Scenario'});
                    NPR_temp=dataframe2table(ampl_SS5,'NPR',{'Price_Scenario'});
                    NPC_temp=dataframe2table(ampl_SS5,'NPC',{'Price_Scenario'});
                    On_Demand_WD_temp=dataframe2table(ampl_SS5,'On_Demand_WD',{'Horizon','Price_Scenario'});
                    On_Demand_WD_p_temp=dataframe2table(ampl_SS5,'On_Demand_WD_p',{'Horizon','Price_Scenario'});
                    
                    Flexible_MS_v_temp=dataframe2table(ampl_SS5,'Flexible_MS_v',{'Horizon','Price_Scenario'});
                    Flexible_MS_p_temp=dataframe2table(ampl_SS5,'Flexible_MS_p',{'Horizon','Price_Scenario'});
                    
                    Long_Term_WD_Usage_temp=dataframe2table(ampl_SS5,'Long_Term_WD_Usage',{'Horizon','Price_Scenario'});
                    Long_Term_WD_Usage_p_temp=dataframe2table(ampl_SS5,'Long_Term_WD_Usage_p',{'Horizon','Price_Scenario'});
                    NG_Realized_temp=dataframe2table(ampl_SS5,'NG_Realized',{'Horizon','Price_Scenario'});
                    NG_Future_temp=dataframe2table(ampl_SS5,'NG_Future',{'Horizon','Price_Scenario'});
                    GP_v_temp=dataframe2table(ampl_SS5,'GP_v',{'Horizon','Price_Scenario'});
                    x_temp=dataframe2table(ampl_SS5,'x',{'Horizon','Price_Scenario'});
                    
                    
                    NPV_temp=dataframe2table(ampl_SS5,'NPV_CM',{'Price_Scenario'});
                    NPV_temp=dataframe2table(ampl_SS5,'NPV_CM',{'Price_Scenario'});
                    
                    NPV_temp.month(:) = k*ones(size(NPV_temp.Price_Scenario));
                    NPV_temp.month(:) = k*ones(size(NPV_temp.Price_Scenario));
                    
                    NPR_temp.month(:) = k*ones(size(NPR_temp.Price_Scenario));
                    NPC_temp.month(:) = k*ones(size(NPC_temp.Price_Scenario));
                    On_Demand_WD_temp.month(:) = k*ones(size(On_Demand_WD_temp.Price_Scenario));
                    On_Demand_WD_p_temp.month(:) = k*ones(size(On_Demand_WD_p_temp.Price_Scenario));
                    
                    Flexible_MS_v_temp.month(:) = k*ones(size(Flexible_MS_v_temp.Price_Scenario));
                    Flexible_MS_p_temp.month(:) = k*ones(size(Flexible_MS_p_temp.Price_Scenario));
                    
                    Long_Term_WD_Usage_temp.month(:) = k*ones(size(Long_Term_WD_Usage_temp.Price_Scenario));
                    Long_Term_WD_Usage_p_temp.month(:) = k*ones(size(Long_Term_WD_Usage_p_temp.Price_Scenario));
                    NG_Realized_temp.month(:) = k*ones(size(NG_Realized_temp.Price_Scenario));
                    NG_Future_temp.month(:) = k*ones(size(NG_Future_temp.Price_Scenario));
                    GP_v_temp.month(:) = k*ones(size(GP_v_temp.Price_Scenario));
                    
                    x_temp.month(:) = k*ones(size(x_temp.Price_Scenario));
                    
                    NPV_temp.Price_Scenario(:) = masterIDX;
                    NPC_temp.Price_Scenario(:) = masterIDX;
                    On_Demand_WD_temp.Price_Scenario(:) = masterIDX;
                    On_Demand_WD_p_temp.Price_Scenario(:) = masterIDX;
                    
                    Flexible_MS_v_temp.Price_Scenario(:) = masterIDX;
                    Flexible_MS_p_temp.Price_Scenario(:) = masterIDX;
                    
                    Long_Term_WD_Usage_temp.Price_Scenario(:) = masterIDX;
                    Long_Term_WD_Usage_p_temp.Price_Scenario(:) = masterIDX;
                    NG_Realized_temp.Price_Scenario(:) = masterIDX;
                    NG_Future_temp.Price_Scenario(:) = masterIDX;
                    GP_v_temp.Price_Scenario(:) = masterIDX;
                    x_temp.Price_Scenario(:) = masterIDX;
                    
                    NPV=[NPV; NPV_temp];
                    NPR=[NPR; NPR_temp];
                    NPC=[NPC; NPC_temp];
                    On_Demand_WD = [On_Demand_WD; On_Demand_WD_temp];
                    On_Demand_WD_p = [On_Demand_WD_p; On_Demand_WD_p_temp];
                    Long_Term_WD_Usage = [Long_Term_WD_Usage; Long_Term_WD_Usage_temp];
                    Long_Term_WD_Usage_p = [Long_Term_WD_Usage_p; Long_Term_WD_Usage_p_temp];
                    
                    Flexible_MS_v = [Flexible_MS_v; Flexible_MS_v_temp];
                    Flexible_MS_p = [Flexible_MS_p; Flexible_MS_p_temp];
                    
                    NG_Realized = [NG_Realized; NG_Realized_temp];
                    NG_Future = [NG_Future; NG_Future_temp];
                    GP_v = [GP_v; GP_v_temp];
                    x = [x; x_temp];
                else
                    
                end
                
                %if k<Param.Optimization_Horizon - Param.Min_Horizon
                ampl_SS5.eval(strcat('let {a in Tier, i in ', {' '}, num2str(k) , '..' , num2str(k), ', ps in Price_Scenario} x_p[a,i,ps] := x_v[a,i,ps];'));
                ampl_SS5.eval(strcat('let {i in ',  {' '}, num2str(k) , '..' , num2str(k),  ', ps in Price_Scenario}', 'On_Demand_WD_p[i,ps] := On_Demand_WD[i,ps];'));
                ampl_SS5.eval(strcat('let {i in ',  {' '}, num2str(k) , '..' , num2str(k),  ', ps in Price_Scenario}', 'Flexible_MS_p[i,ps] := Flexible_MS_v[i,ps];'));
                ampl_SS5.eval(strcat('let {i in ',  {' '}, num2str(k) , '..' , num2str(k),  ', ps in Price_Scenario}', 'Long_Term_WD_Usage_p[i,ps] := Long_Term_WD_Usage[i,ps];'));
                ampl_SS5.eval(strcat('let {i in ',  {' '}, num2str(k) , '..' , num2str(k),  ', ps in Price_Scenario} Rig_Mobilization_p[i,ps] := Rig_Mobilization[i,ps];'));
                %end
                
            end
            %formatSpec = 'Price Scenario = %i\n';
            %fprintf(formatSpec,masterIDX+1);
            NPV_inter{masterIDX,n}=NPV;
            NPR_inter{masterIDX,n}=NPR;
            NPC_inter{masterIDX,n}=NPC;
            
            On_Demand_WD_inter{masterIDX,n}=On_Demand_WD;
            On_Demand_WD_p_inter{masterIDX,n}=On_Demand_WD_p;
            
            Flexible_MS_v_inter{masterIDX,n} = Flexible_MS_v;
            Flexible_MS_p_inter{masterIDX,n} = Flexible_MS_p;
            
            Long_Term_WD_Usage_inter{masterIDX,n}=Long_Term_WD_Usage;
            Long_Term_WD_Usage_p_inter{masterIDX,n}=Long_Term_WD_Usage_p;
            NG_Realized_inter{masterIDX,n}=NG_Realized;
            NG_Future_inter{masterIDX,n}=NG_Future;
            GP_inter{masterIDX,n}=GP_v;
            x_inter{masterIDX,n}=x;
            
            %r(masterIDX+1)=toc;
            formatSpec = 'Configuration = %i, Price Scenario = %i\n';
            fprintf(formatSpec, n, masterIDX+1); ampl_SS5.close();
        end
        runtime(n) = toc;
        n=n+1;
    end
end

for  n = 1:length(runtime)
    NPV_full{n} = vertcat(NPV_inter{:,n});
    NPR_full{n} = vertcat(NPR_inter{:,n});
    
    NPC_full{n} = vertcat(NPC_inter{:,n});
    
    On_Demand_WD_full{n} = vertcat(On_Demand_WD_inter{:,n});
    On_Demand_WD_p_full{n} = vertcat(On_Demand_WD_p_inter{:,n});
    
    Long_Term_WD_Usage_full{n} = vertcat(Long_Term_WD_Usage_inter{:,n});
    Long_Term_WD_Usage_p_full{n} = vertcat(Long_Term_WD_Usage_p_inter{:,n});
    
    NG_Realized_full{n} = vertcat(NG_Realized_inter{:,n});
    NG_Future_full{n} = vertcat(NG_Future_inter{:,n});
    
    Flexible_MS_v_full{n} = vertcat(Flexible_MS_v_inter{:,n});
    Flexible_MS_p_full{n} = vertcat(Flexible_MS_p_inter{:,n});
    
    GP_full{n} = vertcat(GP_inter{:,n});
    x_full{n} = vertcat(x_inter{:,n});
end

save('myFile3.mat', '-v7.3')
%%
LTDCa = Long_Term_WD_Usage_p_full{end-1};LTDCb = Long_Term_WD_Usage_full{end-1};
LTDCa.Properties.VariableNames = {'Horizon' 'Price_Scenario' 'x' 'month'};
LTDCb.Properties.VariableNames = {'Horizon' 'Price_Scenario' 'x' 'month'};
LTDC = [LTDCa;LTDCb];

xx=pivottable(table2cell(LTDC),[2 4],[1],[3],@sum);
%%
for i = 1:length(runtime)
    NPV_Inter=pivottable(table2cell(NPV_full{i}) , 1, 3, 2, @sum);
    NPR_Inter=pivottable(table2cell(NPR_full{i}) , 1, 3, 2, @sum);
    NPC_Inter=pivottable(table2cell(NPC_full{i}) , 1, 3, 2, @sum);
    
    NPV_Final{i} = cell2mat(NPV_Inter(2:end,2:end));
    NPR_Final{i} = cell2mat(NPR_Inter(2:end,2:end));
    NPC_Final{i} = cell2mat(NPC_Inter(2:end,2:end));
    
    NPV_Mean{i} = mean(NPV_Final{i});
    NPR_Mean{i} = mean(NPR_Final{i});
    NPC_Mean{i} = mean(NPC_Final{i});
    
    NPV_End(i) = NPV_Mean{i}(end);
    NPR_End(i) = NPR_Mean{i}(end);
    NPC_End(i) = NPC_Mean{i}(end);
    
    NPV_Start(i) = NPV_Mean{i}(1);
    NPR_Start(i) = NPR_Mean{i}(1);
    NPC_Start(i) = NPC_Mean{i}(1);
    
end

for i = 1:length(runtime)
    NPV_initial(i) =  NPV_full{i}.NPV_CM(1);
    NPR_initial(i) =  NPR_full{i}.NPR(1);
    NPC_initial(i) =  NPC_full{i}.NPC(1);
end

%%
yearly = 0:Param.Optimization_Horizon - Param.Min_Horizon;
for i = 1:length(runtime)
    for j = 1:length(yearly)
        ind = NPV_full{i}.month == yearly(j);
        NPV_Progress(i,j) = mean(NPV_full{i}.NPV_CM(ind));
        NPR_Progress(i,j) = mean(NPR_full{i}.NPR(ind));
        NPC_Progress(i,j) = mean(NPC_full{i}.NPC(ind));
        
        NPV_Risky(i,j) = prctile(NPV_full{i}.NPV_CM(ind),90) -...
            prctile(NPV_full{i}.NPV_CM(ind),10);
        
        NPV_P10(i,j) = prctile(NPV_full{i}.NPV_CM(ind),10);
        
        NPV_MM(i,j) =  mean(NPV_full{i}.NPV_CM(ind))...
            - median(NPV_full{i}.NPV_CM(ind));
    end
end
%%
agreement_length = 0:6:42;
figure; hold on; set(gcf, 'Units', 'inches', 'OuterPosition', [1, 1, 17, 10]);
s1=scatter(agreement_length, NPV_Start(1:8),100,'r','filled'); hold on;
s3=scatter(agreement_length, NPV_Start(9  :end),100,'g','filled');

labels = num2str(NPV_Start(1:end-1)','%.1f');    %'
text(agreement_length(1:end-1)+0.5, NPV_Start(1:end-1), labels,...
    'horizontal','left','vertical','middle','Color','red','FontSize',16)

labels = num2str(NPV_Start(end)','%.1f');    %'
text(agreement_length(end)+0.5, NPV_Start(end), labels,...
    'horizontal','left','vertical','bottom','Color','red','FontSize',16)

s2=scatter(agreement_length, NPV_End,100,'b','filled');
labels = num2str(NPV_End','%.1f');    %'
text(agreement_length+0.5, NPV_End, labels,...
    'horizontal','left','vertical','bottom','Color','blue','FontSize',16)

xticks(agreement_length);
xticklabels({'0','6','12','18','24','30','36','36'})

xlim([-1 max(agreement_length)+3]);
text(42,38,['Deterministic' newline 'Solution'],...
    'HorizontalAlignment','center','FontSize',20)

v1 = [39 0; 39 70; 50 70; 50 0]; f1 = [1 2 3 4];
patch('Faces',f1,'Vertices',v1,'FaceColor','black','FaceAlpha',.1,...
    'EdgeColor','none');

ylim([0 40])
ytickformat('$%,.0f'); ylabel('Forecast & Mean NPV [Millions]');
%yticks(0:5:40);
xlabel('Agreement Duration [Months]');

set(gca, 'Fontsize', 32); tightfig; box on
legend('Static Price Forecast','Stochastic Scenarios','location','north');
print(gcf,'Initial_NPV_D50','-dpng');

%%
figure; set(gcf, 'Units', 'inches', 'OuterPosition', [1, 1, 17, 10]);

p1 = plot(sort(NPV_Final{1}(:,end)),...
    linspace(0,100,Param.Price_Paths),'linewidth',1.5); hold on

p6 = plot(sort(NPV_Final{2}(:,end)),...
    linspace(0,100,Param.Price_Paths),'linewidth',1.5);

p12 = plot(sort(NPV_Final{3}(:,end)),...
    linspace(0,100,Param.Price_Paths),'linewidth',1.5);

p24 = plot(sort(NPV_Final{end}(:,end)),...
    linspace(0,100,Param.Price_Paths),'linewidth',1.5);

p36 = plot(sort(NPV_Final{end-1}(:,end)),...
    linspace(0,100,Param.Price_Paths),'linewidth',1.5);

plot([min(NPV_Final{end}(:,end)) max(NPV_Final{end}(:,end))],[90 90],'k--');
plot([min(NPV_Final{end}(:,end)) max(NPV_Final{end}(:,end))],[10 10],'k--');

xtickformat('$%,.0f'); xlabel('NPV [Millions]'); xlim([-200 250]); xticks([-200:50:250]);
ylabel('Percentile'); ylim([0 100]); yticks([0:10:100]);

set(gcf,'PaperSize',[15 10]); %set the paper size to what you want
axis([prctile(NPV_Final{end}(:,end),0.5) prctile(NPV_Final{end}(:,end),99.5) 0 100])
set(gca, 'Fontsize', 28); tightfig; box on

leg = legend([p1 p6 p12 p24 p36],'0 Months','6 Months', '12 Months', '36 Months',...
    ['36 Months', newline, '(Deterministic)'],'location','east')
title(leg,'Agreement Length'); leg.FontSize=18;

x = [0.2 0.2]; y = [0.57 0.88];
a = annotation('textarrow',x,y,'String','NPV Risk');
a.Color = 'red'; a.FontSize = 24;

x = [0.2 0.2]; y = [0.53 0.22];
a = annotation('textarrow',x,y);
a.Color = 'red'; a.FontSize = 24;

print(gcf,'P10_P90_D_50','-dpng') % then print it
%%
figure; hold on;
set(gcf, 'Units', 'inches', 'OuterPosition', [1, 1, 15, 10]);
colormap('cool'); h = colorbar('Ticks', agreement_length(1:end-1));
h.Limits=[0 36]; ylabel(h, 'Agreement Length');

xlim([0 300]); xticks([0:50:300])

Pareto2 = plot(NPV_Risky(1:end-1,end),NPV_Progress(1:end-1,end),'k--');
SS=scatter(NPV_Risky(1:end-1,end),NPV_Progress(1:end-1,end),95,...
    agreement_length(1:end-1),'filled');
DS=scatter(NPV_Risky(end,end),NPV_Progress(end,end),95,'filled','k');

text(NPV_Risky(end,end)+2, NPV_Progress(end,end), 'Solution-A',...
    'horizontal','left','vertical','bottom','FontSize',16)

text(NPV_Risky(end-1,end)+2, NPV_Progress(end-1,end), 'Solution-B',...
    'horizontal','left','vertical','bottom','FontSize',16)

text(NPV_Risky(2,end)+4, NPV_Progress(2,end)-2, 'Solution-C',...
    'horizontal','left','vertical','bottom','FontSize',16)

legend([SS DS],'Stochastic Solutions','Deterministic Solution')

ytickformat('$%,.0f'); ylabel('Mean NPV [Millions]');
xtickformat('$%,.0f'); xlabel('NPV Risk [Millions]');

xlim([0 260]); xticks([0:50:300])
ylim([0 round(max(NPV_Progress(:,end))*1.2,-1)])
set(gca, 'Fontsize', 24);

set(gcf,'PaperSize',[15 10]); box on;
print(gcf,'Risk_Return_D_50','-dpng') %

Pareto_Table=NPV_End; Pareto_Table(2,:)=NPV_Risky(:,end);

%%
figure; set(gcf, 'Units', 'inches', 'OuterPosition', [1, 1, 10, 10]);
scatter(NPV_Final{end}(:,end), NPV_Final{end-1}(:,end),60, mean(exp(NGP)),'filled'); hold on;
axis([-300 500 -300 500]); plot([-300 500],[-300 500],'k--');
xlabel('Solution-A [$10^6]'); xtickformat('$%,.0f'); xticks([-300:100:500]);
ylabel('Solution-B [$10^6]'); ytickformat('$%,.0f'); yticks([-300:100:500]);
colormap jet

cb=colorbar(); cb.Limits = [2 4]; cb.Ticks = 2:.25:4;
cb.TickLabels = {'$2.00', '$2.25', '$2.50', '$2.75', '$3.00', '$3.25', '$3.50', '$3.75', '$4.00'};
ylabel(cb,'Mean Scenario Gas Price');

set(gcf,'PaperSize',[10 10]); %set the paper size to what you want
set(gca, 'Fontsize', 20);
print(gcf,'Scatter_1_Case_D_50','-dpng') % then print it

%%
figure; set(gcf, 'Units', 'inches', 'OuterPosition', [1, 1, 10, 10]);
scatter(NPV_Final{end}(:,end), NPV_Final{2}(:,end),60, mean(exp(NGP)),'filled'); hold on;
axis([-300 500 -300 500]); plot([-300 500],[-300 500],'k--');
xlabel('Solution-A [$10^6]'); xtickformat('$%,.0f'); xticks([-300:100:500]);
ylabel('Solution-C [$10^6]'); ytickformat('$%,.0f'); yticks([-300:100:500]);
colormap jet

cb=colorbar(); cb.Limits = [2 4]; cb.Ticks = 2:.25:4;
cb.TickLabels = {'$2.00', '$2.25', '$2.50', '$2.75', '$3.00', '$3.25', '$3.50', '$3.75', '$4.00'};
ylabel(cb,'Mean Scenario Gas Price');

set(gcf,'PaperSize',[10 10]); set(gca, 'Fontsize', 20);
print(gcf,'Scatter_2_Case_D_50','-dpng') % then print it
%%
figure; set(gcf, 'Units', 'inches', 'OuterPosition', [1, 1, 10, 10]);
colormap jet
scatter(NPV_Final{end}(:,end), NPV_Final{end-1}(:,end),60,NPC_Final{end-1}(:,end),'filled'); hold on;
axis([-300 500 -300 500]); plot([-300 500],[-300 500],'k--');
xlabel('Solution-A [$10^6]'); xtickformat('$%,.0f'); xticks([-300:100:500]);
ylabel('Solution-B [$10^6]'); ytickformat('$%,.0f'); yticks([-300:100:500]);

cb=colorbar(); %caxis([232.5394 936.0700]);
ylabel(cb,'Net Present Cost (Solution-B)');

set(gcf,'PaperSize',[10 10]); set(gca, 'Fontsize', 20);
print(gcf,'Scatter_3_Case_D_50','-dpng')
%%
figure; set(gcf, 'Units', 'inches', 'OuterPosition', [1, 1, 10, 10]);
colormap jet
scatter(NPV_Final{end}(:,end), NPV_Final{2}(:,end),60,NPC_Final{1}(:,end),'filled'); hold on;
axis([-300 500 -300 500]); plot([-300 500],[-300 500],'k--');
xlabel('Solution-A [$10^6]'); xtickformat('$%,.0f'); xticks([-300:100:500]);
ylabel('Solution-C [$10^6]'); ytickformat('$%,.0f'); yticks([-300:100:500]);

cb=colorbar(); %caxis([232.5394 936.0700]);
ylabel(cb,'Net Present Cost (Solution-C)');

% future = area([0 500],[5 5]);
% future.FaceAlpha = 0.1;
% future.FaceColor = [0.25 0.25 0.25];

set(gcf,'PaperSize',[10 10]);  set(gca, 'Fontsize', 20);
print(gcf,'Scatter_4_Case_D_50','-dpng');

%%
[Y_36 I_36] = sort((NPV_Final{end-1}(:,end)-NPV_Final{end}(:,end)), 'descend');

rank = [[1:3]'; [998:1000]']; VSS_table_36 = table(rank); VSS_table_36.PS = I_36(rank);

VSS_table_36.NPV_36 = NPV_Final{end-1}(I_36(rank),end);
VSS_table_36.NPV_36D = NPV_Final{end}(I_36(rank),end);
VSS_table_36.R = NPC_Final{end-1}(I_36(rank),end)./NPC_Final{end}(I_36(rank),end);

VSS_table_36.rank(end+1) = 11;
VSS_table_36.NPV_36(end) = mean(NPV_Final{end-1}(:,end));
VSS_table_36.NPV_36D(end) = mean(NPV_Final{end}(:,end));
VSS_table_36.R(end) = mean(NPC_Final{end-1}(I_36,end)./NPC_Final{end}(I_36,end));

VSS_table_36.rank(end+1) = 12;
VSS_table_36.NPV_36(end) = median(NPV_Final{end-1}(:,end));
VSS_table_36.NPV_36D(end) = median(NPV_Final{end}(:,end));
VSS_table_36.R(end) = median(NPC_Final{end-1}(I_36,end)./NPC_Final{end}(I_36,end));
%%
I=VSS_table_36.PS(1);

for m_time = 0:12:84
    figure; set(gcf, 'Units', 'inches', 'OuterPosition', [1, 1, 20, 6]);
    
    ind_MS_1 = On_Demand_WD_full{end-1}.Price_Scenario==I &...
        On_Demand_WD_full{end-1}.month==m_time;
    OD_1=bar(On_Demand_WD_full{end-1}.Horizon(ind_MS_1),...
        On_Demand_WD_full{end-1}.On_Demand_WD(ind_MS_1));
    OD_1.FaceColor = [0.75 0.00 0.75];
    
    hold on;
    
    ind_MS_2 = On_Demand_WD_p_full{end-1}.Price_Scenario==I &...
        On_Demand_WD_p_full{end-1}.month==m_time;
    OD_2=bar(On_Demand_WD_p_full{end-1}.Horizon(ind_MS_2),...
        On_Demand_WD_p_full{end-1}.On_Demand_WD_p(ind_MS_2));
    OD_2.FaceColor = [0.75 0.00 0.75];
    
    ind_X = Long_Term_WD_Usage_full{end-1}.Price_Scenario==I &...
        Long_Term_WD_Usage_full{end-1}.month==m_time;
    LT_1 = bar(Long_Term_WD_Usage_full{end-1}.Horizon(ind_X),...
        Long_Term_WD_Usage_full{end-1}.Long_Term_WD_Usage(ind_X));
    
    LT_1.FaceColor = [0.0 0.5 1.0];
    
    ind_X = Long_Term_WD_Usage_p_full{end-1}.Price_Scenario==I &...
        Long_Term_WD_Usage_p_full{end-1}.month==m_time;
    LT_2 = bar(Long_Term_WD_Usage_p_full{end-1}.Horizon(ind_X),...
        Long_Term_WD_Usage_p_full{end-1}.Long_Term_WD_Usage_p(ind_X));
    
    LT_2.FaceColor = [0.0 0.5 1.0];
    
    %     ind_X = x_full{end-1}.Price_Scenario==I & x_full{end-1}.month==m_time;
    %     b=bar(x_full{end-1}.Horizon(ind_X),x_full{end-1}.x(ind_X));
    %     b.EdgeColor = 'g'; b.LineWidth = 1.5; b.FaceAlpha = .2;
    %     b.FaceColor = [0.00 0.75 0.75];
    
    ind_X = x_full{end-1}.Price_Scenario==I & x_full{end-1}.month==m_time;
    b=bar(x_full{end-1}.Horizon(ind_X),x_full{end-1}.x(ind_X));
    b.EdgeColor = 'g'; b.LineWidth = 1.5; b.FaceAlpha = .2;
    b.FaceColor = [0.00 0.75 0.75];
    
    axis([-1 84 0 2.5]); yticks([0:1:2]); xticks(0:6:84);
    
    t=text(0,2.4,strcat('@ Time = ',{' '},num2str(m_time),{' '},'Months'));
    t.FontSize = 24;
    
    ylabel('Rig Count/Gas Tranport [#/Well EUR]'); xlabel('Time [Months]'); yyaxis right;
    
    ax = gca; ax.YColor = 'r'; %ax.XTick=[m_time-6:6:m_time+36];
    axis([-1 84 0 5.0]);
    
    ind_NG = NG_Realized_full{2}.Price_Scenario==I &...
        NG_Realized_full{2}.month==m_time;
    NG_1 = plot(NG_Realized_full{2}.Horizon(ind_NG),...
        NG_Realized_full{2}.NG_Realized(ind_NG)+0.1,'r','LineWidth',1.5);
    
    ind_NG = NG_Future_full{2}.Price_Scenario==I &...
        NG_Future_full{2}.month==m_time;
    NG_2 = plot(NG_Future_full{2}.Horizon(ind_NG),...
        NG_Future_full{2}.NG_Future(ind_NG)+0.1,'r--','LineWidth',1.25);
    
    ct = plot([m_time m_time],[0 5],'k:');
    ylabel('Natural Gas Price [$/MMBtu]'); ytickformat('$%,.2f');
    
    rl=plot([0 96], [Param.ReversionLevel+0.1 Param.ReversionLevel+0.1],'k-',...
        'LineWidth',0.5);
    
    set(gca, 'Fontsize', 18); tightfig;
    
    future = area([m_time 96],[5 5]);
    future.FaceAlpha = 0.1;
    future.FaceColor = [0.25 0.25 0.25];
    future.LineStyle = 'none';
    
    legend([OD_1 LT_1 b NG_1 NG_2 rl], 'On-Demand D&C',...
        'Long-Term D&C','Gas Transport',...
        'Realized Price','Futures Price','Reversion Level',...
        'location','southeast','NumColumns',4)
    
    print(gcf,strcat('DS_1_High_',num2str(m_time)),'-dpng') % then print it
end

figure; set(gcf, 'Units', 'inches', 'OuterPosition', [1, 1, 20, 6]);
ind_GP_1 = GP_full{end-1}.Price_Scenario==I & GP_full{end-1}.month==m_time;
GP_1=plot(GP_full{end-1}.Horizon(ind_GP_1),GP_full{end-1}.GP_v(ind_GP_1),'--','LineWidth',1.5); hold on;

ind_GP_2 = GP_full{end}.Price_Scenario==I & GP_full{end}.month==m_time;
GP_2=plot(GP_full{end}.Horizon(ind_GP_2),GP_full{end}.GP_v(ind_GP_2),'--','LineWidth',1.5);

xticks(0:6:84);

ylabel('Gas Production [Bcf/Month]'); xlabel('Time [Months]'); ylim([0 17.5]); yticks(0:2.5:17.5); ytickformat('%,.1f');
yyaxis right; ax = gca; ax.YColor = 'r'; axis([0 84 0 5.0]);

ind_NG = NG_Realized_full{2}.Price_Scenario==I & NG_Realized_full{2}.month==m_time;
NG_1 = plot(NG_Realized_full{2}.Horizon(ind_NG), NG_Realized_full{2}.NG_Realized(ind_NG)+0.1,'r','LineWidth',1.5);
ylabel('Natural Gas Price [$/MMBtu]'); ytickformat('$%,.2f'); xticks(0:6:84);

rl = plot([0 96], [Param.ReversionLevel+0.1 Param.ReversionLevel+0.1],'k-', 'LineWidth',0.5);

set(gca, 'Fontsize', 24); tightfig;

legend([GP_1 GP_2 NG_1 rl], 'Dynamic','Static','Realized Price','Reversion Level','location','northwest','NumColumns',4)

print(gcf,'GP_High','-dpng') % then print it

%%
I=VSS_table_36.PS(end-2);

for m_time = 0:12:84
    figure;
    set(gcf, 'Units', 'inches', 'OuterPosition', [1, 1, 20, 6]);
    
    ind_MS_1 = On_Demand_WD_full{end-1}.Price_Scenario==I &...
        On_Demand_WD_full{end-1}.month==m_time;
    OD_1=bar(On_Demand_WD_full{end-1}.Horizon(ind_MS_1),...
        On_Demand_WD_full{end-1}.On_Demand_WD(ind_MS_1));
    OD_1.FaceColor = [0.75 0.00 0.75];
    
    hold on;
    
    ind_MS_2 = On_Demand_WD_p_full{end-1}.Price_Scenario==I &...
        On_Demand_WD_p_full{end-1}.month==m_time;
    OD_2=bar(On_Demand_WD_p_full{end-1}.Horizon(ind_MS_2),...
        On_Demand_WD_p_full{end-1}.On_Demand_WD_p(ind_MS_2));
    OD_2.FaceColor = [0.75 0.00 0.75];
    
    ind_X = Long_Term_WD_Usage_full{end-1}.Price_Scenario==I &...
        Long_Term_WD_Usage_full{end-1}.month==m_time;
    LT_1 = bar(Long_Term_WD_Usage_full{end-1}.Horizon(ind_X),...
        Long_Term_WD_Usage_full{end-1}.Long_Term_WD_Usage(ind_X));
    
    LT_1.FaceColor = [0.0 0.5 1.0];
    
    ind_X = Long_Term_WD_Usage_p_full{end-1}.Price_Scenario==I &...
        Long_Term_WD_Usage_p_full{end-1}.month==m_time;
    LT_2 = bar(Long_Term_WD_Usage_p_full{end-1}.Horizon(ind_X),...
        Long_Term_WD_Usage_p_full{end-1}.Long_Term_WD_Usage_p(ind_X));
    
    LT_2.FaceColor = [0.0 0.5 1.0];
    
    ind_X = x_full{end-1}.Price_Scenario==I & x_full{end-1}.month==m_time;
    b=bar(x_full{end-1}.Horizon(ind_X),x_full{end-1}.x(ind_X));
    b.EdgeColor = 'g'; b.LineWidth = 1.5; b.FaceAlpha = .2;
    b.FaceColor = [0.00 0.75 0.75];
    
    axis([-1 84 0 2.5]); yticks([0:1:2]); xticks(0:6:96);
    
    t=text(0,2.4,strcat('@ Time = ',{' '},num2str(m_time),{' '},'Months'));
    t.FontSize = 24;
    
    ylabel('Rig Count/Gas Tranport [#/Well EUR]'); xlabel('Time [Months]'); yyaxis right;
    
    ax = gca; ax.YColor = 'r'; %ax.XTick=[m_time-6:6:m_time+36];
    axis([-1 84 0 5.0]);
    
    ind_NG = NG_Realized_full{2}.Price_Scenario==I &...
        NG_Realized_full{2}.month==m_time;
    NG_1 = plot(NG_Realized_full{2}.Horizon(ind_NG),...
        NG_Realized_full{2}.NG_Realized(ind_NG)+0.1,'r','LineWidth',1.5);
    
    ind_NG = NG_Future_full{2}.Price_Scenario==I &...
        NG_Future_full{2}.month==m_time;
    NG_2 = plot(NG_Future_full{2}.Horizon(ind_NG),...
        NG_Future_full{2}.NG_Future(ind_NG)+0.1,'r--','LineWidth',1.25);
    
    ct = plot([m_time m_time],[0 5],'k:');
    ylabel('Natural Gas Price [$/MMBtu]'); ytickformat('$%,.2f');
    
    rl=plot([0 96], [Param.ReversionLevel+0.1 Param.ReversionLevel+0.1],'k-','LineWidth',0.5);
    
    set(gca, 'Fontsize', 18); tightfig;
    
    future = area([m_time 96],[5 5]);
    future.FaceAlpha = 0.1;
    future.FaceColor = [0.25 0.25 0.25];
    future.LineStyle = 'none';
    
    legend([OD_1 LT_1 b NG_1 NG_2 rl], 'On-Demand D&C',...
        'Long-Term D&C','Gas Transport',...
        'Realized Price','Futures Price','Reversion Level',...
        'location','southeast','NumColumns',2)
    
    print(gcf,strcat('DS_1_Low_',num2str(m_time)),'-dpng') % then print it
end
%%
figure; set(gcf, 'Units', 'inches', 'OuterPosition', [1, 1, 20, 6]);

ind_GP_1 = GP_full{end-1}.Price_Scenario==I & GP_full{end-1}.month==m_time;
GP_1=plot(GP_full{end-1}.Horizon(ind_GP_1),GP_full{end-1}.GP_v(ind_GP_1),'--','LineWidth',1.5); hold on;

ind_GP_2 = GP_full{end}.Price_Scenario==I & GP_full{end}.month==m_time;
GP_2=plot(GP_full{end}.Horizon(ind_GP_2),GP_full{end}.GP_v(ind_GP_2),'--','LineWidth',1.5);

ylabel('Gas Production [Bcf/Month]'); xlabel('Time [Months]'); ylim([0 17.5]); yticks(0:2.5:17.5); ytickformat('%,.1f');
yyaxis right; ax = gca; ax.YColor = 'r'; axis([0 84 0 5.0]);

ind_NG = NG_Realized_full{2}.Price_Scenario==I & NG_Realized_full{2}.month==m_time;
NG_1 = plot(NG_Realized_full{2}.Horizon(ind_NG), NG_Realized_full{2}.NG_Realized(ind_NG)+0.1,'r','LineWidth',1.5);
ylabel('Natural Gas Price [$/MMBtu]'); ytickformat('$%,.2f'); xticks(0:6:84);

rl=plot([0 96], [Param.ReversionLevel+0.1 Param.ReversionLevel+0.1],'k-', 'LineWidth',0.5);

set(gca, 'Fontsize', 24); tightfig;

legend([GP_1 GP_2 NG_1 rl], 'Dynamic','Static','Realized Price','Reversion Level','location','northwest','NumColumns',4)

print(gcf,'GP_Low','-dpng') % then print it

%%
ind_80 = NPC_Final{2}(:,end)>NPC_Final{end}(:,end)*0.00;
[Y_80 I_80] = sort((NPV_Final{2}(:,end).*ind_80-NPV_Final{end}(:,end).*ind_80),'descend');

rank = [[1:3]'; 501; [998:1000]']; VSS_table_80 = table(rank); VSS_table_80.PS = I_80(rank);

VSS_table_80.NPV_0 = NPV_Final{2}(I_80(rank),end);
VSS_table_80.NPV_36 = NPV_Final{end}(I_80(rank),end);

VSS_table_80.R1 = NPC_Final{2}(I_80(rank),end)./NPC_Final{end-1}(I_80(rank),end);

VSS_table_80.rank(end+1) = 11;
VSS_table_80.NPV_0(end) = mean(NPV_Final{2}(:,end));
VSS_table_80.NPV_36(end) = mean(NPV_Final{end}(:,end));

VSS_table_80.R1(end) =...
    mean(NPC_Final{2}(:,end)./NPC_Final{end}(:,end));

VSS_table_80.rank(end+1) = 11;
VSS_table_80.NPV_0(end) = median(NPV_Final{2}(:,end));
VSS_table_80.NPV_36(end) = median(NPV_Final{end}(:,end));
VSS_table_80.R1(end) =...
    median(NPC_Final{2}(:,end)./NPC_Final{end}(:,end));

%%
I = VSS_table_80.PS(4);
for m_time = 0:12:84
    figure; set(gcf, 'Units', 'inches', 'OuterPosition', [1, 1, 20, 6]);
    
    ind_MS_1 = On_Demand_WD_full{2}.Price_Scenario==I &...
        On_Demand_WD_full{2}.month==m_time;
    OD_1=bar(On_Demand_WD_full{2}.Horizon(ind_MS_1),...
        On_Demand_WD_full{2}.On_Demand_WD(ind_MS_1));
    OD_1.FaceColor = [0.75 0.00 0.75];
    
    hold on;
    
    ind_MS_2 = On_Demand_WD_p_full{2}.Price_Scenario==I &...
        On_Demand_WD_p_full{2}.month==m_time;
    OD_2=bar(On_Demand_WD_p_full{2}.Horizon(ind_MS_2),...
        round(On_Demand_WD_p_full{2}.On_Demand_WD_p(ind_MS_2)));
    OD_2.FaceColor = [0.75 0.00 0.75];
    
    ind_X = Long_Term_WD_Usage_full{2}.Price_Scenario==I &...
        Long_Term_WD_Usage_full{2}.month==m_time;
    LT_1 = bar(Long_Term_WD_Usage_full{2}.Horizon(ind_X),...
        Long_Term_WD_Usage_full{2}.Long_Term_WD_Usage(ind_X));
    
    LT_1.FaceColor = [0.0 0.5 1.0];
    
    ind_X = Long_Term_WD_Usage_p_full{2}.Price_Scenario==I &...
        Long_Term_WD_Usage_p_full{2}.month==m_time;
    LT_2 = bar(Long_Term_WD_Usage_p_full{2}.Horizon(ind_X),...
        Long_Term_WD_Usage_p_full{2}.Long_Term_WD_Usage_p(ind_X));
    
    LT_2.FaceColor = [0.0 0.5 1.0];
    
    ind_X = x_full{2}.Price_Scenario==I & x_full{2}.month==m_time;
    b=bar(x_full{2}.Horizon(ind_X),x_full{2}.x(ind_X));
    b.EdgeColor = 'g'; b.LineWidth = 1.5; b.FaceAlpha = .2;
    b.FaceColor = [0.00 0.75 0.75];
    
    axis([-1 84 0 2.5]); yticks([0:1:2]); xticks(0:6:84);
    
    t=text(0,2.4,strcat('@ Time = ',{' '},num2str(m_time),{' '},'Months'));
    t.FontSize = 24;
    
    ylabel('Rig Count/Gas Tranport [#/Well EUR]'); xlabel('Time [Months]'); yyaxis right;
    
    ax = gca; ax.YColor = 'r'; %ax.XTick=[m_time-6:6:m_time+36];
    axis([-1 84 0 5.0]);
    
    ind_NG = NG_Realized_full{2}.Price_Scenario==I &...
        NG_Realized_full{2}.month==m_time;
    NG_1 = plot(NG_Realized_full{2}.Horizon(ind_NG),...
        NG_Realized_full{2}.NG_Realized(ind_NG)+0.1,'r','LineWidth',1.5);
    
    ind_NG = NG_Future_full{2}.Price_Scenario==I &...
        NG_Future_full{2}.month==m_time;
    NG_2 = plot(NG_Future_full{2}.Horizon(ind_NG),...
        NG_Future_full{2}.NG_Future(ind_NG)+0.1,'r--','LineWidth',1.25);
    
    ct = plot([m_time m_time],[0 5],'k:');
    ylabel('Natural Gas Price [$/MMBtu]'); ytickformat('$%,.2f');
    
    rl=plot([0 96], [Param.ReversionLevel+0.1 Param.ReversionLevel+0.1],'k-',...
        'LineWidth',0.5);
    
    set(gca, 'Fontsize', 18); tightfig;
    
    future = area([m_time 96],[5 5]);
    future.FaceAlpha = 0.1;
    future.FaceColor = [0.25 0.25 0.25];
    future.LineStyle = 'none';
    
    legend([OD_1 LT_1 b NG_1 NG_2 rl], 'On-Demand D&C',...
        'Long-Term D&C','Gas Transport',...
        'Realized Price','Futures Price','Reversion Level',...
        'location','southeast','NumColumns',4)
    
    print(gcf,strcat('DS_Mid',num2str(m_time)),'-dpng') % then print it
end
%%

figure; set(gcf, 'Units', 'inches', 'OuterPosition', [1, 1, 20, 6]);
ind_GP_1 = GP_full{2}.Price_Scenario==I & GP_full{2}.month==m_time;
GP_1=plot(GP_full{2}.Horizon(ind_GP_1),GP_full{2}.GP_v(ind_GP_1),'--','LineWidth',1.5); hold on;

ind_GP_2 = GP_full{end}.Price_Scenario==I & GP_full{end}.month==m_time;
GP_2=plot(GP_full{end}.Horizon(ind_GP_2),GP_full{end}.GP_v(ind_GP_2),'--','LineWidth',1.5);

xticks(0:6:84);

ylabel('Gas Production [Bcf/Month]'); xlabel('Time [Months]'); ylim([0 17.5]); yticks(0:2.5:17.5); ytickformat('%,.1f');
yyaxis right; ax = gca; ax.YColor = 'r'; axis([0 84 0 5.0]);

ind_NG = NG_Realized_full{2}.Price_Scenario==I & NG_Realized_full{2}.month==m_time;
NG_1 = plot(NG_Realized_full{2}.Horizon(ind_NG), NG_Realized_full{2}.NG_Realized(ind_NG)+0.1,'r','LineWidth',1.5);
ylabel('Natural Gas Price [$/MMBtu]'); ytickformat('$%,.2f'); xticks(0:6:84);

rl = plot([0 96], [Param.ReversionLevel+0.1 Param.ReversionLevel+0.1],'k-', 'LineWidth',0.5);

set(gca, 'Fontsize', 24); tightfig;

legend([GP_1 GP_2 NG_1 rl], 'Dynamic','Static','Realized Price','Reversion Level','location','northwest','NumColumns',4)

print(gcf,'GP_Mid','-dpng') % then print it
%%
I = VSS_table_80.PS(end-2);
for m_time = 0:12:84
    figure; set(gcf, 'Units', 'inches', 'OuterPosition', [1, 1, 20, 6]);
    
    ind_MS_1 = On_Demand_WD_full{2}.Price_Scenario==I &...
        On_Demand_WD_full{2}.month==m_time;
    OD_1=bar(On_Demand_WD_full{2}.Horizon(ind_MS_1),...
        On_Demand_WD_full{2}.On_Demand_WD(ind_MS_1));
    OD_1.FaceColor = [0.75 0.00 0.75];
    
    hold on;
    
    ind_MS_2 = On_Demand_WD_p_full{2}.Price_Scenario==I &...
        On_Demand_WD_p_full{2}.month==m_time;
    OD_2=bar(On_Demand_WD_p_full{2}.Horizon(ind_MS_2),...
        On_Demand_WD_p_full{2}.On_Demand_WD_p(ind_MS_2));
    OD_2.FaceColor = [0.75 0.00 0.75];
    
    ind_X = Long_Term_WD_Usage_full{2}.Price_Scenario==I &...
        Long_Term_WD_Usage_full{2}.month==m_time;
    LT_1 = bar(Long_Term_WD_Usage_full{2}.Horizon(ind_X),...
        Long_Term_WD_Usage_full{2}.Long_Term_WD_Usage(ind_X));
    
    LT_1.FaceColor = [0.0 0.5 1.0];
    
    ind_X = Long_Term_WD_Usage_p_full{2}.Price_Scenario==I &...
        Long_Term_WD_Usage_p_full{2}.month==m_time;
    LT_2 = bar(Long_Term_WD_Usage_p_full{2}.Horizon(ind_X),...
        Long_Term_WD_Usage_p_full{2}.Long_Term_WD_Usage_p(ind_X));
    
    LT_2.FaceColor = [0.0 0.5 1.0];
    
    ind_X = x_full{2}.Price_Scenario==I & x_full{2}.month==m_time;
    b=bar(x_full{2}.Horizon(ind_X),x_full{2}.x(ind_X));
    b.EdgeColor = 'g'; b.LineWidth = 1.5; b.FaceAlpha = .2;
    b.FaceColor = [0.00 0.75 0.75];
    
    axis([-1 84 0 2.5]); yticks([0:1:2]); xticks(0:6:84);
    
    t=text(0,2.4,strcat('@ Time = ',{' '},num2str(m_time),{' '},'Months'));
    t.FontSize = 24;
    
    ylabel('Rig Count/Gas Tranport [#/Well EUR]'); xlabel('Time [Months]'); yyaxis right;
    
    ax = gca; ax.YColor = 'r'; %ax.XTick=[m_time-6:6:m_time+36];
    axis([-1 84 0 5.25]);
    
    ind_NG = NG_Realized_full{2}.Price_Scenario==I &...
        NG_Realized_full{2}.month==m_time;
    NG_1 = plot(NG_Realized_full{2}.Horizon(ind_NG),...
        NG_Realized_full{2}.NG_Realized(ind_NG)+0.1,'r','LineWidth',1.5);
    
    ind_NG = NG_Future_full{2}.Price_Scenario==I &...
        NG_Future_full{2}.month==m_time;
    NG_2 = plot(NG_Future_full{2}.Horizon(ind_NG),...
        NG_Future_full{2}.NG_Future(ind_NG)+0.1,'r--','LineWidth',1.25);
    
    ct = plot([m_time m_time],[0 5],'k:');
    ylabel('Natural Gas Price [$/MMBtu]'); ytickformat('$%,.2f');
    
    rl=plot([0 96], [Param.ReversionLevel+0.1 Param.ReversionLevel+0.1],'k-',...
        'LineWidth',0.5);
    
    set(gca, 'Fontsize', 18); tightfig;
    
    future = area([m_time 96],[5.25 5.25]);
    future.FaceAlpha = 0.1;
    future.FaceColor = [0.25 0.25 0.25];
    future.LineStyle = 'none';
    
    legend([OD_1 LT_1 b NG_1 NG_2 rl], 'On-Demand D&C',...
        'Long-Term D&C','Gas Transport',...
        'Realized Price','Futures Price','Reversion Level',...
        'location','southeast','NumColumns',4)
    
    print(gcf,strcat('DS_2_Low_',num2str(m_time)),'-dpng') % then print it
end
%%
figure; set(gcf, 'Units', 'inches', 'OuterPosition', [1, 1, 20, 6]);
ind_GP_1 = GP_full{end-1}.Price_Scenario==I & GP_full{end-1}.month==m_time;
GP_1=plot(GP_full{end-1}.Horizon(ind_GP_1),GP_full{end-1}.GP_v(ind_GP_1),'--','LineWidth',1.5); hold on;

ind_GP_2 = GP_full{end}.Price_Scenario==I & GP_full{end}.month==m_time;
GP_2=plot(GP_full{end}.Horizon(ind_GP_2),GP_full{end}.GP_v(ind_GP_2),'--','LineWidth',1.5);

xticks(0:6:84);

ylabel('Gas Production [Bcf/Month]'); xlabel('Time [Months]'); ylim([0 17.5]); yticks(0:2.5:17.5); ytickformat('%,.1f');
yyaxis right; ax = gca; ax.YColor = 'r'; axis([0 84 0 5.25]);

ind_NG = NG_Realized_full{2}.Price_Scenario==I & NG_Realized_full{2}.month==m_time;
NG_1 = plot(NG_Realized_full{2}.Horizon(ind_NG), NG_Realized_full{2}.NG_Realized(ind_NG)+0.1,'r','LineWidth',1.5);
ylabel('Natural Gas Price [$/MMBtu]'); ytickformat('$%,.2f'); xticks(0:6:84);

rl = plot([0 96], [Param.ReversionLevel+0.1 Param.ReversionLevel+0.1],'k-', 'LineWidth',0.5);

set(gca, 'Fontsize', 24); tightfig;

legend([GP_1 GP_2 NG_1 rl], 'Dynamic','Static','Realized Price','Reversion Level','location','northeast','NumColumns',4)

print(gcf,'GP_Low_2','-dpng') % then print it

%%
function solve_ampl(ampl)
evalc('ampl.solve;');
end

function solve_ampl_or(ampl_or)
evalc('ampl_or.solve;');
end

function setUp_ampl()
evalc('setUp;');
end

