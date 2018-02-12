%
%
%  Track Plot Angles Function for Imaris 7.3.0
%
%  Copyright Bitplane AG 2011
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
%        <Item name="Plot Angles of selected Track" icon="Matlab" tooltip="Plot the angles of the track.">
%          <Command>MatlabXT::XTTrackPlotAngles(%i)</Command>
%        </Item>
%       </Submenu>
%      </Menu>
%      <SurpassTab>
%        <SurpassComponent name="bpSpots">
%          <Item name="Plot Angles of selected Track" icon="Matlab" tooltip="Plot the angles of the track.">
%            <Command>MatlabXT::XTTrackPlotAngles(%i)</Command>
%          </Item>
%        </SurpassComponent>
%        <SurpassComponent name="bpSurfaces">
%          <Item name="Plot Angles of selected Track" icon="Matlab" tooltip="Plot the angles of the track.">
%            <Command>MatlabXT::XTTrackPlotAngles(%i)</Command>
%          </Item>
%        </SurpassComponent>
%      </SurpassTab>
%    </CustomTools>
% 
%
%  Description:
%   
%   Plot the angles of the track. 
%   
%

function XTTrackPlotAngles(aImarisApplicationID)

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

% the user has to create a scene with some tracks
vSurpassScene = vImarisApplication.GetSurpassScene;
if isequal(vSurpassScene, [])
  msgbox('Please create some tracks in the surpass scene!');
  return
end

% get the track
vObjectIndices = GetFirstSelectedTrack(vImarisApplication);
if isempty(vObjectIndices)  
  msgbox('Please select a track!');
  return
end

[vCoords, vTimes] = GetObjectsCoordsTimes( ...
  vImarisApplication, vObjectIndices);
vCoords = vCoords';

vNumberOfObjects = numel(vTimes);

% order eventual unordered data (e.g. vTimes == [1,5,2])
vTimeMin = min(vTimes);
vTimeMax = max(vTimes);

vObjectAtTime = zeros(1, vTimeMax - vTimeMin + 1);
vObjectAtTime(vTimes - vTimeMin + 1) = 1:vNumberOfObjects; % [1,3,0,0,2]
vObjectsIndex = vObjectAtTime(vObjectAtTime ~= 0); % [1,3,2]

% computes the track edges
vStepsSize = vCoords(:, vObjectsIndex(2:vNumberOfObjects)) - ...
  vCoords(:, vObjectsIndex(1:vNumberOfObjects-1));

% get the angle for each pair of contiguous edges
vAngles = zeros(4, vNumberOfObjects-2);
for vObject = 1:vNumberOfObjects-2
  vVector1 = vStepsSize(:, vObject);
  vVector2 = vStepsSize(:, vObject+1);

  vAngles(:, vObject) = [GetAngle(vVector1, vVector2); ...
    GetAngle(vVector1(1:2), vVector2(1:2)); ...
    GetAngle(vVector1([1,3]), vVector2([1,3])); ...
    GetAngle(vVector1(2:3), vVector2(2:3))];
end
    
% finally plot the results
vStrings = {'XYZ', 'XY', 'XZ', 'YZ'};
vName = char(vImarisApplication.GetSurpassSelection.GetName);
for vPlot = 1:4
  subplot(2,2,vPlot)
  plot(vTimes(2:vNumberOfObjects-1)+1, vAngles(vPlot, :)*180/pi, 'b-');
  title([vStrings{vPlot}, '-Angles of ', vName]);
  xlabel('Time');
  ylabel('Amplitude [degrees]');
  hold off
end


%---------------------------------------------------------%

function aAngle = GetAngle(aVector1, aVector2)
vNormProduct = norm(aVector1) * norm(aVector2);

if vNormProduct == 0
  aAngle = 0;
else
  aAngle = acos(dot(aVector1,aVector2)/vNormProduct);
end


%---------------------------------------------------------%

function aObjectIndices = GetFirstSelectedTrack(aImarisApplication)

% aTracks is the list of indices (starting from 0) of the objects
%   in the track, *not* a set of edges
aObjectIndices = [];

% get the selected object (spots or surfaces)
vFactory = aImarisApplication.GetFactory;
vObject = vFactory.ToSpots(aImarisApplication.GetSurpassSelection);
if ~isempty(vObject)
  vSize = numel(vObject.GetIndicesT);
else
  vObject = vFactory.ToSurfaces(aImarisApplication.GetSurpassSelection);
  if ~isempty(vObject)
    vSize = vObject.GetNumberOfSurfaces;
  else
    return
  end
end

% get the sub-selection and the traks
vSelection = vObject.GetSelectedIndices;
vEdges = vObject.GetTrackEdges';
if isempty(vSelection) || isempty(vEdges)
  return
end

% get the first selected spot which belongs to a of the track
vCurrent = [];
vIndex = 0;
while ~any(vCurrent) && vIndex < numel(vSelection)
  vIndex = vIndex + 1;
  vCurrent = any(vEdges == vSelection(vIndex));
end
if ~any(vCurrent(:))
  % no spots selected belongs to a track
  return
end

% get the spots of the track of the first selected object
vTrackBool = false(vSize, 1);
vTrackBool(vSelection(vIndex) + 1) = true;
while any(vCurrent)
  vObjects = vEdges([vCurrent; vCurrent]);
  vTrackBool(vObjects + 1) = true;
  vEdges([vCurrent; vCurrent]) = vSize;
  vCurrent = false(size(vCurrent));
  for vIndex = 1:numel(vObjects)
    vCurrent = vCurrent | any(vEdges == vObjects(vIndex));
  end
end
vIndices = 0:vSize-1;
aObjectIndices = vIndices(vTrackBool);


%---------------------------------------------------------%

function [aCoords, aTimes] = GetObjectsCoordsTimes( ...
  aImarisApplication, aSelectionIndices)

aCoords = [];
aTimes = [];

% get the selected object (spots or surfaces)
vFactory = aImarisApplication.GetFactory;
vSpots = vFactory.ToSpots(aImarisApplication.GetSurpassSelection);
vSurfaces = vFactory.ToSurfaces(aImarisApplication.GetSurpassSelection);

if ~isempty(vSpots)
  aCoords = vSpots.GetPositionsXYZ;
  aTimes = vSpots.GetIndicesT;
  vSize = numel(aTimes);
  % remove invalid selection indices
  aSelectionIndices = aSelectionIndices(aSelectionIndices < vSize) + 1;
  % perform selection
  aCoords = aCoords(aSelectionIndices, :);
  aTimes = aTimes(aSelectionIndices);
elseif ~isempty(vSurfaces)
  vSize = vSurfaces.GetNumberOfSurfaces;
  % remove invalid selection indices
  aSelectionIndices = aSelectionIndices(aSelectionIndices < vSize);
  vSize = numel(aSelectionIndices);
  aCoords = zeros(vSize, 3);
  aTimes = zeros(vSize, 1);
  % read selection
  for vIndex = 1:vSize
    vSurface = aSelectionIndices(vIndex);
    aCoords(vIndex, :) = vSurfaces.GetCenterOfMass(vSurface);
    aTimes(vIndex) = vSurfaces.GetTimeIndex(vSurface);
  end
end
