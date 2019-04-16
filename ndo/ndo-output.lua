local socket = require "socket"

-- Specifying where is the module to load
package.path = package.path .. ";/usr/share/centreon-broker/lua/ndo-module.lua"
local NDO = require "ndo"

local ndo = {
  [65537] = {
    id = 1,
    ndo_api_id = NDO.api.NDO_API_ACKNOWLEDGEMENTDATA,
    key = {
      { ndo_data = NDO.data.NDO_DATA_ACKNOWLEDGEMENTTYPE, tag = "type" },
      { ndo_data = NDO.data.NDO_DATA_AUTHORNAME, tag = "author" },
      { ndo_data = NDO.data.NDO_DATA_COMMENT, tag = "comment_data" },
      { ndo_data = NDO.data.NDO_DATA_EXPIRATIONTIME, tag = "deletion_time" },
      { ndo_data = NDO.data.NDO_DATA_TIMESTAMP, tag = "entry_time" },
      { ndo_data = NDO.data.NDO_DATA_HOSTNAME, tag = "host_id" },
      { ndo_data = NDO.data.NDO_DATA_INSTANCE, tag = "instance_id" },
      { ndo_data = NDO.data.NDO_DATA_STICKY, tag = "sticky" },
      { ndo_data = NDO.data.NDO_DATA_NOTIFYCONTACTS, tag = "notify_contacts" },
      { ndo_data = NDO.data.NDO_DATA_PERSISTENT, tag = "persistent_comment" },
      { ndo_data = NDO.data.NDO_DATA_SERVICEDESCRIPTION, tag = "service_id" },
      { ndo_data = NDO.data.NDO_DATA_STATE, tag = "state" },
    }
  },
  [65538] = {
    id = 2,
    ndo_api_id = NDO.api.NDO_API_COMMENTDATA,
    key = {
      { ndo_data = NDO.data.NDO_DATA_AUTHORNAME, tag = "author" },
      { ndo_data = NDO.data.NDO_DATA_COMMENTTYPE, tag = "type" },
      { ndo_data = NDO.data.NDO_DATA_ENDTIME, tag = "deletion_time" },
      { ndo_data = NDO.data.NDO_DATA_ENTRYTIME, tag = "entry_time" },
      { ndo_data = NDO.data.NDO_DATA_ENTRYTYPE, tag = "entry_type" },
      { ndo_data = NDO.data.NDO_DATA_EXPIRATIONTIME, tag = "expire_time" },
      { ndo_data = NDO.data.NDO_DATA_EXPIRES, tag = "expires" },
      { ndo_data = NDO.data.NDO_DATA_HOSTNAME, tag = "host_id" },
      { ndo_data = NDO.data.NDO_DATA_INSTANCE, tag = "instance_id" },
      { ndo_data = NDO.data.NDO_DATA_COMMENTID, tag = "internal_id" },
      { ndo_data = NDO.data.NDO_DATA_PERSISTENT, tag = "persistent" },
      { ndo_data = NDO.data.NDO_DATA_SERVICEDESCRIPTION, tag = "service_id" },
      { ndo_data = NDO.data.NDO_DATA_SOURCE, tag = "source" },
      { ndo_data = NDO.data.NDO_DATA_COMMENT, tag = "data" },
    }
  },
  [65539] = {
    id = 3,
    ndo_api_id = NDO.api.NDO_API_RUNTIMEVARIABLES,
    key = {
      { ndo_data = NDO.data.NDO_DATA_HOST, tag = "host_id" },
      { ndo_data = NDO.data.NDO_DATA_HASBEENMODIFIED, tag = "modified" },
      { ndo_data = NDO.data.NDO_DATA_CONFIGFILENAME, tag = "name" },
      { ndo_data = NDO.data.NDO_DATA_SERVICE, tag = "service_id" },
      { ndo_data = NDO.data.NDO_DATA_ENTRYTIME, tag = "update_time" },
      { ndo_data = NDO.data.NDO_DATA_TYPE, tag = "type" },
      { ndo_data = NDO.data.NDO_DATA_ACTIVESERVICECHECKSENABLED, tag = "value" },
      { ndo_data = NDO.data.NDO_DATA_ACTIVEHOSTCHECKSENABLED, tag = "default_value" },
    }
  },
  [65540] = {
    id = 4,
    ndo_api_id = NDO.api.NDO_API_CONFIGVARIABLES,
    key = {
      { ndo_data = NDO.data.NDO_DATA_HOST, tag = "host_id" },
      { ndo_data = NDO.data.NDO_DATA_HASBEENMODIFIED, tag = "modified" },
      { ndo_data = NDO.data.NDO_DATA_CONFIGFILENAME, tag = "name" },
      { ndo_data = NDO.data.NDO_DATA_SERVICE, tag = "service_id" },
      { ndo_data = NDO.data.NDO_DATA_ENTRYTIME, tag = "update_time" },
      { ndo_data = NDO.data.NDO_DATA_ACTIVESERVICECHECKSENABLED, tag = "value" },
    }
  },
  [65541] = {
    id = 5,
    ndo_api_id = NDO.api.NDO_API_DOWNTIMEDATA,
    key = {
      { ndo_data = NDO.data.NDO_DATA_ACTUALENDTIME, tag = "actual_end_time" },
      { ndo_data = NDO.data.NDO_DATA_ACTUALSTARTTIME, tag = "actual_start_time" },
      { ndo_data = NDO.data.NDO_DATA_AUTHORNAME, tag = "author" },
      { ndo_data = NDO.data.NDO_DATA_DOWNTIMETYPE, tag = "type" },
      { ndo_data = NDO.data.NDO_DATA_EXPIRATIONTIME, tag = "deletion_time" },
      { ndo_data = NDO.data.NDO_DATA_DURATION, tag = "duration" },
      { ndo_data = NDO.data.NDO_DATA_ENDTIME, tag = "end_time" },
      { ndo_data = NDO.data.NDO_DATA_ENTRYTIME, tag = "entry_time" },
      { ndo_data = NDO.data.NDO_DATA_FIXED, tag = "fixed" },
      { ndo_data = NDO.data.NDO_DATA_HOSTNAME, tag = "host_id" },
      { ndo_data = NDO.data.NDO_DATA_INSTANCE, tag = "instance_id" },
      { ndo_data = NDO.data.NDO_DATA_DOWNTIMEID, tag = "internal_id" },
      { ndo_data = NDO.data.NDO_DATA_SERVICEDESCRIPTION, tag = "service_id" },
      { ndo_data = NDO.data.NDO_DATA_STARTTIME, tag = "start_time" },
      { ndo_data = NDO.data.NDO_DATA_TRIGGEREDBY, tag = "triggered_by" },
      { ndo_data = NDO.data.NDO_DATA_X3D, tag = "cancelled" },
      { ndo_data = NDO.data.NDO_DATA_Y3D, tag = "started" },
      { ndo_data = NDO.data.NDO_DATA_COMMENT, tag = "comment_data" },
    }
  },
  [65542] = {
    id = 6,
    ndo_api_id = NDO.api.NDO_API_EVENTHANDLERDATA,
    key = {
      { ndo_data = NDO.data.NDO_DATA_EARLYTIMEOUT, tag = "early_timeout" },
      { ndo_data = NDO.data.NDO_DATA_ENDTIME, tag = "end_time" },
      { ndo_data = NDO.data.NDO_DATA_EXECUTIONTIME, tag = "execution_time" },
      { ndo_data = NDO.data.NDO_DATA_TYPE, tag = "type" },
      { ndo_data = NDO.data.NDO_DATA_HOST, tag = "host_id" },
      { ndo_data = NDO.data.NDO_DATA_RETURNCODE, tag = "return_code" },
      { ndo_data = NDO.data.NDO_DATA_SERVICE, tag = "service_id" },
      { ndo_data = NDO.data.NDO_DATA_STARTTIME, tag = "start_time" },
      { ndo_data = NDO.data.NDO_DATA_STATE, tag = "state" },
      { ndo_data = NDO.data.NDO_DATA_STATETYPE, tag = "state_type" },
      { ndo_data = NDO.data.NDO_DATA_TIMEOUT, tag = "timeout" },
      { ndo_data = NDO.data.NDO_DATA_COMMANDARGS, tag = "command_args" },
      { ndo_data = NDO.data.NDO_DATA_COMMANDLINE, tag = "command_line" },
      { ndo_data = NDO.data.NDO_DATA_OUTPUT, tag = "output" },
    }
  },
  [65543] = {
    id = 7,
    ndo_api_id = NDO.api.NDO_API_FLAPPINGDATA,
    key = {
      { ndo_data = NDO.data.NDO_DATA_COMMENTTIME, tag = "comment_time" },
      { ndo_data = NDO.data.NDO_DATA_ENTRYTIME, tag = "event_time" },
      { ndo_data = NDO.data.NDO_DATA_ENTRYTYPE, tag = "event_type" },
      { ndo_data = NDO.data.NDO_DATA_TYPE, tag = "type" },
      { ndo_data = NDO.data.NDO_DATA_HIGHTHRESHOLD, tag = "high_threshold" },
      { ndo_data = NDO.data.NDO_DATA_HOST, tag = "host_id" },
      { ndo_data = NDO.data.NDO_DATA_COMMENTID, tag = "internal_comment_id" },
      { ndo_data = NDO.data.NDO_DATA_LOWTHRESHOLD, tag = "low_threshold" },
      { ndo_data = NDO.data.NDO_DATA_PERCENTSTATECHANGE, tag = "percent_state_change" },
      { ndo_data = NDO.data.NDO_DATA_NOTIFICATIONREASON, tag = "reason_type" },
      { ndo_data = NDO.data.NDO_DATA_SERVICE, tag = "service_id" },
    }
  },
  [65544] = {
    id = 8,
    ndo_api_id = NDO.api.NDO_API_HOSTDEFINITION,
    key = {
      { ndo_data = NDO.data.NDO_DATA_ACKNOWLEDGEMENTTYPE, tag = "acknowledgement_type" },
      { ndo_data = NDO.data.NDO_DATA_ACTIONURL, tag = "action_url" },
      { ndo_data = NDO.data.NDO_DATA_ACTIVEHOSTCHECKSENABLED, tag = "active_checks" },
      { ndo_data = NDO.data.NDO_DATA_HOSTADDRESS, tag = "address" },
      { ndo_data = NDO.data.NDO_DATA_HOSTALIAS, tag = "alias" },
      { ndo_data = NDO.data.NDO_DATA_HOSTFRESHNESSCHECKSENABLED, tag = "check_freshness" },
      { ndo_data = NDO.data.NDO_DATA_NORMALCHECKINTERVAL, tag = "check_interval" },
      { ndo_data = NDO.data.NDO_DATA_HOSTCHECKPERIOD, tag = "check_period" },
      { ndo_data = NDO.data.NDO_DATA_CHECKTYPE, tag = "check_type" },
      { ndo_data = NDO.data.NDO_DATA_CURRENTCHECKATTEMPT, tag = "check_attempt" },
      { ndo_data = NDO.data.NDO_DATA_CURRENTNOTIFICATIONNUMBER, tag = "notification_number" },
      { ndo_data = NDO.data.NDO_DATA_CURRENTSTATE, tag = "state" },
      { ndo_data = 0, tag = "default_active_checks" },
      { ndo_data = 0, tag = "default_event_handler_enabled" },
      { ndo_data = 0, tag = "default_failure_prediction" },
      { ndo_data = 0, tag = "default_flap_detection" },
      { ndo_data = 0, tag = "default_notify" },
      { ndo_data = 0, tag = "default_passive_checks" },
      { ndo_data = 0, tag = "default_process_perfdata" },
      { ndo_data = NDO.data.NDO_DATA_DISPLAYNAME, tag = "display_name" },
      { ndo_data = NDO.data.NDO_DATA_X3D, tag = "enabled" },
      { ndo_data = NDO.data.NDO_DATA_EVENTHANDLER, tag = "event_handler" },
      { ndo_data = NDO.data.NDO_DATA_EVENTHANDLERENABLED, tag = "event_handler_enabled" },
      { ndo_data = NDO.data.NDO_DATA_EXECUTIONTIME, tag = "execution_time" },
      { ndo_data = NDO.data.NDO_DATA_FAILUREPREDICTIONENABLED, tag = "failure_prediction" },
      { ndo_data = NDO.data.NDO_DATA_FIRSTNOTIFICATIONDELAY, tag = "first_notification_delay" },
      { ndo_data = NDO.data.NDO_DATA_FLAPDETECTIONENABLED, tag = "flap_detection" },
      { ndo_data = NDO.data.NDO_DATA_FLAPDETECTIONONDOWN, tag = "flap_detection_on_down" },
      { ndo_data = NDO.data.NDO_DATA_FLAPDETECTIONONUNREACHABLE, tag = "flap_detection_on_unreachable" },
      { ndo_data = NDO.data.NDO_DATA_FLAPDETECTIONONUP, tag = "flap_detection_on_up" },
      { ndo_data = NDO.data.NDO_DATA_HOSTFRESHNESSTHRESHOLD, tag = "freshness_threshold" },
      { ndo_data = NDO.data.NDO_DATA_HASBEENCHECKED, tag = "checked" },
      { ndo_data = NDO.data.NDO_DATA_HIGHHOSTFLAPTHRESHOLD, tag = "high_flap_threshold" },
      { ndo_data = NDO.data.NDO_DATA_HOSTNAME, tag = "name" },
      { ndo_data = NDO.data.NDO_DATA_ICONIMAGE, tag = "icon_image" },
      { ndo_data = NDO.data.NDO_DATA_ICONIMAGEALT, tag = "icon_image_alt" },
      { ndo_data = NDO.data.NDO_DATA_HOST, tag = "host_id" },
      { ndo_data = NDO.data.NDO_DATA_INSTANCE, tag = "instance_id" },
      { ndo_data = NDO.data.NDO_DATA_ISFLAPPING, tag = "flapping" },
      { ndo_data = NDO.data.NDO_DATA_LASTHOSTCHECK, tag = "last_check" },
      { ndo_data = NDO.data.NDO_DATA_LASTHARDSTATE, tag = "last_hard_state" },
      { ndo_data = NDO.data.NDO_DATA_LASTHARDSTATECHANGE, tag = "last_hard_state_change" },
      { ndo_data = NDO.data.NDO_DATA_LASTHOSTNOTIFICATION, tag = "last_notification" },
      { ndo_data = NDO.data.NDO_DATA_LASTSTATECHANGE, tag = "last_state_change" },
      { ndo_data = NDO.data.NDO_DATA_LASTTIMEDOWN, tag = "last_time_down" },
      { ndo_data = NDO.data.NDO_DATA_LASTTIMEUNREACHABLE, tag = "last_time_unreachable" },
      { ndo_data = NDO.data.NDO_DATA_LASTTIMEUP, tag = "last_time_up" },
      { ndo_data = NDO.data.NDO_DATA_LASTUPDATE, tag = "last_update" },
      { ndo_data = NDO.data.NDO_DATA_LATENCY, tag = "latency" },
      { ndo_data = NDO.data.NDO_DATA_LOWHOSTFLAPTHRESHOLD, tag = "low_flap_threshold" },
      { ndo_data = NDO.data.NDO_DATA_MAXCHECKATTEMPTS, tag = "max_check_attempts" },
      { ndo_data = NDO.data.NDO_DATA_MODIFIEDHOSTATTRIBUTES, tag = "modified_attributes" },
      { ndo_data = NDO.data.NDO_DATA_NEXTHOSTCHECK, tag = "next_check" },
      { ndo_data = NDO.data.NDO_DATA_NEXTHOSTNOTIFICATION, tag = "next_host_notification" },
      { ndo_data = NDO.data.NDO_DATA_NOMORENOTIFICATIONS, tag = "no_more_notifications" },
      { ndo_data = NDO.data.NDO_DATA_NOTES, tag = "notes" },
      { ndo_data = NDO.data.NDO_DATA_NOTESURL, tag = "notes_url" },
      { ndo_data = NDO.data.NDO_DATA_HOSTNOTIFICATIONINTERVAL, tag = "notification_interval" },
      { ndo_data = NDO.data.NDO_DATA_HOSTNOTIFICATIONPERIOD, tag = "notification_period" },
      { ndo_data = NDO.data.NDO_DATA_NOTIFICATIONSENABLED, tag = "notify" },
      { ndo_data = NDO.data.NDO_DATA_NOTIFYHOSTDOWN, tag = "notify_on_down" },
      { ndo_data = NDO.data.NDO_DATA_NOTIFYHOSTDOWNTIME, tag = "notify_on_downtime" },
      { ndo_data = NDO.data.NDO_DATA_NOTIFYHOSTFLAPPING, tag = "notify_on_flapping" },
      { ndo_data = NDO.data.NDO_DATA_NOTIFYHOSTRECOVERY, tag = "notify_on_recovery" },
      { ndo_data = NDO.data.NDO_DATA_NOTIFYHOSTUNREACHABLE, tag = "notify_on_unreachable" },
      { ndo_data = NDO.data.NDO_DATA_OBSESSOVERHOST, tag = "obsess_over_host" },
      { ndo_data = NDO.data.NDO_DATA_PASSIVEHOSTCHECKSENABLED, tag = "passive_checks" },
      { ndo_data = NDO.data.NDO_DATA_PERCENTSTATECHANGE, tag = "percent_state_change" },
      { ndo_data = NDO.data.NDO_DATA_PROBLEMHASBEENACKNOWLEDGED, tag = "acknowledged" },
      { ndo_data = NDO.data.NDO_DATA_PROCESSPERFORMANCEDATA, tag = "process_perfdata" },
      { ndo_data = NDO.data.NDO_DATA_RETAINHOSTNONSTATUSINFORMATION, tag = "retain_nonstatus_information" },
      { ndo_data = NDO.data.NDO_DATA_RETAINHOSTSTATUSINFORMATION, tag = "retain_status_information" },
      { ndo_data = NDO.data.NDO_DATA_RETRYCHECKINTERVAL, tag = "retry_interval" },
      { ndo_data = NDO.data.NDO_DATA_SCHEDULEDDOWNTIMEDEPTH, tag = "scheduled_downtime_depth" },
      { ndo_data = NDO.data.NDO_DATA_SHOULDBESCHEDULED, tag = "should_be_scheduled" },
      { ndo_data = NDO.data.NDO_DATA_STALKHOSTONDOWN, tag = "stalk_on_down" },
      { ndo_data = NDO.data.NDO_DATA_STALKHOSTONUNREACHABLE, tag = "stalk_on_unreachable" },
      { ndo_data = NDO.data.NDO_DATA_STALKHOSTONUP, tag = "stalk_on_up" },
      { ndo_data = NDO.data.NDO_DATA_STATETYPE, tag = "state_type" },
      { ndo_data = NDO.data.NDO_DATA_STATUSMAPIMAGE, tag = "statusmap_image" },
      { ndo_data = NDO.data.NDO_DATA_CHECKCOMMAND, tag = "check_command" },
      { ndo_data = NDO.data.NDO_DATA_OUTPUT, tag = "output" },
      { ndo_data = NDO.data.NDO_DATA_PERFDATA, tag = "perfdata" },
    }
  },
  [65545] = {
    id = 9,
    ndo_api_id = NDO.api.NDO_API_HOSTCHECKDATA,
    key = {
      { ndo_data = NDO.data.NDO_DATA_HOST, tag = "host_id" },
      { ndo_data = NDO.data.NDO_DATA_COMMANDLINE, tag = "command_line" },
    }
  },
  [65546] = {
    id = 10,
    ndo_api_id = NDO.api.NDO_API_HOSTDEPENDENCYDEFINITION,
    key = {
      { ndo_data = NDO.data.NDO_DATA_DEPENDENCYPERIOD, tag = "dependency_period" },
      { ndo_data = NDO.data.NDO_DATA_DEPENDENTHOSTNAME, tag = "dependent_host_id" },
      { ndo_data = NDO.data.NDO_DATA_HOSTFAILUREPREDICTIONOPTIONS, tag = "execution_failure_options" },
      { ndo_data = NDO.data.NDO_DATA_INHERITSPARENT, tag = "inherits_parent" },
      { ndo_data = NDO.data.NDO_DATA_HOSTNOTIFICATIONCOMMAND, tag = "notification_failure_options" },
      { ndo_data = NDO.data.NDO_DATA_HOST, tag = "host_id" },
    }
  },
  [65547] = {
    id = 11,
    ndo_api_id = NDO.api.NDO_API_HOSTGROUPDEFINITION,
    key = {
      { ndo_data = NDO.data.NDO_DATA_INSTANCE, tag = "name" },
      { ndo_data = NDO.data.NDO_DATA_HOSTID, tag = "hostgroup_id" },
    }
  },
  [65548] = {
    id = 12,
    ndo_api_id = NDO.api.NDO_API_HOSTGROUPMEMBERDEFINITION,
    key = {
      { ndo_data = NDO.data.NDO_DATA_HOSTGROUPNAME, tag = "hostgroup_id" },
      { ndo_data = NDO.data.NDO_DATA_INSTANCE, tag = "host_id" },
    }
  },
  [65549] = {
    id = 13,
    ndo_api_id = NDO.api.NDO_API_HOSTPARENT,
    key = {
      { ndo_data = NDO.data.NDO_DATA_HOST, tag = "child_id" },
      { ndo_data = NDO.data.NDO_DATA_PARENTHOST, tag = "parent_id" },
    }
  },
  [65550] = {
    id = 14,
    ndo_api_id = NDO.api.NDO_API_HOSTSTATUSDATA,
    key = {
      { ndo_data = NDO.data.NDO_DATA_ACKNOWLEDGEMENTTYPE, tag = "acknowledgement_type" },
      { ndo_data = NDO.data.NDO_DATA_ACTIVEHOSTCHECKSENABLED, tag = "active_checks" },
      { ndo_data = NDO.data.NDO_DATA_NORMALCHECKINTERVAL, tag = "check_interval" },
      { ndo_data = NDO.data.NDO_DATA_HOSTCHECKPERIOD, tag = "check_period" },
      { ndo_data = NDO.data.NDO_DATA_CHECKTYPE, tag = "check_type" },
      { ndo_data = NDO.data.NDO_DATA_CURRENTCHECKATTEMPT, tag = "check_attempt" },
      { ndo_data = NDO.data.NDO_DATA_CURRENTNOTIFICATIONNUMBER, tag = "notification_number" },
      { ndo_data = NDO.data.NDO_DATA_CURRENTSTATE, tag = "state" },
      { ndo_data = NDO.data.NDO_DATA_X3D, tag = "enabled" },
      { ndo_data = NDO.data.NDO_DATA_EVENTHANDLER, tag = "event_handler" },
      { ndo_data = NDO.data.NDO_DATA_EVENTHANDLERENABLED, tag = "event_handler_enabled" },
      { ndo_data = NDO.data.NDO_DATA_EXECUTIONTIME, tag = "execution_time" },
      { ndo_data = NDO.data.NDO_DATA_FAILUREPREDICTIONENABLED, tag = "failure_prediction" },
      { ndo_data = NDO.data.NDO_DATA_FLAPDETECTIONENABLED, tag = "flap_detection" },
      { ndo_data = NDO.data.NDO_DATA_HASBEENCHECKED, tag = "checked" },
      { ndo_data = NDO.data.NDO_DATA_HOST, tag = "host_id" },
      { ndo_data = NDO.data.NDO_DATA_ISFLAPPING, tag = "flapping" },
      { ndo_data = NDO.data.NDO_DATA_LASTHOSTCHECK, tag = "last_check" },
      { ndo_data = NDO.data.NDO_DATA_LASTHARDSTATE, tag = "last_hard_state" },
      { ndo_data = NDO.data.NDO_DATA_LASTHARDSTATECHANGE, tag = "last_hard_state_change" },
      { ndo_data = NDO.data.NDO_DATA_LASTHOSTNOTIFICATION, tag = "last_notification" },
      { ndo_data = NDO.data.NDO_DATA_LASTSTATECHANGE, tag = "last_state_change" },
      { ndo_data = NDO.data.NDO_DATA_LASTTIMEDOWN, tag = "last_time_down" },
      { ndo_data = NDO.data.NDO_DATA_LASTTIMEUNREACHABLE, tag = "last_time_unreachable" },
      { ndo_data = NDO.data.NDO_DATA_LASTTIMEUP, tag = "last_time_up" },
      { ndo_data = NDO.data.NDO_DATA_LASTUPDATE, tag = "last_update" },
      { ndo_data = NDO.data.NDO_DATA_LATENCY, tag = "latency" },
      { ndo_data = NDO.data.NDO_DATA_MAXCHECKATTEMPTS, tag = "max_check_attempts" },
      { ndo_data = NDO.data.NDO_DATA_MODIFIEDHOSTATTRIBUTES, tag = "modified_attributes" },
      { ndo_data = NDO.data.NDO_DATA_NEXTHOSTCHECK, tag = "next_check" },
      { ndo_data = NDO.data.NDO_DATA_NEXTHOSTNOTIFICATION, tag = "next_host_notification" },
      { ndo_data = NDO.data.NDO_DATA_NOMORENOTIFICATIONS, tag = "no_more_notifications" },
      { ndo_data = NDO.data.NDO_DATA_NOTIFICATIONSENABLED, tag = "notify" },
      { ndo_data = NDO.data.NDO_DATA_OBSESSOVERHOST, tag = "obsess_over_host" },
      { ndo_data = NDO.data.NDO_DATA_PASSIVEHOSTCHECKSENABLED, tag = "passive_checks" },
      { ndo_data = NDO.data.NDO_DATA_PERCENTSTATECHANGE, tag = "percent_state_change" },
      { ndo_data = NDO.data.NDO_DATA_PROBLEMHASBEENACKNOWLEDGED, tag = "acknowledged" },
      { ndo_data = NDO.data.NDO_DATA_PROCESSPERFORMANCEDATA, tag = "process_perfdata" },
      { ndo_data = NDO.data.NDO_DATA_RETRYCHECKINTERVAL, tag = "retry_interval" },
      { ndo_data = NDO.data.NDO_DATA_SCHEDULEDDOWNTIMEDEPTH, tag = "scheduled_downtime_depth" },
      { ndo_data = NDO.data.NDO_DATA_SHOULDBESCHEDULED, tag = "should_be_scheduled" },
      { ndo_data = NDO.data.NDO_DATA_STATETYPE, tag = "state_type" },
      { ndo_data = NDO.data.NDO_DATA_CHECKCOMMAND, tag = "check_command" },
      { ndo_data = NDO.data.NDO_DATA_OUTPUT, tag = "output" },
      { ndo_data = NDO.data.NDO_DATA_PERFDATA, tag = "perfdata" },
    }
  },
  [65551] = {
    id = 15,
    ndo_api_id = NDO.api.NDO_API_PROCESSDATA,
    key = {
      { ndo_data = NDO.data.NDO_DATA_STATE, tag = "engine" },
      { ndo_data = NDO.data.NDO_DATA_INSTANCE, tag = "instance_id" },
      { ndo_data = NDO.data.NDO_DATA_PROGRAMNAME, tag = "name" },
      { ndo_data = NDO.data.NDO_DATA_RUNTIME, tag = "running" },
      { ndo_data = NDO.data.NDO_DATA_PROCESSID, tag = "pid" },
      { ndo_data = NDO.data.NDO_DATA_ENDTIME, tag = "end_time" },
      { ndo_data = NDO.data.NDO_DATA_PROGRAMSTARTTIME, tag = "start_time" },
      { ndo_data = NDO.data.NDO_DATA_PROGRAMVERSION, tag = "version" },
    }
  },
  [65552] = {
    id = 16,
    ndo_api_id = NDO.api.NDO_API_PROGRAMSTATUSDATA,
    key = {
      { ndo_data = NDO.data.NDO_DATA_ACTIVEHOSTCHECKSENABLED, tag = "active_host_checks" },
      { ndo_data = NDO.data.NDO_DATA_ACTIVESERVICECHECKSENABLED, tag = "active_service_checks" },
      { ndo_data = NDO.data.NDO_DATA_HOSTADDRESS, tag = "address" },
      { ndo_data = NDO.data.NDO_DATA_HOSTFRESHNESSCHECKSENABLED, tag = "check_hosts_freshness" },
      { ndo_data = NDO.data.NDO_DATA_SERVICEFRESHNESSCHECKSENABLED, tag = "check_services_freshness" },
      { ndo_data = NDO.data.NDO_DATA_DAEMONMODE, tag = "daemon_mode" },
      { ndo_data = NDO.data.NDO_DATA_SERVICEDESCRIPTION, tag = "description" },
      { ndo_data = NDO.data.NDO_DATA_EVENTHANDLERENABLED, tag = "event_handlers" },
      { ndo_data = NDO.data.NDO_DATA_FAILUREPREDICTIONENABLED, tag = "failure_prediction" },
      { ndo_data = NDO.data.NDO_DATA_FLAPDETECTIONENABLED, tag = "flap_detection" },
      { ndo_data = NDO.data.NDO_DATA_INSTANCE, tag = "instance_id" },
      { ndo_data = NDO.data.NDO_DATA_LASTSTATE, tag = "last_alive" },
      { ndo_data = NDO.data.NDO_DATA_LASTCOMMANDCHECK, tag = "last_command_check" },
      { ndo_data = NDO.data.NDO_DATA_LASTLOGROTATION, tag = "last_log_rotation" },
      { ndo_data = NDO.data.NDO_DATA_MODIFIEDHOSTATTRIBUTES, tag = "modified_host_attributes" },
      { ndo_data = NDO.data.NDO_DATA_MODIFIEDSERVICEATTRIBUTES, tag = "modified_service_attributes" },
      { ndo_data = NDO.data.NDO_DATA_NOTIFICATIONSENABLED, tag = "notifications" },
      { ndo_data = NDO.data.NDO_DATA_OBSESSOVERHOST, tag = "obsess_over_hosts" },
      { ndo_data = NDO.data.NDO_DATA_OBSESSOVERSERVICE, tag = "obsess_over_services" },
      { ndo_data = NDO.data.NDO_DATA_PASSIVEHOSTCHECKSENABLED, tag = "passive_host_checks" },
      { ndo_data = NDO.data.NDO_DATA_PASSIVESERVICECHECKSENABLED, tag = "passive_service_checks" },
      { ndo_data = NDO.data.NDO_DATA_PROCESSPERFORMANCEDATA, tag = "process_perfdata" },
      { ndo_data = NDO.data.NDO_DATA_GLOBALHOSTEVENTHANDLER, tag = "global_host_event_handler" },
      { ndo_data = NDO.data.NDO_DATA_GLOBALSERVICEEVENTHANDLER, tag = "global_service_event_handler" },
    }
  },
  [65553] = {
    id = 17,
    ndo_api_id = NDO.api.NDO_API_COMMANDDEFINITION,
    key = {
      { ndo_data = 1, tag = "args" },
      { ndo_data = 2, tag = "filename" },
      { ndo_data = 3, tag = "instance_id" },
      { ndo_data = 4, tag = "loaded" },
      { ndo_data = 5, tag = "should_be_loaded" },
    }
  },
  [65554] = {
    id = 18,
    ndo_api_id = NDO.api.NDO_API_NOTIFICATIONDATA,
    key = {
      { ndo_data = NDO.data.NDO_DATA_CONTACTSNOTIFIED, tag = "contacts_notified" },
      { ndo_data = NDO.data.NDO_DATA_ENDTIME, tag = "end_time" },
      { ndo_data = NDO.data.NDO_DATA_ESCALATED, tag = "escalated" },
      { ndo_data = NDO.data.NDO_DATA_HOST, tag = "host_id" },
      { ndo_data = NDO.data.NDO_DATA_NOTIFICATIONTYPE, tag = "type" },
      { ndo_data = NDO.data.NDO_DATA_NOTIFICATIONREASON, tag = "reason_type" },
      { ndo_data = NDO.data.NDO_DATA_SERVICE, tag = "service_id" },
      { ndo_data = NDO.data.NDO_DATA_STARTTIME, tag = "start_time" },
      { ndo_data = NDO.data.NDO_DATA_STATE, tag = "state" },
      { ndo_data = NDO.data.NDO_DATA_ACKAUTHOR, tag = "ack_author" },
      { ndo_data = NDO.data.NDO_DATA_ACKDATA, tag = "ack_data" },
      { ndo_data = NDO.data.NDO_DATA_COMMANDNAME, tag = "command_name" },
      { ndo_data = NDO.data.NDO_DATA_CONTACTNAME, tag = "contact_name" },
      { ndo_data = NDO.data.NDO_DATA_OUTPUT, tag = "output" },
    }
  },
  [65555] = {
    id = 19,
    ndo_api_id = NDO.api.NDO_API_SERVICEDEFINITION,
    key = {
      { ndo_data = NDO.data.NDO_DATA_ACKNOWLEDGEMENTTYPE, tag = "acknowledgement_type" },
      { ndo_data = NDO.data.NDO_DATA_ACTIONURL, tag = "action_url" },
      { ndo_data = NDO.data.NDO_DATA_ACTIVESERVICECHECKSENABLED, tag = "active_checks" },
      { ndo_data = NDO.data.NDO_DATA_SERVICEFRESHNESSCHECKSENABLED, tag = "check_freshness" },
      { ndo_data = NDO.data.NDO_DATA_NORMALCHECKINTERVAL, tag = "check_interval" },
      { ndo_data = NDO.data.NDO_DATA_SERVICECHECKPERIOD, tag = "check_period" },
      { ndo_data = NDO.data.NDO_DATA_CHECKTYPE, tag = "check_type" },
      { ndo_data = NDO.data.NDO_DATA_CURRENTCHECKATTEMPT, tag = "check_attempt" },
      { ndo_data = NDO.data.NDO_DATA_CURRENTNOTIFICATIONNUMBER, tag = "notification_number" },
      { ndo_data = NDO.data.NDO_DATA_CURRENTSTATE, tag = "state" },
      { ndo_data = 0, tag = "default_active_checks" },
      { ndo_data = 0, tag = "default_event_handler_enabled" },
      { ndo_data = 0, tag = "default_failure_prediction" },
      { ndo_data = 0, tag = "default_flap_detection" },
      { ndo_data = 0, tag = "default_notify" },
      { ndo_data = 0, tag = "default_passive_checks" },
      { ndo_data = 0, tag = "default_process_perfdata" },
      { ndo_data = NDO.data.NDO_DATA_DISPLAYNAME, tag = "display_name" },
      { ndo_data = NDO.data.NDO_DATA_X3D, tag = "enabled" },
      { ndo_data = NDO.data.NDO_DATA_EVENTHANDLER, tag = "event_handler" },
      { ndo_data = NDO.data.NDO_DATA_EVENTHANDLERENABLED, tag = "event_handler_enabled" },
      { ndo_data = NDO.data.NDO_DATA_EXECUTIONTIME, tag = "execution_time" },
      { ndo_data = NDO.data.NDO_DATA_FAILUREPREDICTIONENABLED, tag = "failure_prediction" },
      { ndo_data = NDO.data.NDO_DATA_SERVICEFAILUREPREDICTIONOPTIONS, tag = "failure_prediction_options" },
      { ndo_data = NDO.data.NDO_DATA_FIRSTNOTIFICATIONDELAY, tag = "first_notification_delay" },
      { ndo_data = NDO.data.NDO_DATA_FLAPDETECTIONENABLED, tag = "flap_detection" },
      { ndo_data = NDO.data.NDO_DATA_FLAPDETECTIONONCRITICAL, tag = "flap_detection_on_critical" },
      { ndo_data = NDO.data.NDO_DATA_FLAPDETECTIONONOK, tag = "flap_detection_on_ok" },
      { ndo_data = NDO.data.NDO_DATA_FLAPDETECTIONONUNKNOWN, tag = "flap_detection_on_unknown" },
      { ndo_data = NDO.data.NDO_DATA_FLAPDETECTIONONWARNING, tag = "flap_detection_on_warning" },
      { ndo_data = NDO.data.NDO_DATA_SERVICEFRESHNESSTHRESHOLD, tag = "freshness_threshold" },
      { ndo_data = NDO.data.NDO_DATA_HASBEENCHECKED, tag = "checked" },
      { ndo_data = NDO.data.NDO_DATA_HIGHSERVICEFLAPTHRESHOLD, tag = "high_flap_threshold" },
      { ndo_data = NDO.data.NDO_DATA_HOST, tag = "host_id" },
      { ndo_data = NDO.data.NDO_DATA_ICONIMAGE, tag = "icon_image" },
      { ndo_data = NDO.data.NDO_DATA_ICONIMAGEALT, tag = "icon_image_alt" },
      { ndo_data = NDO.data.NDO_DATA_SERVICE, tag = "service_id" },
      { ndo_data = NDO.data.NDO_DATA_ISFLAPPING, tag = "flapping" },
      { ndo_data = NDO.data.NDO_DATA_SERVICEISVOLATILE, tag = "volatile" },
      { ndo_data = NDO.data.NDO_DATA_LASTSERVICECHECK, tag = "last_check" },
      { ndo_data = NDO.data.NDO_DATA_LASTHARDSTATE, tag = "last_hard_state" },
      { ndo_data = NDO.data.NDO_DATA_LASTHARDSTATECHANGE, tag = "last_hard_state_change" },
      { ndo_data = NDO.data.NDO_DATA_LASTSERVICENOTIFICATION, tag = "last_notification" },
      { ndo_data = NDO.data.NDO_DATA_LASTSTATECHANGE, tag = "last_state_change" },
      { ndo_data = NDO.data.NDO_DATA_LASTTIMECRITICAL, tag = "last_time_critical" },
      { ndo_data = NDO.data.NDO_DATA_LASTTIMEOK, tag = "last_time_ok" },
      { ndo_data = NDO.data.NDO_DATA_LASTTIMEUNKNOWN, tag = "last_time_unknown" },
      { ndo_data = NDO.data.NDO_DATA_LASTTIMEWARNING, tag = "last_time_warning" },
      { ndo_data = NDO.data.NDO_DATA_LASTUPDATE, tag = "last_update" },
      { ndo_data = NDO.data.NDO_DATA_LATENCY, tag = "latency" },
      { ndo_data = NDO.data.NDO_DATA_LOWSERVICEFLAPTHRESHOLD, tag = "low_flap_threshold" },
      { ndo_data = NDO.data.NDO_DATA_MAXCHECKATTEMPTS, tag = "max_check_attempts" },
      { ndo_data = NDO.data.NDO_DATA_MODIFIEDSERVICEATTRIBUTES, tag = "modified_attributes" },
      { ndo_data = NDO.data.NDO_DATA_NEXTSERVICECHECK, tag = "next_check" },
      { ndo_data = NDO.data.NDO_DATA_NEXTSERVICENOTIFICATION, tag = "next_notification" },
      { ndo_data = NDO.data.NDO_DATA_NOMORENOTIFICATIONS, tag = "no_more_notifications" },
      { ndo_data = NDO.data.NDO_DATA_NOTES, tag = "notes" },
      { ndo_data = NDO.data.NDO_DATA_NOTESURL, tag = "notes_url" },
      { ndo_data = NDO.data.NDO_DATA_SERVICENOTIFICATIONINTERVAL, tag = "notification_interval" },
      { ndo_data = NDO.data.NDO_DATA_SERVICENOTIFICATIONPERIOD, tag = "notification_period" },
      { ndo_data = NDO.data.NDO_DATA_NOTIFICATIONSENABLED, tag = "notify" },
      { ndo_data = NDO.data.NDO_DATA_NOTIFYSERVICECRITICAL, tag = "notify_on_critical" },
      { ndo_data = NDO.data.NDO_DATA_NOTIFYSERVICEDOWNTIME, tag = "notify_on_downtime" },
      { ndo_data = NDO.data.NDO_DATA_NOTIFYSERVICEFLAPPING, tag = "notify_on_flapping" },
      { ndo_data = NDO.data.NDO_DATA_NOTIFYSERVICERECOVERY, tag = "notify_on_recovery" },
      { ndo_data = NDO.data.NDO_DATA_NOTIFYSERVICEUNKNOWN, tag = "notify_on_unknown" },
      { ndo_data = NDO.data.NDO_DATA_NOTIFYSERVICEWARNING, tag = "notify_on_warning" },
      { ndo_data = NDO.data.NDO_DATA_OBSESSOVERSERVICE, tag = "obsess_over_service" },
      { ndo_data = NDO.data.NDO_DATA_PASSIVESERVICECHECKSENABLED, tag = "passive_checks" },
      { ndo_data = NDO.data.NDO_DATA_PERCENTSTATECHANGE, tag = "percent_state_change" },
      { ndo_data = NDO.data.NDO_DATA_PROBLEMHASBEENACKNOWLEDGED, tag = "acknowledged" },
      { ndo_data = NDO.data.NDO_DATA_PROCESSPERFORMANCEDATA, tag = "process_perfdata" },
      { ndo_data = NDO.data.NDO_DATA_RETAINSERVICENONSTATUSINFORMATION, tag = "retain_nonstatus_information" },
      { ndo_data = NDO.data.NDO_DATA_RETAINSERVICESTATUSINFORMATION, tag = "retain_status_information" },
      { ndo_data = NDO.data.NDO_DATA_RETRYCHECKINTERVAL, tag = "retry_interval" },
      { ndo_data = NDO.data.NDO_DATA_SCHEDULEDDOWNTIMEDEPTH, tag = "scheduled_downtime_depth" },
      { ndo_data = NDO.data.NDO_DATA_SERVICEDESCRIPTION, tag = "description" },
      { ndo_data = NDO.data.NDO_DATA_SHOULDBESCHEDULED, tag = "should_be_scheduled" },
      { ndo_data = NDO.data.NDO_DATA_STALKSERVICEONCRITICAL, tag = "stalk_on_critical" },
      { ndo_data = NDO.data.NDO_DATA_STALKSERVICEONOK, tag = "stalk_on_ok" },
      { ndo_data = NDO.data.NDO_DATA_STALKSERVICEONUNKNOWN, tag = "stalk_on_unknown" },
      { ndo_data = NDO.data.NDO_DATA_STALKSERVICEONWARNING, tag = "stalk_on_warning" },
      { ndo_data = NDO.data.NDO_DATA_STATETYPE, tag = "state_type" },
      { ndo_data = NDO.data.NDO_DATA_CHECKCOMMAND, tag = "check_command" },
      { ndo_data = NDO.data.NDO_DATA_OUTPUT, tag = "output" },
      { ndo_data = NDO.data.NDO_DATA_PERFDATA, tag = "perfdata" },
    }
  },
  [65556] = {
    id = 20,
    ndo_api_id = NDO.api.NDO_API_SERVICECHECKDATA,
    key = {
      { ndo_data = NDO.data.NDO_DATA_HOST, tag = "host_id" },
      { ndo_data = NDO.data.NDO_DATA_SERVICE, tag = "service_id" },
      { ndo_data = NDO.data.NDO_DATA_COMMANDLINE, tag = "command_line" },
    }
  },
  [65557] = {
    id = 21,
    ndo_api_id = NDO.api.NDO_API_SERVICEDEPENDENCYDEFINITION,
    key = {
      { ndo_data = NDO.data.NDO_DATA_DEPENDENCYPERIOD, tag = "dependency_period" },
      { ndo_data = NDO.data.NDO_DATA_DEPENDENTHOSTNAME, tag = "dependent_host_id" },
      { ndo_data = NDO.data.NDO_DATA_DEPENDENTSERVICEDESCRIPTION, tag = "dependent_service_id" },
      { ndo_data = NDO.data.NDO_DATA_SERVICEFAILUREPREDICTIONOPTIONS, tag = "execution_failure_options" },
      { ndo_data = NDO.data.NDO_DATA_HOST, tag = "host_id" },
      { ndo_data = NDO.data.NDO_DATA_INHERITSPARENT, tag = "inherits_parent" },
      { ndo_data = NDO.data.NDO_DATA_SERVICENOTIFICATIONCOMMAND, tag = "notification_failure_options" },
      { ndo_data = NDO.data.NDO_DATA_SERVICE, tag = "service_id" },
    }
  },
  [65558] = {
    id = 22,
    ndo_api_id = NDO.api.NDO_API_SERVICEGROUPDEFINITION,
    key = {
      { ndo_data = NDO.data.NDO_DATA_INSTANCE, tag = "name" },
      { ndo_data = NDO.data.NDO_DATA_SERVICEID, tag = "servicegroup_id" },
    }
  },
  [65559] = {
    id = 23,
    ndo_api_id = NDO.api.NDO_API_SERVICEGROUPMEMBERDEFINITION,
    key = {
      { ndo_data = NDO.data.NDO_DATA_SERVICEGROUPNAME, tag = "servicegroup_id" },
      { ndo_data = NDO.data.NDO_DATA_HOST, tag = "host_id" },
      { ndo_data = NDO.data.NDO_DATA_INSTANCE, tag = "service_id" },
    }
  },
  [65560] = {
    id = 24,
    ndo_api_id = NDO.api.NDO_API_SERVICESTATUSDATA,
    key = {
      { ndo_data = NDO.data.NDO_DATA_PASSIVESERVICECHECKSENABLED, tag = "passive_checks" },
      { ndo_data = NDO.data.NDO_DATA_PERCENTSTATECHANGE, tag = "percent_state_change" },
      { ndo_data = NDO.data.NDO_DATA_PERFDATA, tag = "perfdata" },
      { ndo_data = NDO.data.NDO_DATA_PROBLEMHASBEENACKNOWLEDGED, tag = "acknowledged" },
      { ndo_data = NDO.data.NDO_DATA_PROCESSPERFORMANCEDATA, tag = "process_perfdata" },
      { ndo_data = NDO.data.NDO_DATA_ACKNOWLEDGEMENTTYPE, tag = "acknowledgement_type" },
      { ndo_data = NDO.data.NDO_DATA_ACTIVESERVICECHECKSENABLED, tag = "active_checks" },
      { ndo_data = NDO.data.NDO_DATA_CHECKCOMMAND, tag = "check_command" },
      { ndo_data = NDO.data.NDO_DATA_RETRYCHECKINTERVAL, tag = "retry_interval" },
      { ndo_data = NDO.data.NDO_DATA_CHECKTYPE, tag = "check_type" },
      { ndo_data = NDO.data.NDO_DATA_SERVICECHECKPERIOD, tag = "check_period" },
      { ndo_data = NDO.data.NDO_DATA_SERVICEDESCRIPTION, tag = "service_description" },
      { ndo_data = NDO.data.NDO_DATA_SCHEDULEDDOWNTIMEDEPTH, tag = "scheduled_downtime_depth" },
      { ndo_data = NDO.data.NDO_DATA_SERVICE, tag = "service_id" },
      { ndo_data = NDO.data.NDO_DATA_SHOULDBESCHEDULED, tag = "should_be_scheduled" },
      { ndo_data = NDO.data.NDO_DATA_STATETYPE, tag = "state_type" },
      { ndo_data = NDO.data.NDO_DATA_CURRENTCHECKATTEMPT, tag = "check_attempt" },
      { ndo_data = NDO.data.NDO_DATA_CURRENTNOTIFICATIONNUMBER, tag = "notification_number" },
      { ndo_data = NDO.data.NDO_DATA_CURRENTSTATE, tag = "state" },
      { ndo_data = NDO.data.NDO_DATA_EVENTHANDLER, tag = "event_handler" },
      { ndo_data = NDO.data.NDO_DATA_EVENTHANDLERENABLED, tag = "event_handler_enabled" },
      { ndo_data = NDO.data.NDO_DATA_EXECUTIONTIME, tag = "execution_time" },
      { ndo_data = NDO.data.NDO_DATA_FAILUREPREDICTIONENABLED, tag = "failure_prediction" },
      { ndo_data = NDO.data.NDO_DATA_X3D, tag = "enabled" },
      { ndo_data = NDO.data.NDO_DATA_FLAPDETECTIONENABLED, tag = "flap_detection" },
      { ndo_data = NDO.data.NDO_DATA_HASBEENCHECKED, tag = "checked" },
      { ndo_data = NDO.data.NDO_DATA_HOST, tag = "host_id" },
      { ndo_data = NDO.data.NDO_DATA_ISFLAPPING, tag = "flapping" },
      { ndo_data = NDO.data.NDO_DATA_LASTHARDSTATE, tag = "last_hard_state" },
      { ndo_data = NDO.data.NDO_DATA_LASTHARDSTATECHANGE, tag = "last_hard_state_change" },
      { ndo_data = NDO.data.NDO_DATA_LASTSERVICECHECK, tag = "last_check" },
      { ndo_data = NDO.data.NDO_DATA_LASTSERVICENOTIFICATION, tag = "last_notification" },
      { ndo_data = NDO.data.NDO_DATA_LASTSTATECHANGE, tag = "last_state_change" },
      { ndo_data = NDO.data.NDO_DATA_LASTTIMECRITICAL, tag = "last_time_critical" },
      { ndo_data = NDO.data.NDO_DATA_LASTTIMEOK, tag = "last_time_ok" },
      { ndo_data = NDO.data.NDO_DATA_LASTTIMEUNKNOWN, tag = "last_time_unknown" },
      { ndo_data = NDO.data.NDO_DATA_LASTTIMEWARNING, tag = "last_time_warning" },
      { ndo_data = NDO.data.NDO_DATA_LATENCY, tag = "latency" },
      { ndo_data = NDO.data.NDO_DATA_INSTANCE, tag = "instance_id" },
      { ndo_data = NDO.data.NDO_DATA_HOSTID, tag = "hostname" },
      { ndo_data = NDO.data.NDO_DATA_LASTUPDATE, tag = "last_update" },
      { ndo_data = NDO.data.NDO_DATA_MAXCHECKATTEMPTS, tag = "max_check_attempts" },
      { ndo_data = NDO.data.NDO_DATA_MODIFIEDSERVICEATTRIBUTES, tag = "modified_attributes" },
      { ndo_data = NDO.data.NDO_DATA_NEXTSERVICECHECK, tag = "next_check" },
      { ndo_data = NDO.data.NDO_DATA_NEXTSERVICENOTIFICATION, tag = "next_notification" },
      { ndo_data = NDO.data.NDO_DATA_NOMORENOTIFICATIONS, tag = "no_more_notifications" },
      { ndo_data = NDO.data.NDO_DATA_NORMALCHECKINTERVAL, tag = "check_interval" },
      { ndo_data = NDO.data.NDO_DATA_NOTIFICATIONSENABLED, tag = "notify" },
      { ndo_data = NDO.data.NDO_DATA_OBSESSOVERSERVICE, tag = "obsess_over_service" },
      { ndo_data = NDO.data.NDO_DATA_OUTPUT, tag = "output" }
    }
  }
}

