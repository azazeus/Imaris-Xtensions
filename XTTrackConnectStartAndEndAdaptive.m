%
%
%  Connect Tracks Function for Imaris 7.3.0
%
%  Copyright Bitplane AG 2011
%  Modified by Amar Bhagwat
%
%
%  Installation:
%
%  - Copy this file into the XTensions folder in the Imaris installation directory.
%  - You will find this function in the Image Processing menu
%
%    <CustomTools>
%      <Menu>
%       <Submenu name="Tracks Functions">
%        <Item name="Adaptively connect Tracks on both ends" icon="Matlab" tooltip="Build bifurcated tracks.">
%          <Command>MatlabXT::XTTrackConnectStartAndEndAdaptive(%i)</Command>
%        </Item>
%       </Submenu>
%      </Menu>
%      <SurpassTab>
%        <SurpassComponent name="bpSpots">
%          <Item name="Adaptively connect Tracks on both ends">
%            <Command>MatlabXT::XTTrackConnectStartAndEndAdaptive(%i)</Command>
%          </Item>
%        </SurpassComponent>
%        <SurpassComponent name="bpSurfaces">
%          <Item name="Adaptively connect Tracks on both ends">
%            <Command>MatlabXT::XTTrackConnectStartAndEndAdaptive(%i)</Command>
%          </Item>
%        </SurpassComponent>
%      </SurpassTab>
%    </CustomTools>
% 
%
%  Description:
%   
%   Build bifurcated tracks, connecting tracks start points to other
%   track points. Also build merging tracks to connect tracks ending 
%   in other tracks
%   Assumes linear motion of the objects to find best matches. 
%   
%   
%

function XTTrackConnectStartAndEnd(aImarisApplicationID)

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

% the user has to create a scene with some surpass components
vSurpassScene = vImarisApplication.GetSurpassScene;
if isequal(vSurpassScene, [])
  msgbox('Please create some tracks in the surpass scene!');
  return
end

% get the selected object (spots or surfaces)
% read coordinates, time points and number of objects
vFactory = vImarisApplication.GetFactory;
vObjects = vImarisApplication.GetSurpassSelection;
if vFactory.IsSpots(vObjects)
  vObjects = vFactory.ToSpots(vObjects);
  vCoords = vObjects.GetPositionsXYZ;
  vTimes = vObjects.GetIndicesT + 1;
  vRadius = vObjects.GetRadiiXYZ;
  vTrackIDs = vObjects.GetTrackIds;
  vNumberOfObjects = numel(vTimes);
  vScene = vObjects.GetParent;
elseif vFactory.IsSurfaces(vObjects)
  vObjects = vFactory.ToSurfaces(vObjects);
  vNumberOfObjects = vObjects.GetNumberOfSurfaces;
  vCoords = zeros(vNumberOfObjects, 3);
  vTimes = ones(vNumberOfObjects, 1);
  for vIndex = 1:vNumberOfObjects
    vCoords(vIndex, :) = vObjects.GetCenterOfMass(vIndex - 1);
    vTimes(vIndex) = vObjects.GetTimeIndex(vIndex - 1) + 1;
  end
else
  msgbox('Please select some spots or surfaces!')
  return
end

vTimeEnd=max(vTimes);
vMaxHistoryNum=3;
% get the edges
vEdges = vObjects.GetTrackEdges + 1; % indices start from 1 here (matlab)
if isempty(vEdges)  
  msgbox('Please select some tracks!')
  return
end
vNumberOfEdges = size(vEdges, 1);
disp(['vCoord: ', num2str(vCoords(5,:))])
vAnswer = inputdlg('Please enter the maximal distance in um (diffraction limit is a good estimate):', '', 1, {'0.3'});
if isempty(vAnswer), return, end
vMaxDistanceSquared = str2double(char(vAnswer))^2;

vBranchPoints = false(numel(vTimes), 1);
vMergePoints = false(numel(vTimes), 1);

%%%%%%%%%%%%%%%%%% Starting points %%%%%%%%%%%%
% expected position of the branching point in case of linear motion
% vExpectedCoordsBk = vCoords;
vTrkSlopesBk = nan(numel(vCoords(:,1)),3);

