PROGRAM_NAME='office-scheduling'


DEFINE_DEVICE

dvMaster = 0:1:0

dvTPGCBoardroom = 10001:1:0
dvTPGCBoardroomRms = 10001:7:0

dvTPGCMeeting = 10002:1:0
dvTPGCMeetingRms = 10002:7:0

dvTPGCTraining = 10003:1:0
dvTPGCTrainingRms = 10003:7:0

dvTPSydBoardroom = 10004:1:0
dvTPSydBoardroomRms = 10004:9:0

dvTPSydTraining = 10005:1:0
dvTPSydTrainingRms = 10005:9:0

vdvRms = 41001:1:0

vdvRmsGui = 41002:1:0


define_variable

volatile dev rmsPanels[] = {
	dvTPGCBoardroomRms,
	dvTPGCMeetingRms,
	dvTPGCTrainingRms,
	dvTPSydBoardroomRms,
	dvTPSydTrainingRms
}

volatile dev basePanels[] = {
	dvTPGCBoardroom,
	dvTPGCMeeting,
	dvTPGCTraining,
	dvTPSydBoardroom,
	dvTPSydTraining
}


include 'RmsGuiApi'


define_function showSchedulingPage(dev tp) {
	send_command tp, 'PAGE-rmsSchedulingPage'
}


define_module 'RmsNetLinxAdapter_dr4_0_0' mdlRms(vdvRms)

define_module 'RmsClientGui_dr4_0_0' mdlRmsGui(vdvRmsGui, rmsPanels, basePanels)

define_module 'RmsControlSystemMonitor' mdlRmsControlSys(vdvRms, dvMaster)

define_module 'RmsTouchPanelMonitor' mdlRmsTPGCBoardroom(vdvRms, dvTPGCBoardroom)
define_module 'RmsTouchPanelMonitor' mdlRmsTPGCMeeting(vdvRms, dvTPGCMeeting)
define_module 'RmsTouchPanelMonitor' mdlRmsTPGCTraining(vdvRms, dvTPGCTraining)
define_module 'RmsTouchPanelMonitor' mdlRmsTPSydBoardroom(vdvRms, dvTPSydBoardroom)
define_module 'RmsTouchPanelMonitor' mdlRmsTPSydTraining(vdvRms, dvTPSydTraining)


define_event

data_event[vdvRmsGui] {

	online: {
		RmsSetExternalPanel(dvTPGCBoardroom, dvTPGCBoardroomRms)
		RmsSetExternalPanel(dvTPGCMeeting, dvTPGCMeetingRms)
		RmsSetExternalPanel(dvTPGCTraining, dvTPGCTrainingRms)
		RmsSetExternalPanel(dvTPSydBoardroom, dvTPSydBoardroomRms)
		RmsSetExternalPanel(dvTPSydTraining, dvTPSydTrainingRms)
	}

}

data_event[rmsPanels] {

	online: {
		showSchedulingPage(data.device)
	}

}