local function join(tab)
  table.sort(tab)

end

local custom_output = {
  hostname = function (ndo_data, d)
    return ndo_data .. "=" .. tostring(broker_cache:get_hostname(d.host_id)) .. "\n"
  end,
  process_perfdata = function (ndo_data, d)
    return ndo_data .. "=1\n"
  end,
  service_description = function (ndo_data, d)
    return ndo_data .. "=" .. tostring(broker_cache:get_service_description(d.host_id, d.service_id)) .. "\n"
  end,
  default = function (ndo_data, d)
    return ndo_data .. "=0\n"
  end,
}

-- Obsolete things and some initializations
custom_output.last_notification = custom_output.default
custom_output.last_time_ok = custom_output.default
custom_output.last_time_warning = custom_output.default
custom_output.last_time_critical = custom_output.default
custom_output.last_time_unknown = custom_output.default
custom_output.next_notification = custom_output.default
custom_output.modified_attributes = custom_output.default
custom_output.failure_prediction = custom_output.default
custom_output.instance_id = custom_output.default

local function get_ndo_msg(d)
  local t = d.type
  if ndo[t] then
    local output = "\n" .. ndo[t].ndo_api_id .. ":\n"
    local key = ndo[t].key
    for i,v in ipairs(key) do
      if d[v.tag] ~= nil then
        local value = d[v.tag]
        if type(value) == "boolean" then
          if value then value = "1" else value = "0" end
        end
        value = tostring(value):gsub("\n", "\\n")
        output = output .. v.ndo_data .. "=" .. tostring(value) .. "\n"
      else
        if custom_output[v.tag] then
          output = output .. custom_output[v.tag](v.ndo_data, d)
        else
          output = output .. tostring(v.ndo_data) .. "(index=" .. i .. ") =UNKNOWN (" .. v.tag .. ")\n"
          broker_log:warning(1, "The event does not contain an item " .. v.tag)
        end
      end
    end
    output = output .. NDO.api.NDO_API_ENDDATA .. "\n\n"
    return output
  else
    return nil
  end
