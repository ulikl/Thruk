/*******************************************************************************
 * DOCS:
 *   - https://www.icinga.com/docs/icinga2/latest/doc/09-object-types/#objecttype-idomysqlconnection
 *   - https://www.icinga.com/docs/icinga1/latest/en/db_model.html
 *   - https://www.icinga.com/docs/icinga2/latest/doc/24-appendix/#db-ido-schema
 *
 * ISSUES:
 *   - missing timeperiod changes
 *   - missing initial states
 *   - missing command names in notifications (maybe an icinga2 issue)
 ******************************************************************************/

SELECT log FROM (
SELECT time, log FROM (

/*******************************************************************************
 * SERVICE ALERT
 * [123456] SERVICE ALERT: Company App;Application Server;OK;SOFT;3;OK - 0 business processes updated in 0.00s
 */
(
    SELECT
    s.state_time as time,
    CONCAT('[', UNIX_TIMESTAMP(s.state_time), '] SERVICE ALERT: ',
    CONVERT(CAST(os.name1 as BINARY) USING utf8), ';',
    CONVERT(CAST(os.name2 as BINARY) USING utf8), ';',
    CASE
        WHEN s.state = 0 THEN 'OK'
        WHEN s.state = 1 THEN 'WARNING'
        WHEN s.state = 2 THEN 'CRITICAL'
        WHEN s.state = 3 THEN 'UNKNOWN'
    END, ';',
    CASE
        WHEN s.state_type = 0 THEN 'SOFT'
        WHEN s.state_type = 1 THEN 'HARD'
    END, ';',
    s.current_check_attempt, ';',
    CONVERT(CAST(s.output as BINARY) USING utf8)
    ) as log
    FROM
    icinga_statehistory s
    JOIN icinga_objects os ON s.instance_id = os.instance_id AND s.object_id = os.object_id
    WHERE
      s.state_time >= FROM_UNIXTIME($TIME_START)
      AND s.state_time <= FROM_UNIXTIME($TIME_END)
      AND s.instance_id = $INSTANCE_ID
      AND os.objecttype_id = 2
    ORDER BY time asc
    $LIMIT
)

/*******************************************************************************
 * HOST ALERT
 * [123456] HOST ALERT: Company App;UP;SOFT;3;OK - 0 business processes updated in 0.00s
 */
UNION ALL (
    SELECT
    s.state_time as time,
    CONCAT('[', UNIX_TIMESTAMP(s.state_time), '] HOST ALERT: ',
    CONVERT(CAST(os.name1 as BINARY) USING utf8), ';',
    CASE
        WHEN s.state = 0 THEN 'UP'
        WHEN s.state = 1 THEN 'DOWN'
        WHEN s.state = 2 THEN 'UNREACHABLE'
    END, ';',
    CASE
        WHEN s.state_type = 0 THEN 'SOFT'
        WHEN s.state_type = 1 THEN 'HARD'
    END, ';',
    s.current_check_attempt, ';',
    CONVERT(CAST(s.output as BINARY) USING utf8)
    ) as log
    FROM
    icinga_statehistory s
    JOIN icinga_objects os ON s.instance_id = os.instance_id AND s.object_id = os.object_id
    WHERE
      s.state_time >= FROM_UNIXTIME($TIME_START)
      AND s.state_time <= FROM_UNIXTIME($TIME_END)
      AND s.instance_id = $INSTANCE_ID
      AND os.objecttype_id = 1
    ORDER BY time asc
    $LIMIT
)

/*******************************************************************************
 * SERVICE NOTIFICATION
 * [123456] SERVICE NOTIFICATION: admin;naemon0;users;WARNING;notify-by-mail;USERS WARNING - 7 users currently logged in
 */
UNION ALL (
    SELECT
    n.start_time as time,
    CONCAT('[', UNIX_TIMESTAMP(c.start_time), '] SERVICE NOTIFICATION: ',
    CONVERT(CAST(oc.name1 as BINARY) USING utf8), ';',
    CONVERT(CAST(os.name1 as BINARY) USING utf8), ';',
    CONVERT(CAST(os.name2 as BINARY) USING utf8), ';',
    CASE
        WHEN n.notification_reason = 0 THEN
        CASE
            WHEN n.state = 0 THEN 'RECOVERY'
            WHEN n.state = 1 THEN 'WARNING'
            WHEN n.state = 2 THEN 'CRITICAL'
            WHEN n.state = 3 THEN 'UNKNOWN'
        END
        WHEN n.notification_reason = 1 THEN
        CASE
            WHEN n.state = 1 THEN 'ACKNOWLEDGEMENT (WARNING)'
            WHEN n.state = 2 THEN 'ACKNOWLEDGEMENT (CRITICAL)'
            WHEN n.state = 3 THEN 'ACKNOWLEDGEMENT (UNKNOWN)'
        END
        WHEN n.notification_reason = 2 THEN
        CASE
            WHEN n.state = 0 THEN 'FLAPPINGSTART (OK)'
            WHEN n.state = 1 THEN 'FLAPPINGSTART (WARNING)'
            WHEN n.state = 2 THEN 'FLAPPINGSTART (CRITICAL)'
            WHEN n.state = 3 THEN 'FLAPPINGSTART (UNKNOWN)'
        END
        WHEN n.notification_reason = 3 THEN
        CASE
            WHEN n.state = 0 THEN 'FLAPPINGSTOP (OK)'
            WHEN n.state = 1 THEN 'FLAPPINGSTOP (WARNING)'
            WHEN n.state = 2 THEN 'FLAPPINGSTOP (CRITICAL)'
            WHEN n.state = 3 THEN 'FLAPPINGSTOP (UNKNOWN)'
        END
        WHEN n.notification_reason = 5 THEN
        CASE
            WHEN n.state = 0 THEN 'DOWNTIMESTART'
            WHEN n.state = 1 THEN 'DOWNTIMESTART (WARNING)'
            WHEN n.state = 2 THEN 'DOWNTIMESTART (CRITICAL)'
            WHEN n.state = 3 THEN 'DOWNTIMESTART (UNKNOWN)'
        END
        WHEN n.notification_reason = 6 OR n.notification_reason = 7 THEN
        CASE
            WHEN n.state = 0 THEN 'DOWNTIMEEND'
            WHEN n.state = 1 THEN 'DOWNTIMEEND (WARNING)'
            WHEN n.state = 2 THEN 'DOWNTIMEEND (CRITICAL)'
            WHEN n.state = 3 THEN 'DOWNTIMEEND (UNKNOWN)'
        END
        WHEN n.notification_reason = 99 THEN
        CASE
            WHEN n.state = 0 THEN 'CUSTOM (OK)'
            WHEN n.state = 1 THEN 'CUSTOM (WARNING)'
            WHEN n.state = 2 THEN 'CUSTOM (CRITICAL)'
            WHEN n.state = 3 THEN 'CUSTOM (UNKNOWN)'
        END
    END, ';',
    /* notification command seems to be NULL in icinga2 */
    COALESCE(occ.name1, ''), ';',
    CONVERT(CAST(n.output as BINARY) USING utf8)
    ) as log
    FROM
    icinga_contactnotifications c
    JOIN icinga_notifications n ON c.instance_id = n.instance_id AND c.notification_id = n.notification_id
    JOIN icinga_objects oc ON c.instance_id = oc.instance_id AND c.contact_object_id = oc.object_id
    JOIN icinga_objects os ON n.instance_id = os.instance_id AND n.object_id = os.object_id
    LEFT JOIN icinga_contactnotificationmethods cn ON cn.instance_id = c.instance_id AND cn.contactnotification_id = c.contactnotification_id
    LEFT JOIN icinga_objects occ ON cn.instance_id = occ.instance_id AND cn.command_object_id = occ.object_id
    WHERE
      n.start_time >= FROM_UNIXTIME($TIME_START)
      AND n.start_time <= FROM_UNIXTIME($TIME_END)
      AND c.instance_id = $INSTANCE_ID
      AND os.objecttype_id = 2
    ORDER BY time asc
    $LIMIT
)

/*******************************************************************************
 * HOST NOTIFICATION
 * [123456] HOST NOTIFICATION: admin;naemon0;UP;notify-by-mail;USERS WARNING - 7 users currently logged in
 */
UNION ALL (
    SELECT
    n.start_time as time,
    CONCAT('[', UNIX_TIMESTAMP(c.start_time), '] HOST NOTIFICATION: ',
    CONVERT(CAST(oc.name1 as BINARY) USING utf8), ';',
    CONVERT(CAST(oh.name1 as BINARY) USING utf8), ';',
    CASE
        WHEN n.notification_reason = 0 THEN
        CASE
            WHEN n.state = 0 THEN 'RECOVERY'
            WHEN n.state = 1 THEN 'DOWN'
            WHEN n.state = 2 THEN 'UNREACHABLE'
            ELSE n.state
        END
        WHEN n.notification_reason = 1 THEN
        CASE
            WHEN n.state = 1 THEN 'ACKNOWLEDGEMENT (DOWN)'
            WHEN n.state = 2 THEN 'ACKNOWLEDGEMENT (UNREACHABLE)'
        END
        WHEN n.notification_reason = 2 THEN
        CASE
            WHEN n.state = 0 THEN 'FLAPPINGSTART (UP)'
            WHEN n.state = 1 THEN 'FLAPPINGSTART (DOWN)'
            WHEN n.state = 2 THEN 'FLAPPINGSTART (UNREACHABLE)'
        END
        WHEN n.notification_reason = 3 THEN
        CASE
            WHEN n.state = 0 THEN 'FLAPPINGSTOP (UP)'
            WHEN n.state = 1 THEN 'FLAPPINGSTOP (DOWN)'
            WHEN n.state = 2 THEN 'FLAPPINGSTOP (UNREACHABLE)'
        END
        WHEN n.notification_reason = 5 THEN
        CASE
            WHEN n.state = 0 THEN 'DOWNTIMESTART (UP)'
            WHEN n.state = 1 THEN 'DOWNTIMESTART (DOWN)'
            WHEN n.state = 2 THEN 'DOWNTIMESTART (UNREACHABLE)'
        END
        WHEN n.notification_reason = 6 OR n.notification_reason = 7 THEN
        CASE
            WHEN n.state = 0 THEN 'DOWNTIMEEND (UP)'
            WHEN n.state = 1 THEN 'DOWNTIMEEND (DOWN)'
            WHEN n.state = 2 THEN 'DOWNTIMEEND (UNREACHABLE)'
        END
        WHEN n.notification_reason = 99 THEN
        CASE
            WHEN n.state = 0 THEN 'CUSTOM (UP)'
            WHEN n.state = 1 THEN 'CUSTOM (DOWN)'
            WHEN n.state = 2 THEN 'CUSTOM (UNREACHABLE)'
        END
    END, ';',
    /* notification command seems to be NULL in icinga2 */
    COALESCE(occ.name1, ''), ';',
    CONVERT(CAST(n.output as BINARY) USING utf8)
    ) as log
    FROM
    icinga_contactnotifications c
    JOIN icinga_notifications n ON c.instance_id = n.instance_id AND c.notification_id = n.notification_id
    JOIN icinga_objects oc ON c.instance_id = oc.instance_id AND c.contact_object_id = oc.object_id
    JOIN icinga_objects oh ON n.instance_id = oh.instance_id AND n.object_id = oh.object_id
    LEFT JOIN icinga_contactnotificationmethods cn ON cn.instance_id = c.instance_id AND cn.contactnotification_id = c.contactnotification_id
    LEFT JOIN icinga_objects occ ON cn.instance_id = occ.instance_id AND cn.command_object_id = occ.object_id
    WHERE
      n.start_time >= FROM_UNIXTIME($TIME_START)
      AND n.start_time <= FROM_UNIXTIME($TIME_END)
      AND c.instance_id = $INSTANCE_ID
      AND oh.objecttype_id = 1
    ORDER BY time asc
    $LIMIT
)

/*******************************************************************************
 * EXTERNAL COMMANDS
 * [123456] EXTERNAL COMMAND: ADD_SVC_COMMENT;host;ping6;1;thrukadmin;blah
 */
UNION ALL (
    SELECT
    e.entry_time as time,
    CONCAT('[', UNIX_TIMESTAMP(e.entry_time), '] EXTERNAL COMMAND: ',
    e.command_name, ';',
    e.command_args
    ) as log
    FROM
    icinga_externalcommands e
    WHERE
      e.entry_time >= FROM_UNIXTIME($TIME_START)
      AND e.entry_time <= FROM_UNIXTIME($TIME_END)
      AND e.instance_id = $INSTANCE_ID
    ORDER BY time asc
    $LIMIT
)

/*******************************************************************************
 * HOST DOWNTIME ALERT START
 * [123456] HOST DOWNTIME ALERT: host;STARTED; Checkable has entered a period of scheduled downtime.
 */
UNION ALL (
    SELECT
    d.actual_start_time as time,
    CONCAT('[', UNIX_TIMESTAMP(d.actual_start_time), '] HOST DOWNTIME ALERT: ',
    CONVERT(CAST(oh.name1 as BINARY) USING utf8), ';',
    'STARTED; Checkable has entered a period of scheduled downtime.'
    ) as log
    FROM
    icinga_downtimehistory d
    JOIN icinga_objects oh ON d.instance_id = oh.instance_id AND d.object_id = oh.object_id
    WHERE
      d.actual_start_time >= FROM_UNIXTIME($TIME_START)
      AND d.actual_start_time <= FROM_UNIXTIME($TIME_END)
      AND d.instance_id = $INSTANCE_ID
      AND d.downtime_type = 2
      AND d.was_started = 1
    ORDER BY time asc
    $LIMIT
)

/*******************************************************************************
 * HOST DOWNTIME ALERT END
 * [123456] HOST DOWNTIME ALERT: host;CANCELLED; Scheduled downtime for host has been cancelled.
 */
UNION ALL (
    SELECT
    d.actual_end_time as time,
    CONCAT('[', UNIX_TIMESTAMP(d.actual_end_time), '] HOST DOWNTIME ALERT: ',
    CONVERT(CAST(oh.name1 as BINARY) USING utf8), ';',
    CASE
       WHEN was_cancelled = 0 THEN 'STOPPED; Checkable has exited from a period of scheduled downtime.'
       WHEN was_cancelled = 1 THEN 'CANCELLED; Scheduled downtime for host has been cancelled.'
    END
    ) as log
    FROM
    icinga_downtimehistory d
    JOIN icinga_objects oh ON d.instance_id = oh.instance_id AND d.object_id = oh.object_id
    WHERE
      d.actual_end_time >= FROM_UNIXTIME($TIME_START)
      AND d.actual_end_time <= FROM_UNIXTIME($TIME_END)
      AND d.instance_id = $INSTANCE_ID
      AND d.downtime_type = 2
      AND d.was_started = 1
    ORDER BY time asc
    $LIMIT
)

/*******************************************************************************
 * SERVICE DOWNTIME ALERT START
 * [123456] SERVICE DOWNTIME ALERT: host;http;STARTED; Checkable has entered a period of scheduled downtime.
 */
UNION ALL (
    SELECT
    d.actual_start_time as time,
    CONCAT('[', UNIX_TIMESTAMP(d.actual_start_time), '] SERVICE DOWNTIME ALERT: ',
    CONVERT(CAST(os.name1 as BINARY) USING utf8), ';',
    CONVERT(CAST(os.name2 as BINARY) USING utf8), ';',
    'STARTED; Checkable has entered a period of scheduled downtime.'
    ) as log
    FROM
    icinga_downtimehistory d
    JOIN icinga_objects os ON d.instance_id = os.instance_id AND d.object_id = os.object_id
    WHERE
      d.actual_start_time >= FROM_UNIXTIME($TIME_START)
      AND d.actual_start_time <= FROM_UNIXTIME($TIME_END)
      AND d.instance_id = $INSTANCE_ID
      AND d.downtime_type = 1
      AND d.was_started = 1
    ORDER BY time asc
    $LIMIT
)

/*******************************************************************************
 * SERVICE DOWNTIME ALERT END
 * [123456] SERVICE DOWNTIME ALERT: host;http;CANCELLED; Scheduled downtime for service has been cancelled.
 */
UNION ALL (
    SELECT
    d.actual_end_time as time,
    CONCAT('[', UNIX_TIMESTAMP(d.actual_end_time), '] SERVICE DOWNTIME ALERT: ',
    CONVERT(CAST(os.name1 as BINARY) USING utf8), ';',
    CONVERT(CAST(os.name2 as BINARY) USING utf8), ';',
    CASE
       WHEN was_cancelled = 0 THEN 'STOPPED; Checkable has exited from a period of scheduled downtime.'
       WHEN was_cancelled = 1 THEN 'CANCELLED; Scheduled downtime for service has been cancelled.'
    END
    ) as log
    FROM
    icinga_downtimehistory d
    JOIN icinga_objects os ON d.instance_id = os.instance_id AND d.object_id = os.object_id
    WHERE
      d.actual_end_time >= FROM_UNIXTIME($TIME_START)
      AND d.actual_end_time <= FROM_UNIXTIME($TIME_END)
      AND d.instance_id = $INSTANCE_ID
      AND d.downtime_type = 1
      AND d.was_started = 1
    ORDER BY time asc
    $LIMIT
)

) as sublog
ORDER BY time asc
$LIMIT
) as log
;
