PROGRAM_NAME='office-scheduling'


DEFINE_DEVICE

dvMaster = 0:1:0;

dvTPBoardroom = 10001:1:0;
dvTPTraining = 10002:1:0;
dvTPMeeting = 10003:1:0;

vdvRms = 41001:1:0;
vdvMD5Util = 41002:1:0;


define_module

'RmsNetLinxAdapter_dr4_0_0' mdlRms(vdvRms);

'RmsControlSystemMonitor' mdlRmsControlSys(vdvRms, dvMaster);

'RmsTouchPanelMonitor' mdlRmsBoardroomTp(vdvRMS, dvTPBoardroom);
'SchedulingUI' mdlBoardroomUi(vdvRms, dvTPBoardroom);

'RmsTouchPanelMonitor' mdlRmsTrainingTp(vdvRMS, dvTPTraining);
'SchedulingUI' mdlTrainingUi(vdvRms, dvTPTraining);

// The additional meeting room panel does not exist in every office however no
// harm in instantiating this. The RMS monitor will not register a device unless
// it is online.
'RmsTouchPanelMonitor' mdlRmsMeetingTp(vdvRMS, dvTPMeeting);
'SchedulingUI' mdlMeetingUi(vdvRms, dvTPMeeting);
