class_name IncidentLibrary
extends RefCounted
## Data-driven incident definitions. Add a new incident = add a dictionary here.
## severity: 0 Minor, 1 Moderate, 2 Severe, 3 Extreme, 4 Narrative.
## pick: how to choose the main employee when none is supplied: "highest_stress" | "working" | "none"
## pause: if true the sim pauses (INCIDENT_RESPONSE) until the player answers or dismisses.
## duration: sim minutes before the incident expires and the "ignore" effects apply.
## Effect shapes (see IncidentManager._apply_effects):
##   {"t":"need","who":"emp|other|both|room_occupants|all_staff","key":..,"delta":..}
##   {"t":"room","key":..,"delta":..}      {"t":"resource","key":..,"delta":..}
##   {"t":"rel","dp":..,"dpro":..}         {"t":"flag","key":..,"value":..}
##   {"t":"memory","who":..,"text":..}     {"t":"loan","minutes":..}      {"t":"knowledge","delta":..}

const DEFS := {
	"employee_complaint": {
		"title": "Employee Complaint", "severity": 0, "pick": "highest_stress", "pause": false, "duration": 150,
		"text": "{emp} has filed a complaint about their workload and would like to talk to someone.",
		"responses": [
			{"label": "Hold a proper interview", "tip": "Employee feels heard. Costs some of the department's budget in coverage.",
			 "effects": [
				{"t": "need", "who": "emp", "key": "stress", "delta": -14}, {"t": "need", "who": "emp", "key": "satisfaction", "delta": 7},
				{"t": "resource", "key": "budget", "delta": -10},
				{"t": "memory", "who": "emp", "text": "Was heard out about their workload."}]},
			{"label": "Acknowledge and defer", "tip": "A small relief now, but nothing really changes.",
			 "effects": [{"t": "need", "who": "emp", "key": "stress", "delta": -4}, {"t": "need", "who": "emp", "key": "satisfaction", "delta": 1}]},
		],
		"ignore": [
			{"t": "need", "who": "emp", "key": "satisfaction", "delta": -8}, {"t": "need", "who": "emp", "key": "morale", "delta": -6},
			{"t": "memory", "who": "emp", "text": "Complained about workload and got no answer."}],
	},
	"break_room_malfunction": {
		"title": "Break Room Malfunction", "severity": 1, "pick": "none", "pause": true, "duration": 180, "room": "break_room",
		"text": "The break room's climate unit has failed. It is getting stuffy and the staff using it are noticing.",
		"responses": [
			{"label": "Request an immediate repair", "tip": "Restores the room, costs budget.",
			 "effects": [{"t": "room", "key": "comfort", "delta": 8}, {"t": "room", "key": "equipment", "delta": 20}, {"t": "resource", "key": "budget", "delta": -60}]},
			{"label": "Prop the doors open and improvise", "tip": "Cheap, partial fix. The room stays worse than before.",
			 "effects": [{"t": "room", "key": "comfort", "delta": -10}, {"t": "need", "who": "room_occupants", "key": "stress", "delta": -3}]},
		],
		"ignore": [{"t": "room", "key": "comfort", "delta": -25}, {"t": "room", "key": "equipment", "delta": -15}, {"t": "need", "who": "room_occupants", "key": "morale", "delta": -5}],
	},
	"staffing_request": {
		"title": "Staffing Request", "severity": 0, "pick": "working", "pause": false, "duration": 120,
		"text": "Another department asks to borrow {emp} for a couple of hours.",
		"responses": [
			{"label": "Lend them for two hours", "tip": "Helps the other department and builds goodwill, but leaves a gap here.",
			 "effects": [{"t": "loan", "minutes": 120}, {"t": "knowledge", "delta": 0}, {"t": "flag", "key": "lent_staff", "value": true}]},
			{"label": "Decline politely", "tip": "Keeps your floor intact. They will remember.",
			 "effects": [{"t": "flag", "key": "declined_staff_request", "value": true}]},
		],
		"ignore": [{"t": "flag", "key": "declined_staff_request", "value": true}],
	},
	"conflict_flare": {
		"title": "Argument Between Coworkers", "severity": 1, "pick": "none", "pause": true, "duration": 90,
		"text": "{emp} and {other} are in a heated disagreement in the {room}. Others are starting to notice.",
		"responses": [
			{"label": "Mediate it now", "tip": "Takes both away from their work but defuses things.",
			 "effects": [{"t": "rel", "dp": 18, "dpro": 8}, {"t": "need", "who": "both", "key": "stress", "delta": -8}, {"t": "loan", "minutes": 30},
				{"t": "memory", "who": "both", "text": "Was brought into mediation after an argument."}]},
			{"label": "Separate them for a while", "tip": "Stops the argument, solves nothing underneath.",
			 "effects": [{"t": "need", "who": "both", "key": "stress", "delta": -4}, {"t": "rel", "dp": -2, "dpro": 0}]},
		],
		"ignore": [{"t": "rel", "dp": -12, "dpro": -6}, {"t": "need", "who": "both", "key": "stress", "delta": 10}, {"t": "need", "who": "room_occupants", "key": "morale", "delta": -4}],
	},
	"employee_breakdown": {
		"title": "Employee Breakdown", "severity": 1, "pick": "none", "pause": true, "duration": 60,
		"text": "{emp} has hit their limit and can no longer function at their post.",
		"responses": [
			{"label": "Send them to rest", "tip": "They leave their post but recover.",
			 "effects": [{"t": "loan", "minutes": 180}, {"t": "need", "who": "emp", "key": "stress", "delta": -30}, {"t": "need", "who": "emp", "key": "fatigue", "delta": -20}, {"t": "need", "who": "emp", "key": "stability", "delta": 25},
				{"t": "memory", "who": "emp", "text": "Had a breakdown at work and was sent to rest."}]},
			{"label": "Push through", "tip": "Keeps the output. Costs them badly.",
			 "effects": [{"t": "need", "who": "emp", "key": "stability", "delta": 8}, {"t": "need", "who": "emp", "key": "satisfaction", "delta": -12}, {"t": "need", "who": "emp", "key": "morale", "delta": -10},
				{"t": "memory", "who": "emp", "text": "Was told to push through a breakdown."}]},
		],
		"ignore": [{"t": "need", "who": "emp", "key": "satisfaction", "delta": -15}, {"t": "need", "who": "emp", "key": "stability", "delta": -5}],
	},
	"equipment_fault": {
		"title": "Equipment Fault", "severity": 0, "pick": "none", "pause": false, "duration": 120, "room": "ies_office",
		"text": "The terminals in the IES Office are glitching and slowing everyone down.",
		"responses": [
			{"label": "Call maintenance", "tip": "Costs budget; efficiency recovers.",
			 "effects": [{"t": "room", "key": "efficiency", "delta": 10}, {"t": "room", "key": "equipment", "delta": 25}, {"t": "resource", "key": "budget", "delta": -35}]},
			{"label": "Work around it", "tip": "Free, but the room stays sluggish.",
			 "effects": [{"t": "room", "key": "efficiency", "delta": -6}]},
		],
		"ignore": [{"t": "room", "key": "efficiency", "delta": -15}, {"t": "room", "key": "equipment", "delta": -10}],
	},
}
