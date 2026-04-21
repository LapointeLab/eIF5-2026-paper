%This script assigns ON and OFF dye states in TIRF experiments
 
[r c] = size(ttotal);
if exist('states') == 0
    states = zeros(r,c);
end
nmol = (c-1)/3;
 
c = input('Start from molecule # ->', 's');
c = str2num(c);
t = ttotal(:,1);
p = 0;
while c <= nmol
    
    %Lets calculate number of the red states in the vector
    
    on_indeces = (find(states(:,3*c+1) == 1))';
    if (isempty(on_indeces) == 0)
        on_indeces_shift = on_indeces(1:length(on_indeces)-1);
        on_indeces_shift = [0 on_indeces_shift];
        on_indeces_shift = on_indeces - on_indeces_shift;
        on_indeces_shift(1) = [];
        number_of_states = find(on_indeces_shift > 1);
        number_of_states = length(number_of_states)+1;
    else
        number_of_states = 0;
    end
    
    
    %Time to plot
    % normalize FRET on min min red and -20 green
    % FRET_normalized = (ttotal(:, 3*c) - min(ttotal(20:end, 3*c)))./(ttotal(:, 3*c-1) + ttotal(:, 3*c) - 2*min(ttotal(20:end, 3*c)));
    FRET_normalized = ttotal(:, 3*c+1);
    
    % Get current axis state
    if exist('h') == 1
        xlim_sublopt_1 = xlim(h(1));
        ylim_sublopt_1 = ylim(h(1));
        xlim_sublopt_2 = xlim(h(2));
        ylim_sublopt_2 = ylim(h(2));
    end
    
    h(1) = subplot(2,1,1)
    plot(t,ttotal(:,c*3),'r', t,ttotal(:,c*3-1),'g')
    title(['Molecule ' num2str(c) ' Number of FRET ON events ' num2str(number_of_states)], 'FontSize', 14, 'FontName', 'Arial', 'FontWeight', 'bold')
    ylabel('Fluorescence intensity, A.U.','FontSize', 12, 'FontName', 'Arial', 'FontWeight', 'bold')
    
    set(gca,'FontSize', 12, 'FontName', 'Arial', 'FontWeight', 'bold')
    %See if trace changed and apply axes limits as necessary
    grid on
    if p == c
        xlim(xlim_sublopt_1);
        ylim(ylim_sublopt_1);
    else
        xlim([0 max(t)])
    end
    
    h(2) = subplot(2,1,2)
    plot( t,FRET_normalized,'b', t,0.9*states(:,c*3+1), '--k', 'LineWidth', 1)
    title(['Molecule ' num2str(c)], 'FontSize', 14, 'FontName', 'Arial', 'FontWeight', 'bold')
    xlabel('Time, sec','FontSize', 12, 'FontName', 'Arial', 'FontWeight', 'bold')
    ylabel('FRET intensity, A.U.','FontSize', 12, 'FontName', 'Arial', 'FontWeight', 'bold')
    set(gca,'FontSize', 12, 'FontName', 'Arial', 'FontWeight', 'bold')
    
    if p == c
        xlim(xlim_sublopt_2);
        ylim(ylim_sublopt_2);
    else
        xlim([0 max(t)])
        ylim([-0.2 1])
     end
    p = c;
    
    linkaxes(h, 'x')
    grid on
    zoom on
    
    %Decision tree
    answ = input('accept trace (y), erase states (;) reassign (./) treshold assign (t) or back to previous trace (p) -> ','s');
    
    if strcmp(answ,'y') == 1
        disp('States accepted, going to the next trace')
        c = c + 1;
    elseif strcmp(answ,';') == 1
        disp('States has been erased')
        states(1:r, 3*c+1) = 0;
    elseif strcmp(answ,'t') == 1
        disp('Reassign states, R boundary, L boundary, height on 2nd click is threshold')
        [x,y,button] = ginput(2);
        leftboundary = find (t > min([x(1) x(2)]), 1, 'first');
        rightboundary = find (t < max([x(1) x(2)]), 1, 'last');
        indexes = find(FRET_normalized > y(2));
        indexes(indexes<leftboundary) = [];
        indexes(indexes>rightboundary) = [];
        states(indexes, 3*c+1) = 1;
    elseif strcmp(answ,'p') == 0
        disp('Reassign states, R boundary, L boundary, L = 0, R = 1')
        [x,y,button] = ginput(2);
        leftboundary = find (t > min([x(1) x(2)]), 1, 'first');
        rightboundary = find (t < max([x(1) x(2)]), 1, 'last');
        if button(2) ~= 1
            button(2) = 1;
        else
            button(2) =0;
        end
        states(leftboundary:rightboundary, c*3+1) = button(2);    
    elseif strcmp(answ,'p') == 1
        if c == 1
            beep
            disp('this is the first trace')
        else
            disp('back to previous trace')
            if c == 2
            else
            end
            c = c - 1;
        end
    end
end

clear number_of_states start_index FRET_normalized h lifetime on_indeces on_indeces_shift xlim_sublopt_1 xlim_sublopt_2 ylim_sublopt_1 ylim_sublopt_2
clear n k end_index p leftboundary rightboundary nmol r c button x y SIGMA SIGMAHAT MUHAT BKG answ indexes states_local t vec
 
