function [Prices_Table NGP] = FDP_Input_Data(Price_Path_Number, Initial_Price, ReversionLevel)

%% Add Path Existing Code
foler_path='C:\Users\Demon\Desktop\AMPL\AMPL_Install';
%% Upload Pre Input Data
Pre_Input_Data_Excel='FDP.xlsx';
Pre_Input_Data_File=fullfile(foler_path,Pre_Input_Data_Excel);
[~,Sheet_Names] = xlsfinfo(Pre_Input_Data_File );
Pre_Input_Parameter_Count = readtable(Pre_Input_Data_File,'Sheet','Parameter_Count'); Param=[];

for i = 1:height(Pre_Input_Parameter_Count)
    Pre_Input_Data.Parameter_Count.(Pre_Input_Parameter_Count.Table_Name{i})=...
        Pre_Input_Parameter_Count.Parameter_Count(i);
end
for i = Sheet_Names
    if not(strcmp(i,'Parameter_Count') || strcmp(i,'Tuple_Sets'))
        Pre_Input_Data.(i{:})= readtable(Pre_Input_Data_File,'Sheet',i{:});
    end
end

for i = 1:height(Pre_Input_Data.Param_Table)
    Param.(Pre_Input_Data.Param_Table.Abbrev{i})=Pre_Input_Data.Param_Table.Param(i);
end

Param.Price_Paths = Price_Path_Number;
Param.Initial_Price = Initial_Price;
Param.ReversionLevel = ReversionLevel;
%%
[Prices_Table, NGP, Ssim] = NG_Price_Uncertainity_Parallel(Pre_Input_Data, Param, Param.Price_Paths);
%save('Ssim.mat', 'Ssim'); save('NGP.mat', 'NGP');

Price_Scenario = unique(Prices_Table.Price_Scenario);
Post_Input_Data.Prices_Table=Prices_Table;
Post_Input_Data.Parameter_Count.Prices_Table=2;

%% Create Single Sets From Pre Data
Pre_Input_Fields = fieldnames(Pre_Input_Data);
Set_Names=[];

for i = Pre_Input_Fields'
    if not(strcmp(i,'Parameter_Count') || strcmp(i,'Tuple_Sets') || strcmp(i,'pc_tuple') || strcmp(i,'Scenario_Tree'))
        VarNames = Pre_Input_Data.(i{:}).Properties.VariableNames;
        for j = 1:Pre_Input_Data.Parameter_Count.(i{:})
            Pre_Input_Data.(VarNames{j})=unique(Pre_Input_Data.(i{:})(:,j));
            Set_Names=[Set_Names VarNames(j)];
        end
    end
end

%% Create Single Sets From Post Data
Post_Input_Fields = fieldnames(Post_Input_Data);
Post_Input_Fields = Post_Input_Fields(logical(~(strcmp(Post_Input_Fields,'Parameter_Count')).*~(strcmp(Post_Input_Fields,'Tuple_Set'))));
% Sets
for i = Post_Input_Fields'
    if not(strcmp(i,'Parameter_Count') || strcmp(i,'Tuple_Sets') || strcmp(i,'pc_tuple') || strcmp(i,'Scenario_Tree'))
        VarNames = Post_Input_Data.(i{:}).Properties.VariableNames;
        for j = 1:Post_Input_Data.Parameter_Count.(i{:})
            if ~isfield(Pre_Input_Data,VarNames{j})
                Post_Input_Data.(VarNames{j})=unique(Post_Input_Data.(i{:})(:,j));
                Set_Names=[Set_Names VarNames(j)];
            end
        end
    end
end

%% Create Dataframe for Matlab's AMPL Object
All_Set_Names =[unique(Set_Names)];
% Sets
for i = All_Set_Names
    if isfield(Pre_Input_Data, (i{:}))
        Sets.(i{:}) = Pre_Input_Data.(i{:});
    else
        Sets.(i{:}) = Post_Input_Data.(i{:});
    end
end

Sets_Fields = setdiff(fields(Sets),'Optimizaton_Horizon');

set_fields = Sets_Fields;
for i = 1:length(set_fields)
    sub_set = Sets.(set_fields{i});
    for j = 1:length(sub_set.(set_fields{i}))
        if height(sub_set)==1
            text_line{i}='set'+" "+set_fields{i}+" "+':='+" "+sub_set.(set_fields{i})(j)+";";
        elseif j ==1
            text_line{i}='set'+" "+set_fields{i}+" "+':='+" "+sub_set.(set_fields{i})(j);
        elseif j< length(sub_set.(set_fields{i}))
            text_line{i}=text_line{i}+" "+sub_set.(set_fields{i})(j);
        else
            text_line{i}=text_line{i}+" "+sub_set.(set_fields{i})(j)+";";
        end
    end
