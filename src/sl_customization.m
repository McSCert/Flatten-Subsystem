%% Register custom menu function to beginning of Simulink Editor's context menu
function sl_customization(cm)
    cm.addCustomMenuFcn('Simulink:PreContextMenu', @getMcMasterTool);
end

%% Define custom menu function
function schemaFcns = getMcMasterTool(callbackInfo) 
    if strcmp(get_param(gcb, 'Selected'), 'on') && ...
            strcmp(get_param(gcb, 'BlockType'), 'SubSystem')
        schemaFcns = {@getFlattenSubsystem};
    end
end

%% Define the first action: Flatten Subsystem
function schema = getFlattenSubsystem(callbackInfo)
    schema = sl_action_schema;
    schema.label = 'Flatten Subsystem';
    schema.userdata = 'flattenSubsystem';
    schema.callback = @FlattenSubsystemCallback;
end

function FlattenSubsystemCallback(callbackInfo)
    FlattenSubsystem(gcs, gcbs);
end