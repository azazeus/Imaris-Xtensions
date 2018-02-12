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
%        <Item name="Find the distance from the spot to the coverslip" icon="Matlab">
%          <Command>MatlabXT::XTSpotsDistToCoverslip(%i)</Command>
%        </Item>
%       </Submenu>
%      </Menu>
%      <SurpassTab>
%        <SurpassComponent name="bpSpots">
%          <Item name="Find the distance from the spot to the coverslip" icon="Matlab">
%            <Command>MatlabXT::XTSpotsDistToCoverslip(%i)</Command>
%          </Item>
%        </SurpassComponent>
%      </SurpassTab>
%    </CustomTools>
% 
%
%	Description:
%   
%	Find the distance from the spot to the coverslip
%	The point is to find the vertical distribution as a function of nocodazole
%	treatment or infection.
% 
%

function XTSpotsDistToCoverslip(aImarisApplicationID, aThreshold)

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
vFileName = vImarisApplication.GetCurrentFileName;
%msgbox(char(vFileName));
% the user has to create a scene with some spots
vSurpassScene = vImarisApplication.GetSurpassScene;
if isequal(vSurpassScene, [])
    msgbox('Please create some Spots in the Surpass scene!');
    return;
end

% get the selected object - check if it is a spots object
vSpots = vImarisApplication.GetSurpassSelection;
vSpotsSelected = vImarisApplication.GetFactory.IsSpots(vSpots);
vDataSet = vImarisApplication.GetDataSet;
% get more details of the parent of the spots object
if vSpotsSelected
    vScene = vSpots.GetParent;
else
    vScene = vImarisApplication.GetSurpassScene;
end

% dataset dimensions
vExtMin = [vDataSet.GetExtendMinX, vDataSet.GetExtendMinY, vDataSet.GetExtendMinZ];
vExtMax = [vDataSet.GetExtendMaxX, vDataSet.GetExtendMaxY, vDataSet.GetExtendMaxZ];
vSize = [vDataSet.GetSizeX, vDataSet.GetSizeY, vDataSet.GetSizeZ];
vVoxelSize = (vExtMax - vExtMin) ./ vSize;

msgbox(['dataset size: ', num2str(vVoxelSize)]);

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

%%%%%%%%%%%%%%%%%%%%
% find all spots objects listed in the parent object
vNumberOfPlanes = 0;
vPlanesList{vScene.GetNumberOfChildren} = [];
vNamesList{vScene.GetNumberOfChildren} = [];
for vChildIndex = 1:vScene.GetNumberOfChildren
    vDataItem = vScene.GetChild(vChildIndex - 1);
    if vImarisApplication.GetFactory.IsClippingPlane(vDataItem)
        vNumberOfPlanes = vNumberOfPlanes+1;
        vPlanesList{vNumberOfPlanes} = vImarisApplication.GetFactory.ToClippingPlane(vDataItem);
        vNamesList{vNumberOfPlanes} = char(vDataItem.GetName);
    end
end

% check if no spots objects have been made in the current Imaris scene
if vNumberOfPlanes<1
    msgbox('Please create at least 1 clipping plane!');
    return;
end

% get names of the spots objects available
vNamesList = vNamesList(1:vNumberOfPlanes);

% get handle of the spot item that is to be used for analysis
vPlaneSel = [];
while length(vPlaneSel) ~= 1
    [vPlaneSel, vOk] = listdlg('ListString',vNamesList,'SelectionMode','multiple',...
        'ListSize',[250 150],'Name','Select clipping plane','InitialValue',[1], ...
        'PromptString',{'Please select the plane to analyze:'});
    if vOk<1, return, end
    if length(vPlaneSel) ~= 1
        vHandle = msgbox(['Please select only one object.  ', ...
            'click to select/unselect an object of the list.']);
        uiwait(vHandle);
    end
end

vPlane = vPlanesList{vPlaneSel (1)}; 
%%vSpots2 = vSpotsList{vRESpots(2)};

%vProgressDisplay = waitbar(0,'Colocalizing spots');

