%
%
%  Colocalize Spot Function for Imaris 8.1.0
%
%  Copyright Bitplane 2015
%
%
%  Installation:
%
%  - Copy this file into the XTensions folder in the Imaris installation directory
%  - You will find this function in the Image Processing menu
%
%    <CustomTools>
%      <Menu>
%       <Submenu name="Spots Functions">
%        <Item name="Colocalize Spots" icon="Matlab">
%          <Command>MatlabXT::XTSpotsColocalize(%i)</Command>
%        </Item>
%       </Submenu>
%      </Menu>
%      <SurpassTab>
%        <SurpassComponent name="bpSpots">
%          <Item name="Colocalize Spots" icon="Matlab">
%            <Command>MatlabXT::XTSpotsColocalize(%i)</Command>
%          </Item>
%        </SurpassComponent>
%      </SurpassTab>
%    </CustomTools>
% 
%
%  Description:
%   
%   Find and copy spots of different objects that lies together. Also
%   identify those that are not colocalized
% 
%

function XTSpotsColocalize(aImarisApplicationID, aThreshold)

% connect to Imaris interface
if ~isa(aImarisApplicationID, 'Imaris.IApplicationPrxHelper')
  javaaddpath ImarisLib.jar
  vImarisLib = ImarisLib;
  if ischar(aImarisApplicationID)
    aImarisApplicationID = round(str2double(aImarisApplicationID));
  end
  vImarisApplication = vImarisLib.GetApplication(aImarisApplicationID);
else
  vImarisApplication = aImarisApplicationID;
end

% the user has to create a scene with some spots
vSurpassScene = vImarisApplication.GetSurpassScene;
if isequal(vSurpassScene, [])
    msgbox('Please create some Spots in the Surpass scene!');
    return;
end

% get the spots
vSpots = vImarisApplication.GetSurpassSelection;
vSpotsSelected = vImarisApplication.GetFactory.IsSpots(vSpots);

if vSpotsSelected
    vScene = vSpots.GetParent;
else
    vScene = vImarisApplication.GetSurpassScene;
end
vNumberOfSpots = 0;
vSpotsList{vScene.GetNumberOfChildren} = [];
vNamesList{vScene.GetNumberOfChildren} = [];
for vChildIndex = 1:vScene.GetNumberOfChildren
    vDataItem = vScene.GetChild(vChildIndex - 1);
    if vImarisApplication.GetFactory.IsSpots(vDataItem)
        vNumberOfSpots = vNumberOfSpots+1;
        vSpotsList{vNumberOfSpots} = vImarisApplication.GetFactory.ToSpots(vDataItem);
        vNamesList{vNumberOfSpots} = char(vDataItem.GetName);
    end
end

if vNumberOfSpots<2
    msgbox('Please create at least 2 spots objects!');
    return;
end

vNamesList = vNamesList(1:vNumberOfSpots);

vPair = [];
while length(vPair) ~= 2
    [vPair, vOk] = listdlg('ListString',vNamesList,'SelectionMode','multiple',...
        'ListSize',[250 150],'Name','Colocalize spots','InitialValue',[1,2], ...
        'PromptString',{'Please select the 2 spots to colocalize:'});
    if vOk<1, return, end
    if length(vPair) ~= 2
        vHandle = msgbox(['Please select two (2) objects. Use "Control" and left ', ...
            'click to select/unselect an object of the list.']);
        uiwait(vHandle);
    end
end

vSpots1 = vSpotsList{vPair(1)};
vSpots2 = vSpotsList{vPair(2)};

% ask for threshold
if nargin<2
    vQuestion = {sprintf(['Get the spots with distance <= threshold. \n', ...
        'Please enter the threshold value:'])};
    vAnswer = inputdlg(vQuestion,'Colocalize spots',1,{'1'});
    if isempty(vAnswer), return, end
    vThreshold = str2double(vAnswer{1});
else
    vThreshold = aThreshold;
end
vThresholdSquare = vThreshold.^2;

vProgressDisplay = waitbar(0,'Colocalizing spots');

vSpotsXYZ1 = vSpots1.GetPositionsXYZ;
vTime1 = vSpots1.GetIndicesT;
vRadius1 = vSpots1.GetRadiiXYZ;

vSpotsXYZ2 = vSpots2.GetPositionsXYZ;
vTime2 = vSpots2.GetIndicesT;
vRadius2 = vSpots2.GetRadiiXYZ;

