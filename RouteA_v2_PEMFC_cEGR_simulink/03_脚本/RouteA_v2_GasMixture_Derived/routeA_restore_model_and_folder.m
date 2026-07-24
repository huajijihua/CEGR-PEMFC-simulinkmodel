function routeA_restore_model_and_folder(model, modelFile, oldDir)
% Restore the on-disk Route A model after an audit changes logging state.
try
    if bdIsLoaded(model)
        close_system(model, 0);
    end
    load_system(modelFile);
    cd(oldDir);
catch ME
    warning('RouteA:AuditCleanupFailed', ...
        'Audit cleanup failed: %s', ME.message);
end
end