vPlaneXYZ = vPlane.GetPosition;
vClippingPlaneValues=vPlane.GetOrientationAxisAngle;
vAxis = vClippingPlaneValues.mAxisXYZ;
vAngle = vClippingPlaneValues.mAngle;
vQuaternion=vPlane.GetOrientationQuaternion;
message = sprintf(['Plane position: [',num2str(vPlaneXYZ'),' ] \n', ...
	'Axis: [', num2str(vAxis'),' ] \n',... 
	'Angle: [', num2str(vAngle) ,' ] \n',...
	'Quaternion: [', num2str(vQuaternion'),']' ]);
msgbox(message);
rotquat = [vQuaternion(1) vQuaternion(4) vQuaternion(3) vQuaternion(2)]/norm(vQuaternion);
clip_pointing4 = quatmultiply(quatconj(rotquat), quatmultiply([0 0 0 1],rotquat));
clip_pointing = [clip_pointing4(2) clip_pointing4(3) clip_pointing4(4)];
msgbox(['Clipping plane quaternion is: ',num2str(clip_pointing4)]);
%d = vPlaneXYZ(1)-vPlaneXYZ(3);

%%%%%%%%%%%%%%%%%%%%

vProgressDisplay = waitbar(0,'Measuring distance to coverslip');

vSpotsXYZ1 = vSpots.GetPositionsXYZ;
vTime1 = vSpots.GetIndicesT+1;
vRadius1 = vSpots.GetRadiiXYZ;
vTrackE1 = vSpots.GetTrackEdges+1;

%msgbox(['dimensions: [',num2str(size(vTrackE1)),' ]']);
%csvwrite('C:\\Users\\abhagwat\\Desktop\\trackedges.csv',vTrackE1);

% initialize coloc to zero
vDistSpot = zeros(numel(vTime1), 1);
vSpotCoordXYZ  = zeros(numel(vTime1), 3);
vIntSpot  = zeros(numel(vTime1), 1);
%vColoc2 = false(numel(vTime1), 1);

vTime1 = double(vTime1);
%vTime2 = double(vTime1);

% find the extrema of the time index
vStart = min(vTime1);
vEnd = max(vTime1);

dset_type = vDataSet.GetType();
if strcmp(dset_type,'eTypeFloat')
	msgbox(['plane position: ', num2str(vPlaneXYZ'), 'and the data is afloat!']);
end
msgbox(['data type: ', char(vDataSet.GetType)]);

%iterate over the time index
for vTime = vStart:vEnd
	% boolean vector for spots at the right time
    vValid1 = find(vTime1 == vTime); %present
    % vValid2 = find(vTime2 == vTime+1);  %future

	%iterate over each spot
    
	for vSpot1 = 1:numel(vValid1)
		vColocated1 = vValid1(vSpot1); % index of the present spot
		vSpotCoordXYZ=int32(floor((vSpotsXYZ1(vColocated1, :)-vExtMin)./vVoxelSize));
		vCPcenter = vPlaneXYZ'-vExtMin;
		try
			if strcmp(dset_type,'eTypeFloat')
				tempx = max(vSpotCoordXYZ(1),0);
				tempy = max(vSpotCoordXYZ(2),0);
				tempz = max(vSpotCoordXYZ(3),0);
				tempInt = vDataSet.GetDataSubVolumeFloats(tempx, tempy,tempz, int32(0), int32(vTime-1), int32(1), int32(1), int32(1)) ;
			elseif strcmp(dset_type,'eTypeUInt16')
				tempInt = vDataSet.GetDataSubVolumeShorts(vSpotCoordXYZ(1), vSpotCoordXYZ(2), vSpotCoordXYZ(3), int32(0), int32(vTime-1), int32(1), int32(1), int32(1)) ;
			end
		catch
			tempint=zeros(1,1,1);
			msgbox('found zero');
		end
		vIntSpot (vColocated1) = mean(mean(mean(tempInt)));
		%msgbox(['dims of center:',num2str(size((vPlaneXYZ))),' and ext minima: ', num2str(size(vExtMin))]);
		vDistSpot(vColocated1) = dot((vSpotsXYZ1(vColocated1,:) - vCPcenter),clip_pointing)/norm(clip_pointing);%(1/sqrt(2))*(-vSpotsXYZ1(vColocated1, 1)+vSpotsXYZ1(vColocated1, 3)+d);
	end 
    waitbar((vTime-vStart+1)/(vEnd-vStart+1), vProgressDisplay);

end
close(vProgressDisplay);

figure;
edges=[-2:0.1:15];
histogram(vDistSpot,edges,'Normalization','probability');
xlabel('distance from coverslip (um)');
ylabel('number of spots');
S=strrep(char(vFileName),'_','\_');
C = strsplit(S,'/');
%titletxt=C(3);
%for sid = 4:length(C)
%	titletxt = strcat(titletxt ,'/',C(sid));
%end
%title(titletxt');
%%%%%%%%%%%%%%% 2D histogram %%%%%%%%%%%%%%%%

figure;
X=[vDistSpot,vIntSpot];
hist3(X,[100 100]);
xlabel('distance');ylabel('Intensity');
set(get(gca,'child'),'FaceColor','interp','CDataMode','auto');

%%%%%%%%%%%%%%% Write to file %%%%%%%%%%%%%%%%%%

% ask user for filename to write to
[xlsfilename, xlspathname] = uiputfile('*.xlsx','Save data to excel spreadsheet');
comp_path = fullfile(xlspathname,xlsfilename);
if isempty(xlsfilename), return, end
%msgbox([num2str(size(vCoords)), '  ', num2str(size(vTimes)), '  ', num2str(size(vIntSpot)) ]);
data_out=double([double(vIntSpot ),double(vDistSpot)]);
data_cells=num2cell(data_out);     %Convert data to cell array
col_header={'Spot intensity','Spot distance'};     %Row cell array (for column labels)
msgbox([num2str(size(col_header)), '  ', num2str(size(data_cells))] );
output_matrix=[ col_header; data_cells];     %Join cell arrays
format long 
%xlswrite(comp_path,  data_out);
xlswrite(comp_path,  output_matrix, 'spots intensity vs distance');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% figure;
% edges2=[-2:0.1:15];
% [N,edges3,bin]=histcounts(vColoc1,edges2);
% a=zeros(size(N));
% for i=1:length(vIntSpot)
	% try
		% a(bin(i)) = a(bin(i)) + vIntSpot(i);
	% catch MException
		% msgbox(['problem at: ',num2str(i)]);
	% end
% end
% edges4=edges3(1:length(edges3)-1);
% msgbox(num2str([size(a), size(edges4)]))
% bar(edges4,a/sum(a));
%set(get(gca,'child'),'FaceColor','interp','CDataMode','auto');

% create new group
% vSpotsGroup = vImarisApplication.GetFactory.CreateDataContainer;
% vSpotsGroup.SetName(sprintf('Rec Endosome distance from coverslip', ...
    % vThreshold));

% new spots
% vNewSpots1 = vImarisApplication.GetFactory.CreateSpots;
% vNewSpots1.Set(vSpotsXYZ1(vColoc1, :), vTime1(vColoc1)-1, zeros(sum(vColoc1),1));
% vNewSpots1.SetRadiiXYZ(vRadius1(vColoc1,:));
% vNewSpots1.SetName([char(vSpots.GetName), ' split/relay events']);
% vRGBA = [0, 255, 0, 0];
% vRGBA = uint32(vRGBA * [1; 256; 256*256; 256*256*256]);
% vNewSpots1.SetColorRGBA(vRGBA);
% vSpotsGroup.AddChild(vNewSpots1, -1);

% %vNewSpots1 = vImarisApplication.GetFactory.CreateSpots;
% %vNewSpots1.Set(vSpotsXYZ1(vNonColoc1, :), vTime1(vNonColoc1), zeros(sum(vNonColoc1),1));
% %vNewSpots1.SetRadiiXYZ(vRadius1(vNonColoc1,:));
% %vNewSpots1.SetName([char(vSpots1.GetName), ' non-colocated']);
% %vRGBA = vSpots1.GetColorRGBA;
% %vNewSpots1.SetColorRGBA(vRGBA);
% %vSpotsGroup.AddChild(vNewSpots1, -1);

% vNewSpots2 = vImarisApplication.GetFactory.CreateSpots;
% vNewSpots2.Set(vSpotsXYZ2(vColoc2, :), vTime2(vColoc2)-1, zeros(sum(vColoc2),1));
% vNewSpots2.SetRadiiXYZ(vRadius2(vColoc2,:));
% vNewSpots2.SetName([char(vSpots.GetName),' track beginning spot']);
% vRGBA = [255, 0, 0, 0];
% vRGBA = uint32(vRGBA * [1; 256; 256*256; 256*256*256]);
% vNewSpots2.SetColorRGBA(vRGBA);
% vSpotsGroup.AddChild(vNewSpots2, -1);

% % vNewSpots2 = vImarisApplication.GetFactory.CreateSpots;
% % vNewSpots2.Set(vSpotsXYZ2(vNonColoc2, :), vTime2(vNonColoc2), zeros(sum(vNonColoc2),1));
% % vNewSpots2.SetRadiiXYZ(vRadius2(vNonColoc2,:));
% % vNewSpots2.SetName([char(vSpots2.GetName), ' non-colocated']);
% % vRGBA = vSpots2.GetColorRGBA;
% % vNewSpots2.SetColorRGBA(vRGBA);
% % vSpotsGroup.AddChild(vNewSpots2, -1);

% vSpots.SetVisible(0);
% %vSpots2.SetVisible(0);
% vScene.AddChild(vSpotsGroup, -1);

