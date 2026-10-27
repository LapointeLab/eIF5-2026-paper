function bindingLifetimeKinetics(app)
%BINDINGLIFETIMEKINETICS Plot the binding-event lifetime CDF for a chosen channel.
%   Module function: takes the AnalysisPipelineApp instance. Built on the
%   shared pipeline.buildCDFModule scaffold (channel + type selector -> eCDF
%   + exponential fit), which also handles the plot, export, and fit UI.
%   Requires app.Data.result (see +pipeline/extractEvents.m) and the
%   Statistics and Machine Learning Toolbox (cdfcalc).
%
%   This module covers duration of binding events only (event lifetime).
%   Arrival/association/reassociation timing is a separate module — see
%   +modules/associationKinetics.m.
%
%   The event set analyzed can be restricted to All events / First event /
%   Subsequent events per molecule via pipeline.filterEventsByType.

pipeline.buildCDFModule(app, 'Binding Lifetime Kinetics', ...
    {'All events', 'First event', 'Subsequent events'}, {'all', 'first', 'subsequent'}, 'all', ...
    'Lifetime (s)', @computeLifetimes);

end

function [rawTimes, molIDs] = computeLifetimes(app, chName, typeValue)
chIdx     = find(strcmp(app.Data.result.channelNames, chName), 1);
evListAll = app.Data.result.events{chIdx};
evList    = pipeline.filterEventsByType(evListAll, typeValue);

rawTimes = [evList.lifetime];
molIDs   = [evList.mol];
end
