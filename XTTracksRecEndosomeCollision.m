%
%
%  Colocalize Spot Function for Imaris 8.1.0
%
%  Copyright Bitplane 2015
%  Modified by Amar Bhagwat
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
%        <Item name="Find Recycling Endosome interaction nodes" icon="Matlab">
%          <Command>MatlabXT::XTTracksRecEndosomeCollision(%i)</Command>
%        </Item>
%       </Submenu>
%      </Menu>
%      <SurpassTab>
%        <SurpassComponent name="bpSpots">
%          <Item name="Find Recycling Endosome interaction nodes" icon="Matlab">
%            <Command>MatlabXT::XTTracksRecEndosomeCollision(%i)</Command>
%          </Item>
%        </SurpassComponent>
%      </SurpassTab>
%    </CustomTools>
% 
%
%  Description:
%   
%   Find instances of tracks splitting, merging or continuing.
%   This will tell you the locations at which recycling endosomes
%   underwent fission or fusion events
% 
%

function XTTracksRecEndosomeCollision(aImarisApplicationID, aThreshold)

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

% get the selected object - check if it is a spots object
vSpots = vImarisApplication.GetSurpassSelection;
vSpotsSelected = vImarisApplication.GetFactory.IsSpots(vSpots);

% get more details of the parent of the spots object
if vSpotsSelected
    vScene = vSpots.GetParent;
else
    vScene = vImarisApplication.GetSurpassScene;
end

% find all spots objects listed in the parent object
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

% check if no spots objects have been made in the current Imaris scene
if vNumberOfSpots<1
    msgbox('Please create at least 1 spot object!');
    return;
end

% get names of the spots objects available
vNamesList = vNamesList(1:vNumberOfSpots);

% get handle of the spot item that is to be used for analysis
vRESpots = [];
while length(vRESpots) ~= 1
    [vRESpots, vOk] = listdlg('ListString',vNamesList,'SelectionMode','multiple',...
        'ListSize',[250 150],'Name','Colocalize spots','InitialValue',[1], ...
        'PromptString',{'Please select the spots to analyze:'});
    if vOk<1, return, end
    if length(vRESpots) ~= 1
        vHandle = msgbox(['Please select only one object.  ', ...
            'click to select/unselect an object of the list.']);
        uiwait(vHandle);
    end
end

vSpots = vSpotsList{vRESpots(1)}; 
%%vSpots2 = vSpotsList{vRESpots(2)};

% look for distance threshold input
if nargin<2 % if not part of parameters passed in, then ask from the user
    vQuestion = {sprintf(['Get the spots with distance <= threshold. \n', ...
        'Please enter the threshold value:'])};
    vAnswer = inputdlg(vQuestion,'Colocalize spots',1,{'0.3'});
    if isempty(vAnswer), return, end
    vThreshold = str2double(vAnswer{1});
else % use from the parameters passed to this function
    vThreshold = aThreshold;
end

% square threshold distance
vThresholdSquare = vThreshold.^2;

vProgressDisplay = waitbar(0,'Colocalizing spots');

vSpotsXYZ1 = vSpots.GetPositionsXYZ;
vTime1 = vSpots.GetIndicesT+1;
vRadius1 = vSpots.GetRadiiXYZ;
vTrackE1 = vSpots.GetTrackEdges+1;
msgbox(['dimensions: [',num2str(size(vTrackE1)),' ]']);
%csvwrite('C:\\Users\\abhagwat\\Desktop\\trackedges.csv',vTrackE1);

vSpotsXYZ2 = vSpots.GetPositionsXYZ;
vTime2 = vSpots.GetIndicesT+1;
vRadius2 = vSpots.GetRadiiXYZ;

% initialize coloc to zero
vColoc1 = false(numel(vTime1), 1);
vColoc2 = false(numel(vTime1), 1);

% find track beginnings
vColoc2(vTrackE1(1,1)) =true;
for t = 2:size(vTrackE1(:,1))
 	if vTrackE1(t,1) ~= vTrackE1(t-1,2)
		vColoc2(vTrackE1(t,1)) =true;
	end
end
vTime1 = double(vTime1);
vTime2 = double(vTime1);