% get the beginning tracks
vIsBeginning = false(vNumberOfObjects, 1);
vAlreadyFound = false(vNumberOfObjects, 1);
for vIndex = 1:vNumberOfEdges
  
	% test left object
	vObject = vEdges(vIndex, 1);
	vOther = vEdges(vIndex, 2);
	% must be in the list only one time
	% its neighbor must have greater time point
	% must not be at first time point
	if vAlreadyFound(vObject)
		vIsBeginning(vObject) = false;
	elseif vTimes(vOther) > vTimes(vObject) && vTimes(vObject) ~= 1
		vIsBeginning(vObject) = true;
	end
	vAlreadyFound(vObject) = true;

	% test right object (just invert vObject and vOther)
	vObject = vEdges(vIndex, 2);
	vOther = vEdges(vIndex, 1);

	if vAlreadyFound(vObject)
		vIsBeginning(vObject) = false;
	elseif vTimes(vOther) > vTimes(vObject) && vTimes(vObject) ~= 1
		vIsBeginning(vObject) = true;
	end
	vAlreadyFound(vObject) = true;
  
end
vBeginningPoints = find(vIsBeginning);

for vIndex = 1:vNumberOfEdges
	vObject = vEdges(vIndex, 1);
	if  vIsBeginning(vObject) == true
		vTrackid = vTrackIDs(vIndex);
		vThisTrkObjs = vEdges(find(vTrackIDs == vTrackid),1);
		vThisTrkTimes=vTimes(vThisTrkObjs);
		%disp(['length of track ',num2str(length(vThisTrkObjs))])
		%disp(['times involved ',num2str(vThisTrkTimes')])
		vTime = vTimes(vObject);
		
		if length(vThisTrkObjs) > vMaxHistoryNum-1
			vCoordBegin=zeros(vMaxHistoryNum,3);
		else
			vCoordBegin=zeros(numel(vThisTrkObjs),3);
		end
		vCoordBegin(1,:)=vCoords(vObject,:);
		
		% find next 4 if possible
		if (vMaxHistoryNum> 1 )&& (length(vThisTrkObjs) > vMaxHistoryNum-1)
			vObj2=vThisTrkObjs(find(vThisTrkTimes == (vTime+1))); % obj 2
			if length(vCoords(vObj2,:))>0
				vCoordBegin(2,:)=vCoords(vObj2(1),:);
			end
		end
		if(vMaxHistoryNum > 2)&& (length(vThisTrkObjs) > vMaxHistoryNum-1)
			vObj3=vThisTrkObjs(find(vThisTrkTimes == (vTime+2))); % obj 3
			if length(vCoords(vObj3,:))>0
				vCoordBegin(3,:)=vCoords(vObj3(1),:);
			end
		end
		if (vMaxHistoryNum > 3)&& (length(vThisTrkObjs) > vMaxHistoryNum-1)
			vObj4=vThisTrkObjs(find(vThisTrkTimes == (vTime+3))); % obj 4
			if length(vCoords(vObj4,:))>0
				vCoordBegin(4,:)=vCoords(vObj4(1),:);
			end
		end
		if (vMaxHistoryNum > 4)&& (length(vThisTrkObjs) > vMaxHistoryNum-1)
			vObj5=vThisTrkObjs(find(vThisTrkTimes == (vTime+4))); % obj 5
			if length(vCoords(vObj5,:))>0
				%disp(['coords 5: ',num2str(transpose(vCoords(vObj5)))])
				vCoordBegin(5,:)=vCoords(vObj5(1),:);
			end
		end

		vBegCOM=mean(vCoordBegin,1);
		vCoordCOM = vCoordBegin-vBegCOM;

		[~,~,vTrkDir]=svd(vCoordCOM,0); 
		vTrkSlopesBk(vObject,:)=vTrkDir(:,1);% this is the direction of motion of the track
	end
	
	vObject = vEdges(vIndex, 2);
	if  vIsBeginning(vObject) == true
		vTrackid = vTrackIDs(vIndex);
		vThisTrkObjs = vEdges(find(vTrackIDs == vTrackid),1);
		vThisTrkTimes=vTimes(vThisTrkObjs);
		
		vTime = vTimes(vObject);
		
		if numel(vThisTrkObjs) > vMaxHistoryNum-1
			vCoordBegin=zeros( vMaxHistoryNum,3);
		else
			vCoordBegin=zeros(numel(vThisTrkObjs),3);
		end
		vCoordBegin(1,:)=vCoords(vObject,:);
		
		% find next 4 if possible
		if (vMaxHistoryNum > 1)&& (length(vThisTrkObjs) > vMaxHistoryNum-1)
			vObj2=vThisTrkObjs(find(vThisTrkTimes == (vTime+1))); % obj 2
			if length(vCoords(vObj2,:))>0
				vCoordBegin(2,:)=vCoords(vObj2(1),:);
			end
		end
		if (vMaxHistoryNum > 2)&& (length(vThisTrkObjs) > vMaxHistoryNum-1)
			vObj3=vThisTrkObjs(find(vThisTrkTimes == (vTime+2))); % obj 3
			if length(vCoords(vObj3,:))>0
				vCoordBegin(3,:)=vCoords(vObj3(1),:);
			end
		end
		if (vMaxHistoryNum > 3)&& (length(vThisTrkObjs) > vMaxHistoryNum-1)
			vObj4=vThisTrkObjs(find(vThisTrkTimes == (vTime+3))); % obj 4
			if length(vCoords(vObj4,:))>0
				vCoordBegin(4,:)=vCoords(vObj4(1),:);
			end
		end
		if (vMaxHistoryNum > 4)&& (length(vThisTrkObjs) > vMaxHistoryNum-1)
			vObj5=vThisTrkObjs(find(vThisTrkTimes == (vTime+4))); % obj 5
			if length(vCoords(vObj5,:))>0
				vCoordBegin(5,:)=vCoords(vObj5(1),:);
			end
		end

		vBegCOM=mean(vCoordBegin,1);
		vCoordCOM = vCoordBegin-vBegCOM;

		[~,~,vTrkDir]=svd(vCoordCOM,0); 
		vTrkSlopesBk(vObject,:)=vTrkDir(:,1);% this is the direction of motion of the track
	end
end

jump = [0.2,0.4,0.6,0.8];
% find best candidate as previous of beginning points
vNumberOfBeginningPoints = numel(vBeginningPoints);
vAdditionalEdges = zeros(vNumberOfBeginningPoints, 2);
vBeginningPointHasMatch = false(vNumberOfBeginningPoints, 1);

for vIndex = 1:vNumberOfBeginningPoints
	vObject = vBeginningPoints(vIndex);
	
	
	
	%vObjectCoords = vExpectedCoordsBk(vObject, :);
	vObjectTime = vTimes(vObject);
	jidx = 1;
	% possible matches are all the points at vObjectTime - 1
	vOthers = find(vTimes == (vObjectTime - 1));
	while (vBeginningPointHasMatch(vIndex) == false) && (jidx < 5)
		vObjectCoords = vCoords(vObject,:) - jump(jidx)*vTrkSlopesBk(vObject,:);
		if ~isempty(vOthers)
			vBestIndex = vOthers(1);
			vBestDistanceSquared = sum((vObjectCoords - vCoords(vBestIndex, :)).^2);
			for vOtherIndex = 2:numel(vOthers)
				 vOther = vOthers(vOtherIndex);
				 vDistanceSquared = sum((vObjectCoords - vCoords(vOther, :)).^2);
				 if vDistanceSquared < vBestDistanceSquared
					vBestIndex = vOther;
					vBestDistanceSquared = vDistanceSquared;
				 end
			end
			if (vBestDistanceSquared < vMaxDistanceSquared) 
				 vAdditionalEdges(vIndex, :) = [vObject, vBestIndex];
				 vBranchPoints(vBestIndex) = true;
				 vBeginningPointHasMatch(vIndex) = true;
			end
			jidx = jidx + 1;
	  end
	end
end

% discard invalid pairs
vAdditionalBeginEdges = vAdditionalEdges(vBeginningPointHasMatch, :);

% modify imaris component
%vObjects.SetTrackEdges([vEdges; vAdditionalBeginEdges] - 1);

%%%%%%%%%%%%%%% End points %%%%%%%%%%%%%%%%%

% expected position of the merging point in case of linear motion
%vExpectedCoordsFw = vCoords;
vTrkSlopesFw = nan(numel(vCoords(:,1)),3);
% get the ending tracks
vIsEnding = false(vNumberOfObjects, 1);
vAlreadyFound = false(vNumberOfObjects, 1);

for vIndex = 1:vNumberOfEdges
	% test left object
	vObject = vEdges(vIndex, 1);
	vOther = vEdges(vIndex, 2);
	% must be in the list only one time
	% its neighbor must have greater time point
	% must not be at first time point
	if vAlreadyFound(vObject)
		vIsEnding(vObject) = false;
	elseif vTimes(vOther) < vTimes(vObject) && vTimes(vObject) ~= vTimeEnd
		vIsEnding(vObject) = true;
	end
	vAlreadyFound(vObject) = true;

	% test right object (just invert vObject and vOther)
	vObject = vEdges(vIndex, 2);
	vOther = vEdges(vIndex, 1);
	if vAlreadyFound(vObject)
		vIsEnding(vObject) = false;
	elseif vTimes(vOther) < vTimes(vObject) && vTimes(vObject) ~= vTimeEnd
		vIsEnding(vObject) = true;
	end
	vAlreadyFound(vObject) = true;
end

vEndingPoints = find(vIsEnding);

for vIndex = 1:vNumberOfEdges
	vObject = vEdges(vIndex, 1);
	if  vIsEnding(vObject) == true
		vTrackid = vTrackIDs(vIndex);
		vThisTrkObjs = vEdges(find(vTrackIDs == vTrackid),1);
		vThisTrkTimes=vTimes(vThisTrkObjs);
		vTime = vTimes(vObject);
		if numel(vThisTrkObjs) > vMaxHistoryNum-1
			vCoordEnd=zeros(vMaxHistoryNum,3);
		else
			vCoordEnd=zeros(numel(vThisTrkObjs),3);
		end
		vCoordEnd(1,:)=vCoords(vObject,:);
		% find next 4 if possible
		if (vMaxHistoryNum > 1)&& (length(vThisTrkObjs) > vMaxHistoryNum-1)
			vObj2=vThisTrkObjs(find(vThisTrkTimes == (vTime-1))); % obj 2
			if length(vCoords(vObj2,:))>0
				vCoordBegin(2,:)=vCoords(vObj2(1),:);
			end
		end
		if (vMaxHistoryNum> 2)&& (length(vThisTrkObjs) > vMaxHistoryNum-1)
			vObj3=vThisTrkObjs(find(vThisTrkTimes == (vTime-2))); % obj 3
			if length(vCoords(vObj3,:))>0
				vCoordBegin(3,:)=vCoords(vObj3(1),:);
			end
		end
		if (vMaxHistoryNum > 3)&& (length(vThisTrkObjs) > vMaxHistoryNum-1)
			vObj4=vThisTrkObjs(find(vThisTrkTimes == (vTime-3))); % obj 4
			if length(vCoords(vObj4,:))>0
				vCoordBegin(4,:)=vCoords(vObj4(1),:);
			end
		end
		if (vMaxHistoryNum > 4)&& (length(vThisTrkObjs) > vMaxHistoryNum-1)
			vObj5=vThisTrkObjs(find(vThisTrkTimes == (vTime-4))); % obj 5
			if length(vCoords(vObj5,:))>0
				vCoordBegin(5,:)=vCoords(vObj5(1),:);
			end
		end

		vEndCOM=mean(vCoordEnd,1);
		vCoordCOM = vCoordEnd-vEndCOM;

		[~,~,vTrkDir]=svd(vCoordCOM,0); 
		vTrkSlopesFw(vObject,:)=vTrkDir(:,1);% this is the direction of motion of the track
	end
	
	vObject = vEdges(vIndex, 2);
	if  vIsEnding(vObject) == true
		vTrackid = vTrackIDs(vIndex);
		vThisTrkObjs = vEdges(find(vTrackIDs == vTrackid),1);
		vThisTrkTimes=vTimes(vThisTrkObjs);
		vTime = vTimes(vObject);
		if numel(vThisTrkObjs) > vMaxHistoryNum-1
			vCoordEnd=zeros(vMaxHistoryNum,3);
		else
			vCoordEnd=zeros(numel(vThisTrkObjs),3);
		end
		vCoordEnd(1,:)=vCoords(vObject,:);
		% find next 4 if possible
		if (vMaxHistoryNum > 1)&& (length(vThisTrkObjs) > vMaxHistoryNum-1)
			vObj2=vThisTrkObjs(find(vThisTrkTimes == (vTime-1))); % obj 2
			if length(vCoords(vObj2,:))>0
				vCoordBegin(2,:)=vCoords(vObj2(1),:);
			end
		end
		if (vMaxHistoryNum > 2)&& (length(vThisTrkObjs) > vMaxHistoryNum-1)
			vObj3=vThisTrkObjs(find(vThisTrkTimes == (vTime-2))); % obj 3
			if length(vCoords(vObj3,:))>0
				vCoordBegin(3,:)=vCoords(vObj3(1),:);
			end
		end
		if (vMaxHistoryNum > 3)&& (length(vThisTrkObjs) > vMaxHistoryNum-1)
			vObj4=vThisTrkObjs(find(vThisTrkTimes == (vTime-3))); % obj 4
			if length(vCoords(vObj4,:))>0
				vCoordBegin(4,:)=vCoords(vObj4(1),:);
			end
		end
		if (vMaxHistoryNum > 4)&& (length(vThisTrkObjs) > vMaxHistoryNum-1)
			vObj5=vThisTrkObjs(find(vThisTrkTimes == (vTime-4))); % obj 5
			if length(vCoords(vObj5,:))>0
				vCoordBegin(5,:)=vCoords(vObj5(1),:);
			end
		end

		vEndCOM=mean(vCoordEnd,1);
		vCoordCOM = vCoordEnd-vEndCOM;

		[~,~,vTrkDir]=svd(vCoordCOM,0); 
		vTrkSlopesFw(vObject,:)=vTrkDir(:,1);% this is the direction of motion of the track
	end
end


% find best candidate as previous of beginning points
vNumberOfEndingPoints = numel(vEndingPoints);
vAdditionalEdges = zeros(vNumberOfEndingPoints, 2);
vEndingPointHasMatch = false(vNumberOfEndingPoints, 1);

for vIndex = 1:vNumberOfEndingPoints
	vObject = vEndingPoints(vIndex);
	%vObjectCoords = vExpectedCoordsBk(vObject, :);
	vObjectTime = vTimes(vObject);
	jidx = 1;
	% possible matches are all the points at vObjectTime - 1
	vOthers = find(vTimes == (vObjectTime + 1));
	while (vEndingPointHasMatch(vIndex) == false) && (jidx < 5)
		vObjectCoords = vCoords(vObject,:) - jump(jidx)*vTrkSlopesFw(vObject,:);
		if ~isempty(vOthers)
			vBestIndex = vOthers(1);
			vBestDistanceSquared = sum((vObjectCoords - vCoords(vBestIndex, :)).^2);
			for vOtherIndex = 2:numel(vOthers)
				 vOther = vOthers(vOtherIndex);
				 vDistanceSquared = sum((vObjectCoords - vCoords(vOther, :)).^2);
				 if vDistanceSquared < vBestDistanceSquared
					vBestIndex = vOther;
					vBestDistanceSquared = vDistanceSquared;
				 end
			end
			if (vBestDistanceSquared < vMaxDistanceSquared) 
				 vAdditionalEdges(vIndex, :) = [vObject, vBestIndex];
				 vMergePoints(vBestIndex) = true;
				 vEndingPointHasMatch(vIndex) = true;
			end
			jidx = jidx + 1;
	  end
	end
end

% discard invalid pairs
vAdditionalEndEdges = vAdditionalEdges(vEndingPointHasMatch, :);

% finally modify imaris component
%vObjects.SetTrackEdges([vEdges; vAdditionalEndEdges] - 1);
new_tracks=[vEdges; vAdditionalBeginEdges; vAdditionalEndEdges] - 1;
msgbox(num2str(size(new_tracks)));
% create new group
vSpotsGroup = vFactory.CreateDataContainer;
vSpotsGroup.SetName(sprintf('Branch/merge points [dist < %.2f]', ...
    str2double(char(vAnswer))));

vNewSpots1 = vFactory.CreateSpots;
vNewSpots1.Set(vCoords(vBranchPoints, :), vTimes(vBranchPoints)-1, zeros(sum(vBranchPoints),1));
vNewSpots1.SetRadiiXYZ(vRadius(vBranchPoints,:));
vNewSpots1.SetName([char(vObjects.GetName), ' split events']);
vRGBA = [0, 255, 0, 0];
vRGBA = uint32(vRGBA * [1; 256; 256*256; 256*256*256]);
vNewSpots1.SetColorRGBA(vRGBA);
vSpotsGroup.AddChild(vNewSpots1, -1);

vNewSpots2 = vFactory.CreateSpots;
vNewSpots2.Set(vCoords(vMergePoints, :), vTimes(vMergePoints)-1, zeros(sum(vMergePoints),1));
vNewSpots2.SetRadiiXYZ(vRadius(vMergePoints,:));
vNewSpots2.SetName([char(vObjects.GetName), ' merge events']);
vRGBA = [255, 0, 0, 0];
vRGBA = uint32(vRGBA * [1; 256; 256*256; 256*256*256]);
vNewSpots2.SetColorRGBA(vRGBA);
vSpotsGroup.AddChild(vNewSpots2, -1);

vNewSpots3 = vFactory.CreateSpots;
vNewSpots3.Set(vCoords, vTimes-1, zeros(numel(vTimes),1));
vNewSpots3.SetRadiiXYZ(vRadius);
vNewSpots3.SetName([char(vObjects.GetName), ' copy with dual connect']);
vNewSpots3.SetTrackEdges([vEdges; vAdditionalBeginEdges; vAdditionalEndEdges] - 1);
vRGBA = [0, 255, 0, 0];
vRGBA = uint32(vRGBA * [1; 256; 256*256; 256*256*256]);
vNewSpots3.SetColorRGBA(vRGBA);
vSpotsGroup.AddChild(vNewSpots3, -1);

vObjects.SetVisible(0);
%vSpots2.SetVisible(0);
vScene.AddChild(vSpotsGroup, -1);
%%%%%%%%%%%%%%%%% both ways  %%%%%%%%%%%%%%%%%%%%%%%%

% % % find best candidate as previous of beginning points
% % vNumberOfEndingPoints = numel(vEndingPoints);
% % vAdditionalEdges = zeros(vNumberOfEndingPoints, 2);
% % vEndingPointHasMatch = false(vNumberOfEndingPoints, 1);
% % for vIndex = 1:vNumberOfEndingPoints
  % % vObject = vEndingPoints(vIndex);
  % % vObjectCoords = vExpectedCoordsFw(vObject, :);
  % % vObjectTime = vTimes(vObject);
  
  % % % possible matches are all the points at vObjectTime + 1
  % % vOthers = find(vTimes == vObjectTime +1);
  % % if ~isempty(vOthers)
    % % vBestIndex = vOthers(1);
    % % vBestDistanceSquared = sum((vObjectCoords - vCoords(vBestIndex, :)).^2);
    % % for vOtherIndex = 2:numel(vOthers)
      % % vOther = vOthers(vOtherIndex);
      % % vDistanceSquared = sum((vObjectCoords - vCoords(vOther, :)).^2);
      % % if vDistanceSquared < vBestDistanceSquared
        % % vBestIndex = vOther;
        % % vBestDistanceSquared = vDistanceSquared;
      % % end
    % % end
    % % if (vBestDistanceSquared < vMaxDistanceSquared) 
      % % vAdditionalEdges(vIndex, :) = [vObject, vBestIndex];
      % % vEndingPointHasMatch(vIndex) = true;
    % % end
  % % end
% % end

% % % discard invalid pairs
% % vAdditionalEndEdges = vAdditionalEdges(vEndingPointHasMatch, :);

% % % finally modify imaris component
% % vObjects.SetTrackEdges([vEdges; vAdditionalEndEdges] - 1);