end
%% Parameter
n=i+1; text_line{n}=" ";
n=n+1; text_line{n}="param Param:=";

for i = 1:height(Pre_Input_Data.Param_Table)
    n=n+1;
    if i < height(Pre_Input_Data.Param_Table)
        text_line{n}=Pre_Input_Data.Param_Table.Abbrev(i)+" "+Pre_Input_Data.Param_Table.Param(i);
    else
        text_line{n}=Pre_Input_Data.Param_Table.Abbrev(i)+" "+Pre_Input_Data.Param_Table.Param(i)+";";
    end
end
%%
n=n+1; text_line{n}=" ";
n=n+1; text_line{n}="param EUR_Percent:=";

for i = 1:height(Pre_Input_Data.EUR_Prcnt)
    n=n+1;
    if i < height(Pre_Input_Data.EUR_Prcnt)
        text_line{n}=num2str(Pre_Input_Data.EUR_Prcnt.Component(i))+" "...
            +num2str(Pre_Input_Data.EUR_Prcnt.EUR_Percent(i));
    else
        text_line{n}=num2str(Pre_Input_Data.EUR_Prcnt.Component(i))+" "...
            +num2str(Pre_Input_Data.EUR_Prcnt.EUR_Percent(i))+";";
    end
end
%%
n=n+1; text_line{n}=" ";
n=n+1; text_line{n}="param Coefficient:=";

for i = 1:height(Pre_Input_Data.EUR_Prcnt)
    n=n+1;
    if i < height(Pre_Input_Data.EUR_Prcnt)
        text_line{n}=num2str(Pre_Input_Data.EUR_Prcnt.Component(i))+" "...
            +num2str(Pre_Input_Data.EUR_Prcnt.Coefficient(i));
    else
        text_line{n}=num2str(Pre_Input_Data.EUR_Prcnt.Component(i))+" "...
            +num2str(Pre_Input_Data.EUR_Prcnt.Coefficient(i))+";";
    end
end
%%
n=n+1; text_line{n}=" ";
n=n+1; text_line{n}="param Count:=";

for i = 1:height(Pre_Input_Data.Well_Inventory)
    n=n+1;
    if height(Pre_Input_Data.Well_Inventory)==1
        text_line{n}=Pre_Input_Data.Well_Inventory.Tier(i)+" "...
            +num2str(Pre_Input_Data.Well_Inventory.Count(i))+";";
    elseif i < height(Pre_Input_Data.Well_Inventory)
        text_line{n}=Pre_Input_Data.Well_Inventory.Tier(i)+" "...
            +num2str(Pre_Input_Data.Well_Inventory.Count(i));
    else
        text_line{n}=Pre_Input_Data.Well_Inventory.Tier(i)+" "...
            +num2str(Pre_Input_Data.Well_Inventory.Count(i))+";";
    end
end
%%
n=n+1; text_line{n}=" ";
n=n+1; text_line{n}="param EUR:=";

for i = 1:height(Pre_Input_Data.Well_Inventory)
    n=n+1;
    if height(Pre_Input_Data.Well_Inventory)==1
        text_line{n}=Pre_Input_Data.Well_Inventory.Tier(i)+" "...
            +num2str(Pre_Input_Data.Well_Inventory.EUR(i))+";";
    elseif i < height(Pre_Input_Data.Well_Inventory)
        text_line{n}=Pre_Input_Data.Well_Inventory.Tier(i)+" "...
            +num2str(Pre_Input_Data.Well_Inventory.EUR(i));
    else
        text_line{n}=Pre_Input_Data.Well_Inventory.Tier(i)+" "...
            +num2str(Pre_Input_Data.Well_Inventory.EUR(i))+";";
    end
end

%%
k = ceil(Param.LT_GT_Max_Rate/Param.OD_GT_Max_Rate);
A = Param.LT_GT_Increment.*ones(k*Param.LT_GT_Max_Horizon);B=triu(A);
C = [zeros(length(B),1) B];

x=1;
for i = 1:size(C,2)
    LT_GT_Scenario{x} = ones(Param.LT_GT_Max_Horizon+1,1)*x;
    LT_GT_Horizon{x} = [0:Param.LT_GT_Max_Horizon]';
    LT_GT{x} = [sum(reshape(C(:,i),Param.LT_GT_Max_Horizon,[]),2); 0]; x=x+1;
