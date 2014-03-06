PROGRAM_NAME='office-scheduling'


DEFINE_DEVICE

dvMaster = 0:1:0;

dvTPBoardroom = 10001:1:0;
dvTPTraining = 10002:1:0;
dvTPMeeting = 10003:1:0;

vdvRms = 41001:1:0;


//define_module 'RmsNetLinxAdapter_dr4_0_0' mdlRms(vdvRms);

define_module 'RmsControlSystemMonitor' mdlRmsControlSys(vdvRms, dvMaster);

define_module 'RmsTouchPanelMonitor' mdlRmsBoardroomTp(vdvRMS, dvTPBoardroom);
define_module 'SchedulingUI' mdlBoardroomUi(vdvRms, dvTPBoardroom);

define_module 'RmsTouchPanelMonitor' mdlRmsTrainingTp(vdvRMS, dvTPTraining);
define_module 'SchedulingUI' mdlTrainingUi(vdvRms, dvTPTraining);

// The additional meeting room panel does not exist in every office however no
// harm in instantiating this. The RMS monitor will not register a device unless
// it is online.
define_module 'RmsTouchPanelMonitor' mdlRmsMeetingTp(vdvRMS, dvTPMeeting);
define_module 'SchedulingUI' mdlMeetingUi(vdvRms, dvTPMeeting);
