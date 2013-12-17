PROGRAM_NAME='office-scheduling'


DEFINE_DEVICE

dvMaster = 0:1:0

dvTPGCBoardroom = 10001:1:0
dvTPGCMeeting = 10002:1:0
dvTPGCTraining = 10003:1:0
dvTPSydBoardroom = 10004:1:0
dvTPSydTraining = 10005:1:0

vdvRms = 41001:1:0


define_module 'RmsNetLinxAdapter_dr4_0_0' mdlRms(vdvRms)

define_module 'RmsControlSystemMonitor' mdlRmsControlSys(vdvRms, dvMaster)
