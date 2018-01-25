function FlattenSubsystem(address, subToFlatten)
% FLATTENSUBSYSTEM Take all blocks in a subsystem and place them in the
%   current system.
%
%   Inputs:
%       address         Simulink system path.
%       subToFlatten    Cell array of subsystems to be flattened.

    for blk = 1:length(subToFlatten)
        if ~strcmp(get_param(subToFlatten{blk}, 'BlockType'), 'SubSystem')
            disp(['Error using ' mfilename ':' char(10) ...
                ' One or more blocks selected are not a subsystem.' char(10)])
            return
        end

        allBlocksSub = find_system(subToFlatten{blk}, 'SearchDepth', 1);
        allBlocksSub = setdiff(allBlocksSub, subToFlatten{blk});
        subConnections = get_param(subToFlatten{blk}, 'PortConnectivity');

        subSourceBlocks = [];
        subSourcePorts  = [];
        subDestBlocks   = [];
        subDestPorts    = [];
        blocksMap = containers.Map();
        connectedMap = containers.Map();

        for k = 1:length(subConnections)
            if ~isempty(subConnections(k).SrcBlock)
                subSourceBlocks(end + 1) = subConnections(k).SrcBlock;
                subSourcePorts(end + 1) = subConnections(k).SrcPort;
            elseif ~isempty(subConnections(k).DstBlock)
                subDestBlocks(end + 1) = subConnections(k).DstBlock;
                subDestPorts(end + 1) = subConnections(k).DstPort;
            end
        end

        subPorts = get_param(subToFlatten{blk}, 'PortHandles');
        subInPorts = subPorts.Inport;
        subOutPorts = subPorts.Outport;

        % Delete Subsystem Inport lines
        for i = 1:length(subSourcePorts)
            portToUse = get_param(subSourceBlocks(i), 'PortHandles');
            numInports = length(portToUse.Inport);
            portToUse = portToUse.Outport(1 + subSourcePorts(i));
            delete_line(address, portToUse, subInPorts(i))
        end

        % Delete Subsystem Outport line
        for i = 1:length(subDestPorts)
            portToUse = get_param(subDestBlocks(i), 'PortHandles');
            portToUse = portToUse.Inport(1 + subDestPorts(i));
            delete_line(address, subOutPorts(i), portToUse)
        end

        % Copy the blocks in the Subsystem into the current system. Don't
        % worry about Inports and Outpots, because they need to be deleted
        for x = 1:length(allBlocksSub)
            blockType = get_param(allBlocksSub{x}, 'BlockType');
            if ~strcmp(blockType, 'Inport') && ~strcmp(blockType, 'Outport')
                blockName = get_param(allBlocksSub{x}, 'Name');
                subName = get_param(subToFlatten{blk}, 'Name');
                copiedBlockName = [address '/' blockName '_' subName];
                newblock = add_block(allBlocksSub{x}, copiedBlockName);
                blocksMap(allBlocksSub{x}) = newblock;
            end
        end

        for x = 1:length(allBlocksSub)
            blockType = get_param(allBlocksSub{x}, 'BlockType');
            if ~strcmp(blockType, 'Inport') && ~strcmp(blockType, 'Outport')
                newblock = blocksMap(allBlocksSub{x});
                connections = get_param(allBlocksSub{x}, 'PortConnectivity');
                ports = get_param(newblock, 'PortHandles');
                inPorts = ports.Inport;
                outPorts = ports.Outport;
                triggerPorts = ports.Trigger;
                ifactionPorts = ports.Ifaction;
                enablePorts = ports.Enable;

                z = 1;
                for y = 1:length(connections)
                    if ~isempty(connections(y).SrcBlock) && any(connections(y).SrcBlock ~= -1)
                        if strcmp(get_param(connections(y).SrcBlock, 'BlockType'), 'Inport')
                            portnum = get_param(connections(y).SrcBlock, 'Port');
                            portnum = str2num(portnum);
                            portToUse = get_param(subSourceBlocks(portnum), 'PortHandles');
                            numInports = length(portToUse.Inport);
                            portToUse = portToUse.Outport(1 + subSourcePorts(portnum));
                            portKey = num2str(inPorts(z));
                            if ~isKey(connectedMap, portKey) || (connectedMap(portKey) ~= portToUse)
                                add_line(address, portToUse, inPorts(z))
                                connectedMap(portKey) = portToUse;
                            end
                        else
                            blockToUse = blocksMap(getfullname(connections(y).SrcBlock));
                            portToUse = get_param(blockToUse, 'PortHandles');
                            numInports = length(portToUse.Inport);
                            portToUse = portToUse.Outport(1 + connections(y).SrcPort);
                            if (z > length(inPorts))
                                if ~isempty(triggerPorts)
                                    portKey = num2str(triggerPorts(1));
                                    if ~isKey(connectedMap, portKey) || (connectedMap(portKey) ~= portToUse)
                                        add_line(address, portToUse, triggerPorts(1))
                                        connectedMap(portKey) = portToUse;
                                    end
                                elseif ~isempty(ifactionPorts)
                                    portKey = num2str(ifactionPorts(1));
                                    if ~isKey(connectedMap, portKey) || (connectedMap(portKey) ~= portToUse)
                                        add_line(address, portToUse, ifactionPorts(1))
                                        connectedMap(portKey) = portToUse;
                                    end
                                else
                                    portKey = num2str(enablePorts(1));
                                    if ~isKey(connectedMap, portKey) || (connectedMap(portKey) ~= portToUse)
                                        add_line(address, portToUse, enablePorts(1))
                                        connectedMap(portKey) = portToUse;
                                    end
                                end
                            else
                                portKey = num2str(inPorts(z));
                                if ~isKey(connectedMap, portKey) || (connectedMap(portKey) ~= portToUse)
                                    add_line(address, portToUse, inPorts(z))
                                    connectedMap(portKey) = portToUse;
                                end
                            end

                        end
                        z = z + 1;
                    end
                end

                z = 1;
                for y = 1:length(connections)
                    if ~isempty(connections(y).DstBlock) && any(connections(y).DstBlock ~= -1)
                        destinations = connections(y).DstBlock;
                        destinationsPorts = connections(y).DstPort;

                        for w = 1:length(destinations)
                            if strcmp(get_param(destinations(w), 'BlockType'), 'Outport')
                                portnum = get_param(destinations(w), 'Port');
                                portnum = str2num(portnum);
                                portToUse = get_param(subDestBlocks(portnum), 'PortHandles');
                                portToUse = portToUse.Inport(1 + subDestPorts(portnum));
                                portKey = num2str(portToUse);
                                if ~isKey(connectedMap, portKey) || (connectedMap(portKey) ~= outPorts(z))
                                    add_line(address, outPorts(z), portToUse)
                                    connectedMap(portKey) = outPorts(z);
                                end
                            else
                                blockToUse = blocksMap(getfullname(destinations(w)));
                                portToUse = get_param(blockToUse, 'PortHandles');
                                if (destinationsPorts(w) > length(portToUse.Inport) - 1)
                                    if ~isempty(portToUse.Ifaction)
                                        portToUse = portToUse.Ifaction(1 + destinationsPorts(w));
                                    elseif ~isempty(portToUse.Trigger)
                                        portToUse = portToUse.Trigger(1 + destinationsPorts(w));
                                    else
                                        portToUse = portToUse.Enable(1 + destinationsPorts(w));
                                    end
                                else
                                    portToUse = portToUse.Inport(1 + destinationsPorts(w));
                                end
                                portKey = num2str(portToUse);
                                if ~isKey(connectedMap, portKey) || (connectedMap(portKey) ~= outPorts(z))
                                    add_line(address, outPorts(z), portToUse)
                                    connectedMap(portKey) = outPorts(z);
                                end
                            end
                        end
                        z = z + 1;
                    end
                end
            end
        end
        % Delete the original Subsystem
        delete_block(subToFlatten{blk});
    end

    % Automatically fix the model layout
    AutoLayout(address);
end