end
%for i = 1:size(C,2)
%    LT_GT_Scenario{x} = ones(Param.LT_GT_Max_Horizon+1,1)*x;
%    LT_GT_Horizon{x} = [0:Param.LT_GT_Max_Horizon]';
%    LT_GT{x} = [sum(flipud(reshape(C(:,i),[],Param.LT_GT_Max_Horizon))',2); 0]; x=x+1;
%end

n=n+1; text_line{n}=" ";
j={1:x-1}; j_out = cellfun(@num2str,j,'UniformOutput', false);
n=n+1; text_line{n}="set GT_Configurations:="+j_out+";";

%%
k = ceil(Param.LT_WD_Max_Rate/Param.LT_WD_Increment);
A = Param.LT_WD_Increment.*ones(k*Param.LT_WD_Max_Horizon);B=triu(A);
C = [zeros(length(B),1) B];

y=1;
for i = 1:size(C,2)
    LT_WD_Scenario{y} = ones(Param.LT_WD_Max_Horizon+1,1)*y;
    LT_WD_Horizon{y} = [0:Param.LT_WD_Max_Horizon]';
    LT_WD{y} = [sum(reshape(C(:,i),Param.LT_WD_Max_Horizon,[]),2); 0]; y=y+1;
end

%for i = 1:size(C,2)
%    LT_WD_Scenario{y} = ones(Param.LT_WD_Max_Horizon+1,1)*y;
%    LT_WD_Horizon{y} = [0:Param.LT_WD_Max_Horizon]';
%    LT_WD{y} = [sum(flipud(reshape(C(:,i),[],Param.LT_WD_Max_Horizon))',2); 0]; y=y+1;
%end

n=n+1; text_line{n}=" ";
j={1:y-1}; j_out = cellfun(@num2str,j,'UniformOutput', false);
n=n+1; text_line{n}="set WD_Configurations:="+j_out+";";
%%
LT_GT_Final = cell2mat([LT_GT_Scenario' LT_GT_Horizon' LT_GT']);

n=n+1; text_line{n}=" "; n=n+1; text_line{n}="param Take_or_Pay_Options:=";
for i = 1:size(LT_GT_Final,1)
    n=n+1;
    if i < size(LT_GT_Final,1)
        text_line{n}= num2str(LT_GT_Final(i,1))+" "+num2str(LT_GT_Final(i,2))+" "+num2str(LT_GT_Final(i,3));
    else
        text_line{n}= num2str(LT_GT_Final(i,1))+" "+num2str(LT_GT_Final(i,2))+" "+num2str(LT_GT_Final(i,3))+";";
    end
end

%%
LT_WD_Final = cell2mat([LT_WD_Scenario' LT_WD_Horizon' LT_WD']);

n=n+1; text_line{n}=" "; n=n+1; text_line{n}="param Long_Term_WD_Options:=";
for i = 1:size(LT_WD_Final,1)
    n=n+1;
    if i < size(LT_WD_Final,1)
        text_line{n}= num2str(LT_WD_Final(i,1))+" "+num2str(LT_WD_Final(i,2))+" "+num2str(LT_WD_Final(i,3));
    else
        text_line{n}= num2str(LT_WD_Final(i,1))+" "+num2str(LT_WD_Final(i,2))+" "+num2str(LT_WD_Final(i,3))+";";
    end
end
%%
n=n+1; text_line{n}=" ";
n=n+1; text_line{n}="param NGP:=";

for i = 1:height(Post_Input_Data.Prices_Table)
    n=n+1;
    if i < height(Post_Input_Data.Prices_Table)
        text_line{n}=...
            num2str(Post_Input_Data.Prices_Table.Optimizaton_Horizon(i))+" "...
            +num2str(Post_Input_Data.Prices_Table.Price_Scenario(i))+" "...
            +num2str(Post_Input_Data.Prices_Table.NGP(i));
    else
        text_line{n}=...
            num2str(Post_Input_Data.Prices_Table.Optimizaton_Horizon(i))+" "...
            +num2str(Post_Input_Data.Prices_Table.Price_Scenario(i))+" "...
            +num2str(Post_Input_Data.Prices_Table.NGP(i))+";";
    end
end

%%
fid = fopen(strcat('Input_Data_',num2str(Param.Price_Paths),'_',num2str(Param.Initial_Price),'_',num2str(Param.ReversionLevel),'.dat'), 'wt');
for k = 1:length(text_line)
    fprintf(fid, '%s\n', text_line{k});
end
%%

end
