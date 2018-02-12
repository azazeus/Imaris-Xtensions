%
%
%  Track Mean Square Displacement Function for Imaris 7.3.0
%
%  Copyright Bitplane AG 2011
%  Modified by Amar Bhagwat (Nov. 2017)
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
%        <Item name="Mean Sq. Disp." icon="Matlab" tooltip="Plot mean square displacement for the tracks.">
%          <Command>MatlabXT::XTTrackPlotMSD(%i)</Command>
%        </Item>
%       </Submenu>
%      </Menu>
%      <SurpassTab>
%        <SurpassComponent name="bpSpots">
%          <Item name="Mean Sq. Disp." icon="Matlab" tooltip="Plot mean square displacement for the tracks.">
%            <Command>MatlabXT::XTTrackPlotMSD(%i)</Command>
%          </Item>
%        </SurpassComponent>
%        <SurpassComponent name="bpSurfaces">
%          <Item name="Mean Sq. Disp." icon="Matlab" tooltip="Plot mean square displacement for the tracks.">
%            <Command>MatlabXT::XTTrackPlotMSD(%i)</Command>
%          </Item>
%        </SurpassComponent>
%      </SurpassTab>
%    </CustomTools>
% 
%
%  Description:
%   
%	TODO: This function needs a description!!
%

function XTTrackPlotMSD(aImarisApplicationID,aThreshold)

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
vCurPathName = char(vImarisApplication.GetCurrentFileName());
vCurFileName = split(vCurPathName,[string('\'),string('/'),string('.')])'; 
if isequal(vSurpassScene, [])
  msgbox('Please create some tracks in the surpass scene!');
  return
end
%msgbox(['current file name ', vCurFileName(end)]);
% get the selected object (spots or surfaces)
% read coordinates, time points and number of objects
vFactory = vImarisApplication.GetFactory;
vObjects = vImarisApplication.GetSurpassSelection;
vScene = vObjects.GetParent;
if vFactory.IsSpots(vObjects) %each spot gets the following data
  vObjects = vFactory.ToSpots(vObjects);
  vCoords = vObjects.GetPositionsXYZ; %3 element array denoting [X,Y,Z]position
  vTimes = vObjects.GetIndicesT + 1; % time frame the spot belongs to (MATLAB index starts at 1)
  vRadius = vObjects.GetRadiiXYZ; %X,Y,Z radii of the ellipsoid fit to the spot
  vNumberOfObjects = numel(vTimes); % number of objects found
  vTrackIds = vObjects.GetTrackIds; % unique ID of track that the spot belong to
else
  msgbox('Please select some spots!')
  return
end

% get the edges
vEdges = vObjects.GetTrackEdges + 1; % add correction of 1, because indices start from 1 in Matlab

if isempty(vEdges)  
  msgbox('Please select some tracks!')
  return
end


vNumberOfEdges = size(vEdges, 1);
vListofTracks=unique(vTrackIds); % array of unique track IDs

%initialize arrays to hold calculations
vTrackDispOverTime=nan(length(vListofTracks),499);

vStepsTotal=0;
nStepsTotal=0;
maxtrklen=0;
figure;
hold on;
for idx=1:length(vListofTracks)
 
	% figure out the spots belonging to the current track
	vTrackEdges=vEdges(vTrackIds == vListofTracks(idx),:);
	vStart = vCoords(vTrackEdges(:,1),:); % array of starting points of edges
	vEnd =  vCoords(vTrackEdges(:,2),:); % array of end points of the same edges
	vTrackDispTot = sqrt(sum((vEnd(end,:) - vStart(1,:)).^2));
	vTrackLenTot = sum(sqrt(sum((vEnd - vStart).^2,2)));
	vTrackStrght = vTrackDispTot/vTrackLenTot;
	vDispSq = sum((vEnd - vStart(1,:)).^2,2); %find displacements from starting position
    aTrackLen = size(vDispSq,1); %how many values do I need to sub into vTrackDispOverTime
	if (aTrackLen>30)
		vTrackDispOverTime(idx,1:aTrackLen) = vDispSq';
	end
    
end
%find which elements are not NaNs
vTrackDOTBool = ~isnan(vTrackDispOverTime); 
disp_sum_over_time = sum(vTrackDispOverTime,1,'omitnan');
exist_steps_over_time = sum(vTrackDOTBool,1,'omitnan');
MSDOverTime = disp_sum_over_time./exist_steps_over_time;

disp(['size of MSDOverTime: ',num2str(exist_steps_over_time)]);
plot(MSDOverTime,'r-');
xlim([0,30]);
title(horzcat(strrep(vCurFileName(end-1),'_','-'),'MSD over 30'));
xlabel('duration [# of timeframes]');
ylabel('mean square displacement [um^2]');

% save the figure in a file
dirnam = uigetdir('D:\SPIMdata');
fname=fullfile(dirnam,horzcat(char(vCurFileName(end-1)),'-MSD_over_30.fig'));
msgbox(char(vCurFileName(end-1)));
savefig(fname);

%% ask user for filename to write to
% [xlsfilename, xlspathname] = uiputfile('*.xlsx','Save data to excel spreadsheet');
% comp_path = fullfile(xlspathname,xlsfilename);
% % if no spots, exit
% if isempty(xlsfilename), return, end
% 
% % write a worksheet with information about spots: location, timestamp, intensity, and distance from coverslip
% data_out=double(N1(1:end-1,2:end));
% data_cells=num2cell(data_out);     %Convert data to cell array
% col_header=['Horz axis: track duration','bin edges',num2cell(edges{2})];     % column labels
% row_header=['Vert axis: arrest coeff','bin edges',num2cell(edges{1})];
% % output_matrix=[ col_header; [row_header',data_cells]];     %Join cell arrays
% format long 
% xlswrite(comp_path,  col_header, 'steps vs track duration','C1');
% xlswrite(comp_path,  row_header, 'steps vs track duration','C2');
% xlswrite(comp_path,  data_cells, 'steps vs track duration','C4');