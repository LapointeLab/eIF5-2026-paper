function associationKinetics(app)
%ASSOCIATIONKINETICS Plot first-association / reassociation time CDFs for a chosen channel.
%   Module function: takes the AnalysisPipelineApp instance. Built on the
%   shared pipeline.buildCDFModule scaffold (channel + type selector -> eCDF
%   + exponential fit), which also handles the plot, export, and fit UI.
%   Requires app.Data.result (see +pipeline/extractEvents.m) and the
%   Statistics and Machine Learning Toolbox (cdfcalc).
%
%   This module covers waiting times between/before binding events, within
%   a single channel:
%     First association  - time from the start of data collection (the
%                           first recorded frame) to a molecule's first
%                           binding event on this channel. One value per
%                           molecule that has at least one event.
%     Reassociation       - time from the end of one binding event to the
%                           start of the next, for the same molecule. If
%                           "Min event frames" filtered out a short blip
%                           between two kept events, the gap spans across
%                           it (a filtered-out blip isn't treated as a real
%                           intervening event).
%
%   Duration of binding events themselves (lifetime) is a separate module —
%   see +modules/bindingLifetimeKinetics.m.

pipeline.buildCDFModule(app, 'Association Kinetics', ...
    {'First association', 'Reassociation'}, {'first', 'reassoc'}, 'first', ...
    'Association time (s)', @computeAssociationTimes);

end

function [rawTimes, molIDs] = computeAssociationTimes(app, chName, typeValue)
chIdx  = find(strcmp(app.Data.result.channelNames, chName), 1);
evList = app.Data.result.events{chIdx};   % unfiltered: need each molecule's full event sequence
t0     = app.Data.result.t(1);

switch typeValue
    case 'first'
        firstEvents = pipeline.filterEventsByType(evList, 'first');
        rawTimes = [firstEvents.onTime] - t0;
        molIDs   = [firstEvents.mol];

    case 'reassoc'
        mols = unique([evList.mol]);
        rawTimes = [];
        molIDs   = [];
        for i = 1:numel(mols)
            molEvents = evList([evList.mol] == mols(i));
            [~, order] = sort([molEvents.eventNum]);
            molEvents = molEvents(order);
            for k = 2:numel(molEvents)
                rawTimes(end+1) = molEvents(k).onTime - molEvents(k-1).offTime; %#ok<AGROW>
                molIDs(end+1)   = mols(i); %#ok<AGROW>
            end
        end

    otherwise
        error('modules:associationKinetics:invalidType', 'Unknown association type "%s".', typeValue);
end
end
