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
%       <Submenu name="Clipping Plane Functions">
%        <Item name="Get Clipping Plane Info" icon="Matlab">
%          <Command>MatlabXT::XTClippingPlaneInfo(%i)</Command>
%        </Item>
%       </Submenu>
%      </Menu>
%      <SurpassTab>
%        <SurpassComponent name="bpSpots">
%          <Item name="GetClippingPlane Info" icon="Matlab">
%            <Command>MatlabXT::XTClippingPlaneInfo(%i)</Command>
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

function XTClippingPlaneInfo(aImarisApplicationID, aThreshold)

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
    msgbox('Please create a clipping plane in the Surpass scene!');
    return;
end

% get the selected object - check if it is a clipping plane object
vPlane = vImarisApplication.GetSurpassSelection;
vPlaneSelected = vImarisApplication.GetFactory.IsClippingPlane(vPlane);

% get more details of the parent of the spots object
if vPlaneSelected
    vScene = vPlane.GetParent;
else
    vScene = vImarisApplication.GetSurpassScene;
end

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
vRESpots = [];
while length(vRESpots) ~= 1
    [vRESpots, vOk] = listdlg('ListString',vNamesList,'SelectionMode','multiple',...
        'ListSize',[250 150],'Name','Select clipping plane','InitialValue',[1], ...
        'PromptString',{'Please select the plane to analyze:'});
    if vOk<1, return, end
    if length(vRESpots) ~= 1
        vHandle = msgbox(['Please select only one object.  ', ...
            'click to select/unselect an object of the list.']);
        uiwait(vHandle);
    end
end

vPlane = vPlanesList{vRESpots(1)}; 
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

prompt = {'Enter angle:','Enter axis'};
dlg_title = 'Input quaternion';
num_lines = 1;
vQuaternion=vPlane.GetOrientationQuaternion;
defaultans = {num2str(acos(vQuaternion(1))*180*2/pi), num2str(1/sin(acos(vQuaternion(1)))*[vQuaternion(2) vQuaternion(3) vQuaternion(4)])};
answer = inputdlg(prompt,dlg_title,num_lines,defaultans);
if (~isempty(answer))
	qAng = str2num(answer{1});
	qAx = str2num(answer{2});
	q = quatnormalize([cosd(qAng/2) sind(qAng/2)*1/norm(qAx)*[qAx(1) qAx(2) qAx(3)]]);
	vPlane.SetOrientationQuaternion(q);
end
		
while(~isempty(answer))
	prompt = {'Enter angle:','Enter axis'};
	dlg_title = 'Input quaternion';
	num_lines = 1;
	vQuaternion=vPlane.GetOrientationQuaternion;
	defaultans = {num2str(acos(vQuaternion(1))*180*2/pi), num2str(1/sin(acos(vQuaternion(1)))*[vQuaternion(2) vQuaternion(3) vQuaternion(4)])};
	%defaultans = {'0', '0 0 1'};
	answer = inputdlg(prompt,dlg_title,num_lines,defaultans);
	if (~isempty(answer))
		qAng = str2num(answer{1});
		qAx = str2num(answer{2});
		q = quatnormalize([cosd(qAng/2) sind(qAng/2)*1/norm(qAx)*[qAx(1) qAx(2) qAx(3)]]);
		vPlane.SetOrientationQuaternion(q);
	end
end