% initialize coloc to zero
vColoc1 = false(numel(vTime1), 1);
vColoc2 = false(numel(vTime2), 1);

vTime1 = double(vTime1);
vTime2 = double(vTime2);

vStart = max([min(vTime1), min(vTime2)]);
vEnd = min([max(vTime1), max(vTime2)]);
for vTime = vStart:vEnd
    vValid1 = find(vTime1 == vTime);
    vValid2 = find(vTime2 == vTime);

    vXYZ = vSpotsXYZ2(vValid2, :);
    for vSpot1 = 1:numel(vValid1)
        vColocated1 = vValid1(vSpot1);
        
        vX = vXYZ(:, 1) - vSpotsXYZ1(vColocated1, 1);
        vY = vXYZ(:, 2) - vSpotsXYZ1(vColocated1, 2);
        vZ = vXYZ(:, 3) - vSpotsXYZ1(vColocated1, 3);
        vDistanceList = vX.^2 + vY.^2 + vZ.^2 <= vThresholdSquare;
        
        vColocated2 = vValid2(vDistanceList);
        if ~isempty(vColocated2)
            vColoc1(vColocated1) = true;
            vColoc2(vColocated2) = true;
        end
    end
    
    waitbar((vTime-vStart+1)/(vEnd-vStart+1), vProgressDisplay);
end

close(vProgressDisplay);

if isempty(find(vColoc1, 1))
    msgbox('There is no colocated spots.');
    return
end
vNonColoc1 = ~vColoc1;
vNonColoc2 = ~vColoc2;
% create new group
vSpotsGroup = vImarisApplication.GetFactory.CreateDataContainer;
vSpotsGroup.SetName(sprintf('Coloc[%.2f] %s | %s', ...
    vThreshold, char(vSpots1.GetName), char(vSpots2.GetName)));

vNewSpots1 = vImarisApplication.GetFactory.CreateSpots;
vNewSpots1.Set(vSpotsXYZ1(vColoc1, :), vTime1(vColoc1), zeros(sum(vColoc1),1));
vNewSpots1.SetRadiiXYZ(vRadius1(vColoc1,:));
vNewSpots1.SetName([char(vSpots1.GetName), ' colocated']);
vRGBA = vSpots1.GetColorRGBA;
vNewSpots1.SetColorRGBA(vRGBA);
vSpotsGroup.AddChild(vNewSpots1, -1);

vNewSpots1 = vImarisApplication.GetFactory.CreateSpots;
vNewSpots1.Set(vSpotsXYZ1(vNonColoc1, :), vTime1(vNonColoc1), zeros(sum(vNonColoc1),1));
vNewSpots1.SetRadiiXYZ(vRadius1(vNonColoc1,:));
vNewSpots1.SetName([char(vSpots1.GetName), ' non-colocated']);
vRGBA = vSpots1.GetColorRGBA;
vNewSpots1.SetColorRGBA(vRGBA);
vSpotsGroup.AddChild(vNewSpots1, -1);

vNewSpots2 = vImarisApplication.GetFactory.CreateSpots;
vNewSpots2.Set(vSpotsXYZ2(vColoc2, :), vTime2(vColoc2), zeros(sum(vColoc2),1));
vNewSpots2.SetRadiiXYZ(vRadius2(vColoc2,:));
vNewSpots2.SetName([char(vSpots2.GetName),' colocated']);
vRGBA = vSpots2.GetColorRGBA;
vNewSpots2.SetColorRGBA(vRGBA);
vSpotsGroup.AddChild(vNewSpots2, -1);

vNewSpots2 = vImarisApplication.GetFactory.CreateSpots;
vNewSpots2.Set(vSpotsXYZ2(vNonColoc2, :), vTime2(vNonColoc2), zeros(sum(vNonColoc2),1));
vNewSpots2.SetRadiiXYZ(vRadius2(vNonColoc2,:));
vNewSpots2.SetName([char(vSpots2.GetName), ' non-colocated']);
vRGBA = vSpots2.GetColorRGBA;
vNewSpots2.SetColorRGBA(vRGBA);
vSpotsGroup.AddChild(vNewSpots2, -1);

vSpots1.SetVisible(0);
vSpots2.SetVisible(0);
vScene.AddChild(vSpotsGroup, -1);