% find the extrema of the time index
vStart = min(vTime1);
vEnd = max(vTime1);
msgbox(['threshold :',num2str(vThresholdSquare)]);
%iterate over the time index
for vTime = vStart:vEnd-1
	% boolean vector for spots at the right time
    vValid1 = find(vTime1 == vTime); %present
    vValid2 = find(vTime2 == vTime+1);  %future
	
	% find spots from the future time point
    vXYZ2 = vSpotsXYZ2(vValid2, :); %future
	
	%iterate over each spot
    
	for vSpot1 = 1:numel(vValid1)
        
		vColocated1 = vValid1(vSpot1); % index of the present spot
		v1edge2 = vTrackE1 (find(vTrackE1 (:,1) == vColocated1),:);
        % msgbox(['spot index: ', num2str(vColocated1),' pairing : ',num2str(v1edge2)])
		% vectors of distances between all spots and the selected spot
        vX = vXYZ2(:, 1) - vSpotsXYZ1(vColocated1, 1);
        vY = vXYZ2(:, 2) - vSpotsXYZ1(vColocated1, 2);
        vZ = vXYZ2(:, 3) - vSpotsXYZ1(vColocated1, 3);
		
		% boolean vector of indices within vXYZ vector 
		% of all future spots within threshold distance from present spot
		vDistanceList = (vX.^2 + vY.^2 + vZ.^2 <= vThresholdSquare) ; %(vX.^2 + vY.^2 + vZ.^2 > 0) & 
        
        vColocated2 = vValid2(vDistanceList); % indices of all future spots colocated with present spot
		% check that current spot has a future spot on a track edge
		% if not it might be the end of a track
		if ~isempty(v1edge2)
			vNonPairColoc=vColocated2(vColocated2 ~= v1edge2(2));
		else
			vNonPairColoc=vColocated2;
		end
		try
			if ~isempty(vNonPairColoc) 
				%msgbox(['vColocated2 value:',num2str(vColocated2),'nonpaircoloc value:', num2str(vNonPairColoc),'pair value:', num2str(v1edge2(2))]);
				vColoc1(vColocated1) = true; % current spot is colocated
								
			end
		catch failcond
			msgbox(['fail on ', failcond.identifier, ' point index: ',num2str(v1edge2)]);
		end
	end  
    waitbar((vTime-vStart+1)/(vEnd-vStart+1), vProgressDisplay);
end

close(vProgressDisplay);

%vColoc1(vValid1) = true;
%vColoc2(vValid2) = true;
if isempty(find(vColoc1, 1))
    msgbox('There are no colocated spots.');
    return
end

%%vNonColoc1 = ~vColoc1;
%% vNonColoc2 = ~vColoc2;

% create new group
vSpotsGroup = vImarisApplication.GetFactory.CreateDataContainer;
vSpotsGroup.SetName(sprintf('Rec Endosome time event [dist < %.2f] %s | %s', ...
    vThreshold));

vNewSpots1 = vImarisApplication.GetFactory.CreateSpots;
vNewSpots1.Set(vSpotsXYZ1(vColoc1, :), vTime1(vColoc1)-1, zeros(sum(vColoc1),1));
vNewSpots1.SetRadiiXYZ(vRadius1(vColoc1,:));
vNewSpots1.SetName([char(vSpots.GetName), ' split/relay events']);
vRGBA = [0, 255, 0, 0];
vRGBA = uint32(vRGBA * [1; 256; 256*256; 256*256*256]);
vNewSpots1.SetColorRGBA(vRGBA);
vSpotsGroup.AddChild(vNewSpots1, -1);

% %vNewSpots1 = vImarisApplication.GetFactory.CreateSpots;
% %vNewSpots1.Set(vSpotsXYZ1(vNonColoc1, :), vTime1(vNonColoc1), zeros(sum(vNonColoc1),1));
% %vNewSpots1.SetRadiiXYZ(vRadius1(vNonColoc1,:));
% %vNewSpots1.SetName([char(vSpots1.GetName), ' non-colocated']);
% %vRGBA = vSpots1.GetColorRGBA;
% %vNewSpots1.SetColorRGBA(vRGBA);
% %vSpotsGroup.AddChild(vNewSpots1, -1);

vNewSpots2 = vImarisApplication.GetFactory.CreateSpots;
vNewSpots2.Set(vSpotsXYZ2(vColoc2, :), vTime2(vColoc2)-1, zeros(sum(vColoc2),1));
vNewSpots2.SetRadiiXYZ(vRadius2(vColoc2,:));
vNewSpots2.SetName([char(vSpots.GetName),' track beginning spot']);
vRGBA = [255, 0, 0, 0];
vRGBA = uint32(vRGBA * [1; 256; 256*256; 256*256*256]);
vNewSpots2.SetColorRGBA(vRGBA);
vSpotsGroup.AddChild(vNewSpots2, -1);

% % vNewSpots2 = vImarisApplication.GetFactory.CreateSpots;
% % vNewSpots2.Set(vSpotsXYZ2(vNonColoc2, :), vTime2(vNonColoc2), zeros(sum(vNonColoc2),1));
% % vNewSpots2.SetRadiiXYZ(vRadius2(vNonColoc2,:));
% % vNewSpots2.SetName([char(vSpots2.GetName), ' non-colocated']);
% % vRGBA = vSpots2.GetColorRGBA;
% % vNewSpots2.SetColorRGBA(vRGBA);
% % vSpotsGroup.AddChild(vNewSpots2, -1);

vSpots.SetVisible(0);
%vSpots2.SetVisible(0);
vScene.AddChild(vSpotsGroup, -1);