end

local data = {
  max_row   = 1,
  rows      = {}
}

local function connect()
  data.socket, err = socket.connect(data.ipaddr, data.port)
  if not data.socket then
    local msg = "Unable to establish connection on server " .. data.ipaddr .. ":" .. data.port .. ": " .. err
    broker_log:error(1, msg)
  end
end

--------------------------------------------------------------------------------
--  Initialization of the module
--  @param conf A table containing data entered by the user through the GUI
--------------------------------------------------------------------------------
function init(conf)
  -- broker_ndo initialization
  broker_log:set_parameters(1, '/var/log/centreon-broker/ndo-output.log')
  if conf['ipaddr'] and conf['ipaddr'] ~= "" then
    data.ipaddr = conf['ipaddr']
  else
    error("Unable to find the 'ipaddr' value of type 'string'")
  end

  if conf['port'] and conf['port'] ~= "" then
    data.port = conf['port']
  else
    error("Unable to find the 'port' value of type 'number'")
  end

  if conf['max-row'] then
    data.max_row = conf['max-row']
  else
    error("Unable to find the 'max-row' value of type 'number'")
  end
  connect()
end

--------------------------------------------------------------------------------
--  Called when the data limit count is reached.
--------------------------------------------------------------------------------
local function flush()
  if #data.rows > 0 then
    if not data.socket then
      connect()
    end
    if data.socket then
      for k,v in ipairs(data.rows) do
        local msg = get_ndo_msg(v)
        if msg then
          local l, err = data.socket:send(msg)
          if not l then
            broker_log:error(2, "Unable to send data to socket :" .. err)
            data.socket = nil
          end
        else
          broker_log:info(1, "Unable to write event of cat " .. v.category .. " elem " .. v.element)
        end
      end
      data.rows = {}
    end
  end
  return true
end

--------------------------------------------------------------------------------
--  Function attached to the write event.
--------------------------------------------------------------------------------
function write(d)
  if d.category ~= 1 or d.element ~= 24 then
    return true
  end
  data.rows[#data.rows + 1] = d

  if #data.rows >= data.max_row then
    return flush()
  end
  return true
end
