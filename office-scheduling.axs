PROGRAM_NAME='office-scheduling'


DEFINE_DEVICE

dvMaster = 0:1:0;

dvTPGCBoardroom = 10001:1:0;
dvTPGCMeeting = 10002:1:0;
dvTPGCTraining = 10003:1:0;
dvTPSydBoardroom = 10004:1:0;
dvTPSydTraining = 10005:1:0;

vdvRms = 41001:1:0;


define_module 'RmsNetLinxAdapter_dr4_0_0' mdlRms(vdvRms);

define_module 'RmsControlSystemMonitor' mdlRmsControlSys(vdvRms, dvMaster);

define_module 'RmsTouchPanelMonitor' mdlRmsGCBoardroomTp(vdvRMS, dvTPGCBoardroom);
define_module 'RmsTouchPanelMonitor' mdlRmsGCMeetingTp(vdvRMS, dvTPGCMeeting);
define_module 'RmsTouchPanelMonitor' mdlRmsGCTrainingTp(vdvRMS, dvTPGCTraining);
define_module 'RmsTouchPanelMonitor' mdlRmsSydBoardroomTp(vdvRMS, dvTPSydBoardroom);
define_module 'RmsTouchPanelMonitor' mdlRmsSydTrainingTp(vdvRMS, dvTPSydTraining);

define_module 'SchedulingUI' mdlGCBoardroomUi(vdvRms, dvTPGCBoardroom);
define_module 'SchedulingUI' mdlGCMeetingUi(vdvRms, dvTPGCMeeting);
define_module 'SchedulingUI' mdlGCTrainingUi(vdvRms, dvTPGCTraining);
define_module 'SchedulingUI' mdlSydBoardroomUi(vdvRms, dvTPSydBoardroom);
define_module 'SchedulingUI' mdlSydTrainingUi(vdvRms, dvTPSydTraining);

#WARN 'logger enabled for debug'
define_module 'RmsSchedulingEventLogger' mdlLogger(vdvRms);


define_event

data_event[vdvRms] {

	online: {
		send_command data.device, '@LOG.SCHEDULING.EVENTS-true';
	}

}